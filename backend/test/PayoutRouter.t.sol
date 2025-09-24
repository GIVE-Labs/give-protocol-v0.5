// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {PayoutRouter} from "../src/payout/PayoutRouter.sol";
import {RoleManager} from "../src/access/RoleManager.sol";
import {CampaignRegistry} from "../src/campaign/CampaignRegistry.sol";
import {StrategyRegistry} from "../src/manager/StrategyRegistry.sol";
import {RegistryTypes} from "../src/manager/RegistryTypes.sol";
import {CampaignVault} from "../src/vault/CampaignVault.sol";
import {Errors} from "../src/utils/Errors.sol";

contract PayoutRouterTest is Test {
    RoleManager internal roleManager;
    StrategyRegistry internal strategyRegistry;
    CampaignRegistry internal campaignRegistry;
    PayoutRouter internal router;

    MockERC20 internal usdc;
    CampaignVault internal vault;

    address internal admin;
    address internal curator;
    address internal treasury;
    address internal payoutAddress;
    address internal beneficiary;
    address internal supporterTwo;
    address internal beneficiaryTwo;
    uint64 internal campaignId;
    uint64 internal strategyId;

    function setUp() public {
        admin = makeAddr("admin");
        curator = makeAddr("curator");
        treasury = makeAddr("treasury");
        payoutAddress = makeAddr("payout");
        beneficiary = makeAddr("beneficiary");
        supporterTwo = makeAddr("supporterTwo");
        beneficiaryTwo = makeAddr("beneficiaryTwo");

        usdc = new MockERC20("USD Coin", "USDC", 6);

        roleManager = new RoleManager(address(this));
        roleManager.grantRole(roleManager.ROLE_CAMPAIGN_ADMIN(), admin);
        roleManager.grantRole(roleManager.ROLE_STRATEGY_ADMIN(), admin);
        roleManager.grantRole(roleManager.ROLE_TREASURY(), admin);
        roleManager.grantRole(roleManager.ROLE_TREASURY(), treasury);
        roleManager.grantRole(roleManager.ROLE_GUARDIAN(), admin);
        roleManager.grantRole(roleManager.ROLE_VAULT_OPS(), admin);

        strategyRegistry = new StrategyRegistry(address(roleManager));
        vm.prank(admin);
        strategyId = strategyRegistry.createStrategy(
            address(usdc), makeAddr("adapter"), RegistryTypes.RiskTier.Conservative, "ipfs://strategy", 1_000_000 ether
        );

        campaignRegistry = new CampaignRegistry(address(roleManager), treasury, address(strategyRegistry), 0);

        vm.deal(address(this), 1 ether);
        vm.prank(address(this));
        campaignId = campaignRegistry.submitCampaign{value: 0}(
            "ipfs://campaign", curator, payoutAddress, RegistryTypes.LockProfile.Days90
        );

        vm.prank(admin);
        campaignRegistry.approveCampaign(campaignId);

        vm.prank(curator);
        campaignRegistry.attachStrategy(campaignId, strategyId);

        router = new PayoutRouter(address(roleManager), address(campaignRegistry), treasury);

        vault = new CampaignVault(
            IERC20(address(usdc)),
            "Campaign Vault",
            "cvUSDC",
            address(roleManager),
            campaignId,
            strategyId,
            RegistryTypes.LockProfile.Days90,
            1e6  // min deposit of 1 USDC
        );

        vm.prank(admin);
        vault.setPayoutRouter(address(router));

        vm.prank(admin);
        router.registerVault(address(vault), campaignId, strategyId);
        vm.prank(admin);
        router.setAuthorizedCaller(address(vault), true);

        uint256 depositAmount = 10_000e6;
        usdc.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, address(this));

        router.setYieldAllocation(address(vault), 50, beneficiary);
    }

    function testDistributeAppliesProtocolFeeAndEpoch() public {
        // Fund router with harvested yield (simulating vault transfer)
        uint256 amount = 1_000e6;
        usdc.transfer(address(router), amount);

        vm.prank(address(vault));
        router.distributeToAllUsers(address(usdc), amount);

        uint256 protocolFee = (amount * router.protocolFeeBps()) / router.BASIS_POINTS();
        assertEq(usdc.balanceOf(treasury), protocolFee);
        uint256 distributable = amount - protocolFee;

        // Campaign allocation receives half (50%) immediately, remainder claimable by beneficiary
        assertEq(usdc.balanceOf(payoutAddress), distributable / 2);
        assertEq(usdc.balanceOf(beneficiary), 0);

        vm.prank(address(this));
        uint256 claimed = router.claimPersonalYield(address(vault));
        assertEq(claimed, distributable / 2);
        assertEq(usdc.balanceOf(beneficiary), distributable / 2);
    }

    function testSetYieldAllocationRejectsZeroBeneficiary() public {
        vm.expectRevert(Errors.InvalidBeneficiary.selector);
        router.setYieldAllocation(address(vault), 50, address(0));
    }

    function testDistributeToMultipleUsersRespectsAllocations() public {
        uint256 secondDeposit = 10_000e6;
        usdc.transfer(supporterTwo, secondDeposit);

        vm.prank(supporterTwo);
        usdc.approve(address(vault), secondDeposit);

        vm.prank(supporterTwo);
        vault.deposit(secondDeposit, supporterTwo);

        vm.prank(supporterTwo);
        router.setYieldAllocation(address(vault), 100, address(0));

        uint256 amount = 2_000e6;
        usdc.transfer(address(router), amount);

        vm.prank(address(vault));
        router.distributeToAllUsers(address(usdc), amount);

        uint256 protocolFee = (amount * router.protocolFeeBps()) / router.BASIS_POINTS();
        uint256 distributable = amount - protocolFee;
        uint256 totalShares = vault.totalSupply();
        uint256 sharesUserOne = vault.balanceOf(address(this));
        uint256 sharesUserTwo = vault.balanceOf(supporterTwo);

        uint256 userOnePortion = (distributable * sharesUserOne) / totalShares;
        uint256 userTwoPortion = (distributable * sharesUserTwo) / totalShares;

        uint256 campaignFromUserOne = (userOnePortion * 50) / 100;
        uint256 beneficiaryFromUserOne = userOnePortion - campaignFromUserOne;
        uint256 campaignFromUserTwo = userTwoPortion; // 100% allocation

        uint256 consumed = userOnePortion + userTwoPortion;
        uint256 leftover = distributable > consumed ? distributable - consumed : 0;
        uint256 expectedCampaign = campaignFromUserOne + campaignFromUserTwo + leftover;

        assertEq(usdc.balanceOf(treasury), protocolFee);
        assertEq(usdc.balanceOf(payoutAddress), expectedCampaign);
        assertEq(usdc.balanceOf(beneficiary), 0);

        vm.prank(address(this));
        uint256 claimedUserOne = router.claimPersonalYield(address(vault));
        assertEq(claimedUserOne, beneficiaryFromUserOne);
        assertEq(usdc.balanceOf(beneficiary), beneficiaryFromUserOne);

        vm.prank(supporterTwo);
        uint256 claimedUserTwo = router.claimPersonalYield(address(vault));
        assertEq(claimedUserTwo, 0);
    }

    function testUpdateUserSharesRevertsOnMismatch() public {
        uint256 actualShares = vault.balanceOf(address(this));
        vm.startPrank(address(vault));
        vm.expectRevert(bytes("shares mismatch"));
        router.updateUserShares(address(this), address(vault), actualShares + 1);
        vm.stopPrank();
    }
}

contract MockERC20 is ERC20 {
    uint8 private immutable _decimals;

    constructor(string memory name_, string memory symbol_, uint8 decimals_) ERC20(name_, symbol_) {
        _decimals = decimals_;
        _mint(msg.sender, type(uint128).max);
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }
}
