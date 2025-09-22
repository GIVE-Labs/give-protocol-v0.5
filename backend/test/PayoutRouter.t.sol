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
    uint64 internal campaignId;
    uint64 internal strategyId;

    function setUp() public {
        admin = makeAddr("admin");
        curator = makeAddr("curator");
        treasury = makeAddr("treasury");
        payoutAddress = makeAddr("payout");
        beneficiary = makeAddr("beneficiary");

        usdc = new MockERC20("USD Coin", "USDC", 6);

        roleManager = new RoleManager(address(this));
        roleManager.grantRole(roleManager.ROLE_CAMPAIGN_ADMIN(), admin);
        roleManager.grantRole(roleManager.ROLE_STRATEGY_ADMIN(), admin);
        roleManager.grantRole(roleManager.ROLE_TREASURY(), admin);
        roleManager.grantRole(roleManager.ROLE_GUARDIAN(), admin);
        roleManager.grantRole(roleManager.ROLE_VAULT_OPS(), admin);

        strategyRegistry = new StrategyRegistry(address(roleManager));
        vm.prank(admin);
        strategyId = strategyRegistry.createStrategy(
            address(usdc),
            makeAddr("adapter"),
            RegistryTypes.RiskTier.Conservative,
            "ipfs://strategy",
            1_000_000 ether
        );

        campaignRegistry = new CampaignRegistry(
            address(roleManager),
            treasury,
            address(strategyRegistry),
            0
        );

        vm.deal(address(this), 1 ether);
        vm.prank(address(this));
        campaignId = campaignRegistry.submitCampaign{
            value: 0
        }(
            "ipfs://campaign",
            curator,
            payoutAddress,
            RegistryTypes.LockProfile.Days90
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
            RegistryTypes.LockProfile.Days90
        );

        vm.prank(admin);
        vault.setDonationRouter(address(router));

        vm.prank(admin);
        router.registerVault(address(vault), campaignId, strategyId);
        vm.prank(admin);
        router.setAuthorizedCaller(address(vault), true);
        vm.prank(address(vault));
        router.updateUserShares(address(this), address(vault), 1_000);
        router.setYieldAllocation(address(vault), 50, beneficiary);
    }

    function testDistributeAppliesProtocolFeeAndEpoch() public {
        // Fund router with harvested yield (simulating vault transfer)
        uint256 amount = 1_000e6;
        usdc.transfer(address(router), amount);

        vm.prank(address(vault));
        router.distributeToAllUsers(address(usdc), amount);

        uint256 protocolFee = (amount * router.PROTOCOL_FEE_BPS()) / router.BASIS_POINTS();
        assertEq(usdc.balanceOf(treasury), protocolFee);
        uint256 distributable = amount - protocolFee;
        assertEq(usdc.balanceOf(payoutAddress), distributable / 2);
        assertEq(usdc.balanceOf(beneficiary), distributable / 2);
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
