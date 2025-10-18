// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {RoleManager} from "../src/access/RoleManager.sol";
import {StrategyRegistry} from "../src/manager/StrategyRegistry.sol";
import {CampaignRegistry} from "../src/campaign/CampaignRegistry.sol";
import {PayoutRouter} from "../src/payout/PayoutRouter.sol";
import {CampaignVault} from "../src/vault/CampaignVault.sol";
import {CampaignVaultFactory} from "../src/vault/CampaignVaultFactory.sol";
import {VaultDeploymentLib} from "../src/vault/VaultDeploymentLib.sol";
import {ManagerDeploymentLib} from "../src/vault/ManagerDeploymentLib.sol";
import {StrategyManager} from "../src/manager/StrategyManager.sol";
import {RegistryTypes} from "../src/manager/RegistryTypes.sol";
import {Errors} from "../src/utils/Errors.sol";

/**
 * @title IntegrationTest
 * @notice Comprehensive integration tests for the entire GIVE protocol flow
 */
contract IntegrationTest is Test {
    RoleManager internal roleManager;
    StrategyRegistry internal strategyRegistry;
    CampaignRegistry internal campaignRegistry;
    PayoutRouter internal payoutRouter;
    CampaignVaultFactory internal factory;

    MockToken internal usdc;
    TestYieldAdapter internal adapter;

    // Actors
    address internal admin;
    address internal guardian;
    address internal treasury;
    address internal curator;
    address internal campaignPayout;
    address internal beneficiary1;
    address internal beneficiary2;
    address[] internal supporters;

    // IDs
    uint64 internal campaignId;
    uint64 internal strategyId;

    // Constants
    uint256 constant MIN_DEPOSIT = 1e6; // 1 USDC
    uint256 constant CAMPAIGN_STAKE = 0.1 ether;

    event CampaignPayout(
        address indexed vault,
        uint64 indexed campaignId,
        uint64 indexed strategyId,
        address asset,
        uint256 grossAmount,
        uint256 protocolFee,
        uint256 netAmount,
        uint256 epochTimestamp,
        address payoutAddress
    );

    function setUp() public {
        // Setup actors
        admin = makeAddr("admin");
        guardian = makeAddr("guardian");
        treasury = makeAddr("treasury");
        curator = makeAddr("curator");
        campaignPayout = makeAddr("campaignPayout");
        beneficiary1 = makeAddr("beneficiary1");
        beneficiary2 = makeAddr("beneficiary2");

        // Create 10 supporters with funds
        for (uint256 i = 0; i < 10; i++) {
            address supporter = makeAddr(string.concat("supporter", vm.toString(i)));
            supporters.push(supporter);
            vm.deal(supporter, 10 ether);
        }

        // Deploy core infrastructure
        _deployCore();
        _setupRoles();
        _deployTokensAndAdapters();
        _createCampaignAndStrategy();
    }

    function _deployCore() internal {
        // Deploy role manager
        roleManager = new RoleManager(admin);

        // Deploy registries
        vm.prank(admin);
        strategyRegistry = new StrategyRegistry(address(roleManager));

        vm.prank(admin);
        campaignRegistry = new CampaignRegistry(
            address(roleManager),
            treasury,
            address(strategyRegistry),
            CAMPAIGN_STAKE
        );

        vm.prank(admin);
        payoutRouter = new PayoutRouter(
            address(roleManager),
            address(campaignRegistry),
            treasury
        );

        vm.startPrank(admin);

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

        vm.stopPrank();
    }

    function _setupRoles() internal {
        vm.startPrank(admin);

        // Admin roles
        roleManager.grantRole(roleManager.DEFAULT_ADMIN_ROLE(), admin);
        roleManager.grantRole(roleManager.ROLE_CAMPAIGN_ADMIN(), admin);
        roleManager.grantRole(roleManager.ROLE_STRATEGY_ADMIN(), admin);
        roleManager.grantRole(roleManager.ROLE_VAULT_OPS(), admin);
        roleManager.grantRole(roleManager.ROLE_TREASURY(), treasury);
        roleManager.grantRole(roleManager.ROLE_GUARDIAN(), guardian);

        // Factory roles
        roleManager.grantRole(roleManager.DEFAULT_ADMIN_ROLE(), address(factory));
        roleManager.grantRole(roleManager.ROLE_STRATEGY_ADMIN(), address(factory));
        roleManager.grantRole(roleManager.ROLE_CAMPAIGN_ADMIN(), address(factory));

        vm.stopPrank();
    }

    function _deployTokensAndAdapters() internal {
        usdc = new MockToken("USD Coin", "USDC", 6);

        // Create the adapter (without predicting vault address since it doesn't exist yet)
        adapter = new TestYieldAdapter(address(roleManager), address(usdc), address(0));

        // Fund supporters with USDC
        for (uint256 i = 0; i < supporters.length; i++) {
            usdc.mint(supporters[i], 100_000e6); // 100k USDC each
        }

        // Fund adapter with some initial yield
        usdc.mint(address(adapter), 10_000e6);
    }

    function _createCampaignAndStrategy() internal {
        // Create strategy
        vm.prank(admin);
        strategyId = strategyRegistry.createStrategy(
            address(usdc),
            address(adapter),
            RegistryTypes.RiskTier.Conservative,
            "ipfs://strategy/conservative-usdc",
            10_000_000e6 // 10M USDC TVL limit
        );

        // Submit campaign
        vm.deal(curator, CAMPAIGN_STAKE);
        vm.prank(curator);
        campaignId = campaignRegistry.submitCampaign{value: CAMPAIGN_STAKE}(
            "ipfs://campaign/clean-water",
            curator,
            campaignPayout,
            RegistryTypes.LockProfile.Days90
        );

        // Approve campaign
        vm.prank(admin);
        campaignRegistry.approveCampaign(campaignId);

        // Attach strategy
        vm.prank(curator);
        campaignRegistry.attachStrategy(campaignId, strategyId);
    }

    /**
     * @notice Test complete flow from deployment to yield distribution
     */
    function testFullProtocolFlow() public {
        // Step 1: Deploy vault through factory
        vm.prank(curator);
        CampaignVaultFactory.Deployment memory deployment = factory.deployCampaignVault(
            campaignId,
            strategyId,
            RegistryTypes.LockProfile.Days90,
            "Clean Water USDC Vault",
            "cwUSDC",
            MIN_DEPOSIT
        );

        CampaignVault vault = CampaignVault(payable(deployment.vault));
        StrategyManager manager = StrategyManager(deployment.strategyManager);

        // Step 2: Configure vault parameters
        vm.prank(admin);
        manager.updateVaultParameters(100, 50, 50); // 1% buffer, 0.5% slippage, 0.5% max loss

        // Step 3: Multiple users deposit with different allocations
        _performDeposits(vault);

        // Step 4: Verify positions and locks
        _verifyPositions(vault);

        // Step 5: Simulate time passage and yield accrual
        vm.warp(block.timestamp + 30 days);
        adapter.simulateYield(5_000e6); // 5k USDC yield

        // Step 6: Harvest yield
        vault.harvest();

        // Step 7: Verify yield distribution
        _verifyYieldDistribution(vault);

        // Step 8: Test withdrawals at different time points
        _testTimedWithdrawals(vault);
    }

    function _performDeposits(CampaignVault vault) internal {
        uint256 depositTime = block.timestamp;
        // First 5 supporters: 50% to campaign, 50% to beneficiary
        for (uint256 i = 0; i < 5; i++) {
            vm.startPrank(supporters[i]);

            usdc.approve(address(vault), 10_000e6);
            vault.deposit(10_000e6, supporters[i]);

            payoutRouter.setYieldAllocation(
                address(vault),
                50,
                i % 2 == 0 ? beneficiary1 : beneficiary2
            );

            vm.stopPrank();
        }

        // Next 3 supporters: 75% to campaign
        for (uint256 i = 5; i < 8; i++) {
            vm.startPrank(supporters[i]);

            usdc.approve(address(vault), 5_000e6);
            vault.deposit(5_000e6, supporters[i]);

            payoutRouter.setYieldAllocation(address(vault), 75, supporters[i]);

            vm.stopPrank();
        }

        // Last 2 supporters: 100% to campaign
        for (uint256 i = 8; i < 10; i++) {
            vm.startPrank(supporters[i]);

            usdc.approve(address(vault), 2_000e6);
            vault.deposit(2_000e6, supporters[i]);

            payoutRouter.setYieldAllocation(address(vault), 100, address(0));

            vm.stopPrank();
        }
    }

    function _verifyPositions(CampaignVault vault) internal {
        // Verify each supporter has correct position
        for (uint256 i = 0; i < supporters.length; i++) {
            assertEq(vault.getPositionCount(supporters[i]), 1);

            (uint256 shares, uint256 unlockTime,) = vault.getPosition(supporters[i], 0);
            assertGt(shares, 0);
            assertEq(unlockTime, block.timestamp + 90 days);
        }

        // Verify total supply
        uint256 expectedTotal = 50_000e6 + 15_000e6 + 4_000e6; // Sum of all deposits
        assertApproxEqAbs(vault.totalAssets(), expectedTotal, 100);
    }

    function _verifyYieldDistribution(CampaignVault vault) internal {
        // Calculate expected distributions
        uint256 yield = 5_000e6;
        uint256 protocolFee = (yield * payoutRouter.protocolFeeBps() + 9999) / 10000; // Round up
        uint256 distributable = yield - protocolFee;

        // Verify protocol fee went to treasury
        assertGe(usdc.balanceOf(treasury), protocolFee);

        // Verify campaign payout received funds
        assertGt(usdc.balanceOf(campaignPayout), 0);

        // Beneficiaries receive their portions upon claim
        for (uint256 i = 0; i < supporters.length; i++) {
            vm.prank(supporters[i]);
            payoutRouter.claimPersonalYield(address(vault));
        }

        assertGt(usdc.balanceOf(beneficiary1), 0);
        assertGt(usdc.balanceOf(beneficiary2), 0);

        // Supporters with personal allocations should have received tokens after claim
        for (uint256 i = 5; i < 8; i++) {
            assertGt(usdc.balanceOf(supporters[i]), 0);
        }
    }

    function _testTimedWithdrawals(CampaignVault vault) internal {
        // Check the actual unlock time for the first position
        (,uint256 unlockTime,) = vault.getPosition(supporters[0], 0);

        // We should be before unlock time
        assertLt(block.timestamp, unlockTime, "Already unlocked");

        // Try withdrawal before unlock - should fail
        vm.startPrank(supporters[0]);
        uint256 shares = vault.balanceOf(supporters[0]);
        vm.expectRevert("Insufficient unlocked shares");
        vault.redeem(shares, supporters[0], supporters[0]);
        vm.stopPrank();

        // Fast forward to unlock time
        vm.warp(block.timestamp + 60 days + 1); // Total 90 days passed

        // Now withdrawals should succeed
        for (uint256 i = 0; i < 3; i++) {
            vm.startPrank(supporters[i]);

            uint256 shares = vault.balanceOf(supporters[i]);
            uint256 assets = vault.redeem(shares, supporters[i], supporters[i]);

            assertGt(assets, 0);
            assertEq(vault.balanceOf(supporters[i]), 0);

            vm.stopPrank();
        }
    }

    /**
     * @notice Test protocol fee changes during active epoch
     */
    function testProtocolFeeChangeDuringEpoch() public {
        // Deploy vault
        vm.prank(curator);
        CampaignVaultFactory.Deployment memory deployment = factory.deployCampaignVault(
            campaignId, strategyId, RegistryTypes.LockProfile.Days30, "Test Vault", "tUSDC", MIN_DEPOSIT
        );

        CampaignVault vault = CampaignVault(payable(deployment.vault));

        // Deposit
        vm.startPrank(supporters[0]);
        usdc.approve(address(vault), 10_000e6);
        vault.deposit(10_000e6, supporters[0]);
        payoutRouter.setYieldAllocation(address(vault), 100, address(0));
        vm.stopPrank();

        // Initial harvest with 10% fee
        adapter.simulateYield(1_000e6);
        vault.harvest();

        uint256 treasuryBefore = usdc.balanceOf(treasury);
        assertEq(treasuryBefore, 100e6); // 10% of 1000

        // Change fee to 25%
        vm.prank(treasury);
        payoutRouter.setProtocolFee(2500);

        // Second harvest with new fee
        adapter.simulateYield(1_000e6);
        vault.harvest();

        uint256 treasuryAfter = usdc.balanceOf(treasury);
        assertEq(treasuryAfter - treasuryBefore, 250e6); // 25% of 1000
    }

    /**
     * @notice Test emergency scenarios with guardian intervention
     */
    function testEmergencyGuardianActions() public {
        // Deploy vault
        vm.prank(curator);
        CampaignVaultFactory.Deployment memory deployment = factory.deployCampaignVault(
            campaignId, strategyId, RegistryTypes.LockProfile.Days180, "Emergency Test", "eUSDC", MIN_DEPOSIT
        );

        CampaignVault vault = CampaignVault(payable(deployment.vault));
        StrategyManager manager = StrategyManager(deployment.strategyManager);

        // Multiple deposits
        for (uint256 i = 0; i < 3; i++) {
            vm.startPrank(supporters[i]);
            usdc.approve(address(vault), 10_000e6);
            vault.deposit(10_000e6, supporters[i]);
            vm.stopPrank();
        }

        // Simulate emergency - guardian can bypass locks
        // First, supporter needs to give approval to guardian
        vm.prank(supporters[0]);
        vault.approve(guardian, type(uint256).max);

        vm.startPrank(guardian);

        // Guardian bypasses locks
        uint256 shares = vault.balanceOf(supporters[0]);
        vault.redeem(shares, supporters[0], supporters[0]);
        vm.stopPrank();

        assertEq(vault.balanceOf(supporters[0]), 0);
    }

    /**
     * @notice Test multiple position management
     */
    function testMultiplePositionsPerUser() public {
        vm.prank(curator);
        CampaignVaultFactory.Deployment memory deployment = factory.deployCampaignVault(
            campaignId, strategyId, RegistryTypes.LockProfile.Days30, "Multi Position", "mpUSDC", MIN_DEPOSIT
        );

        CampaignVault vault = CampaignVault(payable(deployment.vault));

        // User makes multiple deposits at different times
        vm.startPrank(supporters[0]);
        usdc.approve(address(vault), 100_000e6);

        // First deposit at t=1
        vault.deposit(10_000e6, supporters[0]);
        assertEq(vault.getPositionCount(supporters[0]), 1);

        // Wait 10 days (warp to t=864001)
        vm.warp(1 + 10 days);

        // Second deposit at t=864001
        vault.deposit(5_000e6, supporters[0]);
        assertEq(vault.getPositionCount(supporters[0]), 2);

        // Wait another 10 days (warp to t=1728001)
        vm.warp(1 + 20 days);

        // Third deposit at t=1728001
        vault.deposit(2_000e6, supporters[0]);
        assertEq(vault.getPositionCount(supporters[0]), 3);

        // Verify each position has different unlock time
        (,uint256 unlock1,) = vault.getPosition(supporters[0], 0);
        (,uint256 unlock2,) = vault.getPosition(supporters[0], 1);
        (,uint256 unlock3,) = vault.getPosition(supporters[0], 2);

        // Positions unlock 30 days after their deposit time
        // Position 1: deposited at t=1, unlocks at t=2592001
        // Position 2: deposited at t=864001, unlocks at t=3456001
        // Position 3: deposited at t=1728001, unlocks at t=4320001
        assertEq(unlock2 - unlock1, 10 days, "Second position should unlock 10 days after first");
        assertEq(unlock3 - unlock2, 10 days, "Third position should unlock 10 days after second");

        vm.stopPrank();
    }

    /**
     * @notice Test campaign completion scenarios
     */
    function testCampaignCompletionWithActivePositions() public {
        vm.prank(curator);
        CampaignVaultFactory.Deployment memory deployment = factory.deployCampaignVault(
            campaignId, strategyId, RegistryTypes.LockProfile.Days90, "Completion Test", "ctUSDC", MIN_DEPOSIT
        );

        CampaignVault vault = CampaignVault(payable(deployment.vault));

        // Deposits
        for (uint256 i = 0; i < 3; i++) {
            vm.startPrank(supporters[i]);
            usdc.approve(address(vault), 10_000e6);
            vault.deposit(10_000e6, supporters[i]);
            vm.stopPrank();
        }

        // Complete campaign
        vm.prank(admin);
        campaignRegistry.setFinalStatus(campaignId, RegistryTypes.CampaignStatus.Completed);

        // Existing positions should still be withdrawable after unlock
        vm.warp(block.timestamp + 91 days);

        vm.startPrank(supporters[0]);
        uint256 shares = vault.balanceOf(supporters[0]);
        vault.redeem(shares, supporters[0], supporters[0]);
        vm.stopPrank();

        assertGt(usdc.balanceOf(supporters[0]), 0);
    }
}

/**
 * @notice Mock token for testing
 */
contract MockToken is ERC20 {
    uint8 private immutable _decimals;

    constructor(string memory name, string memory symbol, uint8 decimals_) ERC20(name, symbol) {
        _decimals = decimals_;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/**
 * @notice Test yield adapter with simulation capabilities
 */
contract TestYieldAdapter {
    IERC20 public asset;
    address public vault;
    RoleManager public roleManager;
    uint256 public totalInvested;
    uint256 public simulatedYield;

    constructor(address _roleManager, address _asset, address _vault) {
        roleManager = RoleManager(_roleManager);
        asset = IERC20(_asset);
        vault = _vault;
    }

    // IConfigurableAdapter interface
    function configureForVault(address _vault) external {
        vault = _vault;
    }

    function invest(uint256 assets) external {
        require(msg.sender == vault, "Only vault");
        totalInvested += assets;
    }

    function divest(uint256 assets) external returns (uint256) {
        require(msg.sender == vault, "Only vault");
        uint256 available = asset.balanceOf(address(this));
        uint256 toReturn = assets > available ? available : assets;

        if (toReturn > 0) {
            totalInvested -= toReturn;
            asset.transfer(vault, toReturn);
        }

        return toReturn;
    }

    function harvest() external returns (uint256 profit, uint256 loss) {
        require(msg.sender == vault, "Only vault");

        profit = simulatedYield;
        simulatedYield = 0;

        if (profit > 0) {
            asset.transfer(vault, profit);
        }

        return (profit, 0);
    }

    function totalAssets() external view returns (uint256) {
        return totalInvested + simulatedYield;
    }

    function simulateYield(uint256 amount) external {
        simulatedYield += amount;
    }

    function emergencyWithdraw() external returns (uint256) {
        require(msg.sender == vault, "Only vault");
        uint256 balance = asset.balanceOf(address(this));
        if (balance > 0) {
            asset.transfer(vault, balance);
        }
        totalInvested = 0;
        simulatedYield = 0;
        return balance;
    }

    function setVault(address _vault) external {
        require(
            roleManager.hasRole(roleManager.ROLE_VAULT_OPS(), msg.sender),
            "Unauthorized"
        );
        vault = _vault;
    }
}
