// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {RoleManager} from "../src/access/RoleManager.sol";
import {StrategyRegistry} from "../src/manager/StrategyRegistry.sol";
import {CampaignRegistry} from "../src/campaign/CampaignRegistry.sol";
import {PayoutRouter} from "../src/payout/PayoutRouter.sol";
import {CampaignVault} from "../src/vault/CampaignVault.sol";
import {StrategyManager} from "../src/manager/StrategyManager.sol";
import {RegistryTypes} from "../src/manager/RegistryTypes.sol";
import {Errors} from "../src/utils/Errors.sol";
import {IYieldAdapter} from "../src/interfaces/IYieldAdapter.sol";
import {CampaignVaultFactory} from "../src/vault/CampaignVaultFactory.sol";
import {VaultDeploymentLib} from "../src/vault/VaultDeploymentLib.sol";
import {ManagerDeploymentLib} from "../src/vault/ManagerDeploymentLib.sol";
import {IConfigurableAdapter} from "../src/vault/IConfigurableAdapter.sol";

contract CampaignVaultTest is Test {
    using SafeERC20 for IERC20;

    RoleManager internal roleManager;
    StrategyRegistry internal strategyRegistry;
    CampaignRegistry internal campaignRegistry;
    PayoutRouter internal payoutRouter;
    CampaignVaultFactory internal factory;

    CampaignVault internal vault;
    StrategyManager internal manager;
    TestToken internal asset;
    YieldAdapter internal adapter;

    address internal admin;
    address internal curator;
    address internal treasury;
    address internal payout;
    address internal beneficiary;
    address internal supporter;
    uint64 internal strategyId;
    uint64 internal campaignId;

    function setUp() public {
        admin = address(this);
        curator = makeAddr("curator");
        treasury = makeAddr("treasury");
        payout = makeAddr("payout");
        beneficiary = makeAddr("beneficiary");

        asset = new TestToken();

        roleManager = new RoleManager(admin);
        roleManager.grantRole(roleManager.ROLE_STRATEGY_ADMIN(), admin);
        roleManager.grantRole(roleManager.ROLE_CAMPAIGN_ADMIN(), admin);
        roleManager.grantRole(roleManager.ROLE_VAULT_OPS(), admin);
        roleManager.grantRole(roleManager.ROLE_GUARDIAN(), admin);
        roleManager.grantRole(roleManager.ROLE_TREASURY(), treasury);

        supporter = makeAddr("supporter");

        strategyRegistry = new StrategyRegistry(address(roleManager));
        campaignRegistry = new CampaignRegistry(address(roleManager), treasury, address(strategyRegistry), 0);
        payoutRouter = new PayoutRouter(address(roleManager), address(campaignRegistry), treasury);

        // Deploy helper contracts
        VaultDeploymentLib vaultDeployer = new VaultDeploymentLib();
        ManagerDeploymentLib managerDeployer = new ManagerDeploymentLib();

        // Grant roles to helper contracts
        roleManager.grantRole(roleManager.DEFAULT_ADMIN_ROLE(), address(managerDeployer));
        roleManager.grantRole(roleManager.ROLE_STRATEGY_ADMIN(), address(managerDeployer));
        roleManager.grantRole(roleManager.ROLE_CAMPAIGN_ADMIN(), address(managerDeployer));

        factory = new CampaignVaultFactory(
            address(roleManager),
            address(strategyRegistry),
            address(campaignRegistry),
            address(payoutRouter),
            address(vaultDeployer),
            address(managerDeployer)
        );

        roleManager.grantRole(roleManager.DEFAULT_ADMIN_ROLE(), address(factory));
        roleManager.grantRole(roleManager.ROLE_STRATEGY_ADMIN(), address(factory));
        roleManager.grantRole(roleManager.ROLE_CAMPAIGN_ADMIN(), address(factory));

        adapter = new YieldAdapter(asset);

        strategyId = strategyRegistry.createStrategy(
            address(asset), address(adapter), RegistryTypes.RiskTier.Moderate, "ipfs://strategy", type(uint256).max
        );

        campaignId =
            campaignRegistry.submitCampaign("ipfs://campaign", curator, payout, RegistryTypes.LockProfile.Days90);

        campaignRegistry.approveCampaign(campaignId);
        vm.prank(curator);
        campaignRegistry.attachStrategy(campaignId, strategyId);

        CampaignVaultFactory.Deployment memory deployment = factory.deployCampaignVault(
            campaignId, strategyId, RegistryTypes.LockProfile.Days90, "Campaign Vault", "cvTEST", 1 ether
        );

        vault = CampaignVault(payable(deployment.vault));
        manager = StrategyManager(deployment.strategyManager);
        manager.updateVaultParameters(0, 50, 50);

        asset.approve(address(vault), type(uint256).max);
        asset.approve(address(adapter), type(uint256).max);
        asset.transfer(supporter, 500_000 ether);
    }

    function testIndependentPositionLocks() public {
        // Start at a known timestamp for easier math
        vm.warp(1000000);

        // First deposit: 1000 tokens for 90 days
        uint256 firstDeposit = 1_000 ether;

        vm.startPrank(supporter);
        asset.approve(address(vault), type(uint256).max);
        uint256 firstShares = vault.deposit(firstDeposit, supporter);

        // Check first position created with correct lock
        assertEq(vault.getPositionCount(supporter), 1);
        (uint256 pos1Shares, uint256 pos1Unlock,) = vault.getPosition(supporter, 0);
        assertEq(pos1Shares, firstShares);
        uint256 expectedFirstUnlock = 1000000 + 90 days;
        assertEq(pos1Unlock, expectedFirstUnlock);

        // Fast forward 45 days and make second deposit
        vm.warp(1000000 + 45 days);
        uint256 secondDeposit = 500 ether;
        uint256 secondShares = vault.deposit(secondDeposit, supporter);

        // Check second position created independently
        assertEq(vault.getPositionCount(supporter), 2);
        (uint256 pos2Shares, uint256 pos2Unlock,) = vault.getPosition(supporter, 1);
        assertEq(pos2Shares, secondShares);
        // Second position should have its own 90-day lock from the current timestamp
        uint256 expectedSecondUnlock = 1000000 + 45 days + 90 days;
        assertEq(pos2Unlock, expectedSecondUnlock);

        // Verify second position unlocks later than first
        assertEq(pos2Unlock - pos1Unlock, 45 days);

        // First position should still unlock at original time
        (uint256 checkPos1Shares, uint256 checkPos1Unlock,) = vault.getPosition(supporter, 0);
        assertEq(checkPos1Shares, firstShares);
        assertEq(checkPos1Unlock, expectedFirstUnlock); // Unchanged!

        // Fast forward to first position unlock (45 more days)
        vm.warp(pos1Unlock + 1);

        // Can withdraw first position but not second
        uint256 unlockedShares = vault.getUnlockedShares(supporter);
        assertEq(unlockedShares, firstShares);

        // Withdraw first position
        vault.redeem(firstShares, supporter, supporter);

        // Second position still locked
        uint256 remainingLocked = vault.getLockedShares(supporter);
        assertEq(remainingLocked, secondShares);

        // Cannot withdraw second position yet
        vm.expectRevert("Insufficient unlocked shares");
        vault.redeem(secondShares, supporter, supporter);

        // Fast forward to second position unlock
        vm.warp(pos2Unlock + 1);

        // Now can withdraw second position
        vault.redeem(secondShares, supporter, supporter);

        vm.stopPrank();
    }

    function testTransfersBlockedForNormalUsers() public {
        uint256 depositAmount = 500 ether;

        vm.startPrank(supporter);
        asset.approve(address(vault), depositAmount);
        uint256 shares = vault.deposit(depositAmount, supporter);

        // Try to transfer to another user - should fail
        address recipient = makeAddr("recipient");
        vm.expectRevert(Errors.OperationNotAllowed.selector);
        vault.transfer(recipient, shares / 2);

        vm.stopPrank();
    }

    function testGuardianCanBypassLocks() public {
        uint256 depositAmount = 500 ether;

        vm.startPrank(supporter);
        asset.approve(address(vault), depositAmount);
        uint256 shares = vault.deposit(depositAmount, supporter);

        // Give guardian approval to redeem on behalf of supporter
        vault.approve(admin, shares);
        vm.stopPrank();

        // Check position is locked
        assertEq(vault.getUnlockedShares(supporter), 0);
        assertEq(vault.getLockedShares(supporter), shares);

        // Guardian can withdraw even when locked
        vm.startPrank(admin); // admin has GUARDIAN role
        vault.redeem(shares, supporter, supporter);
        vm.stopPrank();

        assertEq(vault.balanceOf(supporter), 0);
    }

    function testPositionCleanup() public {
        vm.startPrank(supporter);
        asset.approve(address(vault), type(uint256).max);

        // Create multiple positions
        vault.deposit(100 ether, supporter);
        vault.deposit(200 ether, supporter);
        vault.deposit(300 ether, supporter);

        assertEq(vault.getPositionCount(supporter), 3);

        // Fast forward past all locks
        vm.warp(block.timestamp + 91 days);

        // Redeem middle position amount
        (uint256 pos1Shares,,) = vault.getPosition(supporter, 1);
        vault.redeem(pos1Shares, supporter, supporter);

        // Position should be cleaned up after full redemption
        // Note: cleanup happens in _update after burn

        vm.stopPrank();
    }

    function testMinimumDepositRequirement() public {
        // Try to deposit below minimum (1 ether)
        uint256 belowMinimum = 0.5 ether;

        vm.startPrank(supporter);
        asset.approve(address(vault), belowMinimum);

        vm.expectRevert("Deposit below minimum");
        vault.deposit(belowMinimum, supporter);

        // Deposit exactly at minimum should work
        uint256 exactMinimum = 1 ether;
        asset.approve(address(vault), exactMinimum);
        vault.deposit(exactMinimum, supporter);

        assertEq(vault.balanceOf(supporter), vault.previewDeposit(exactMinimum));
        vm.stopPrank();
    }

    function testEmergencyWithdrawDistributesYield() public {
        uint256 depositAmount = 2_000 ether;
        vault.deposit(depositAmount, address(this));

        // Simulate adapter accrual so emergency withdraw has funds.
        adapter.injectYield(1_000 ether);

        payoutRouter.setYieldAllocation(address(vault), 75, beneficiary);

        uint256 vaultBalanceBefore = asset.balanceOf(address(vault));
        assertEq(vaultBalanceBefore, 0); // all invested due to zero buffer

        uint256 expectedReturn = adapter.totalAssets();
        vault.emergencyWithdrawFromAdapter();

        uint256 protocolFee = (expectedReturn * payoutRouter.protocolFeeBps()) / payoutRouter.BASIS_POINTS();
        uint256 distributable = expectedReturn - protocolFee;
        uint256 userPortion = distributable; // single supporter
        uint256 campaignShare = (userPortion * 75) / 100;
        uint256 beneficiaryShare = userPortion - campaignShare;

        assertEq(asset.balanceOf(treasury), protocolFee);
        assertEq(asset.balanceOf(payout), campaignShare);
        assertEq(asset.balanceOf(beneficiary), 0);

        uint256 claimed = payoutRouter.claimPersonalYield(address(vault));
        assertEq(claimed, beneficiaryShare);
        assertEq(asset.balanceOf(beneficiary), beneficiaryShare);
        assertEq(adapter.totalAssets(), 0);
    }
}

contract TestToken is ERC20 {
    constructor() ERC20("Test Token", "TEST") {
        _mint(msg.sender, 1_000_000 ether);
    }
}

contract YieldAdapter is IYieldAdapter, IConfigurableAdapter {
    using SafeERC20 for IERC20;

    IERC20 private immutable _asset;
    address private _vault;
    uint256 private _balance;

    constructor(IERC20 asset_) {
        _asset = asset_;
    }

    function configureForVault(address vault_) external override {
        _vault = vault_;
    }

    function asset() external view override returns (IERC20) {
        return _asset;
    }

    function vault() external view override returns (address) {
        return _vault;
    }

    function totalAssets() external view override returns (uint256) {
        return _balance;
    }

    function invest(uint256 assets) external override {
        require(msg.sender == _vault, "only vault");
        _balance += assets;
    }

    function divest(uint256 assets) external override returns (uint256 returned) {
        require(msg.sender == _vault, "only vault");
        returned = assets > _balance ? _balance : assets;
        _balance -= returned;
        if (returned > 0) {
            _asset.safeTransfer(_vault, returned);
        }
    }

    function harvest() external override returns (uint256 profit, uint256 loss) {
        require(msg.sender == _vault, "only vault");
        return (0, 0);
    }

    function emergencyWithdraw() external override returns (uint256 returned) {
        require(msg.sender == _vault, "only vault");
        returned = _balance;
        _balance = 0;
        if (returned > 0) {
            _asset.safeTransfer(_vault, returned);
        }
    }

    function injectYield(uint256 amount) external {
        _asset.safeTransferFrom(msg.sender, address(this), amount);
        _balance += amount;
    }
}
