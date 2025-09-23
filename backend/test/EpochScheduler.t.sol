// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {EpochScheduler} from "../src/payout/EpochScheduler.sol";
import {PayoutRouter} from "../src/payout/PayoutRouter.sol";
import {CampaignRegistry} from "../src/campaign/CampaignRegistry.sol";
import {StrategyRegistry} from "../src/manager/StrategyRegistry.sol";
import {RegistryTypes} from "../src/manager/RegistryTypes.sol";
import {RoleManager} from "../src/access/RoleManager.sol";
import {CampaignVault} from "../src/vault/CampaignVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract EpochSchedulerTest is Test {
    RoleManager internal roleManager;
    StrategyRegistry internal strategyRegistry;
    CampaignRegistry internal campaignRegistry;
    PayoutRouter internal router;
    EpochScheduler internal scheduler;
    CampaignVault internal vault;
    MockToken internal usdc;

    address internal admin;
    address internal curator;
    address internal treasury;
    address internal payout;

    uint64 internal campaignId;
    uint64 internal strategyId;

    function setUp() public {
        admin = makeAddr("admin");
        curator = makeAddr("curator");
        treasury = makeAddr("treasury");
        payout = makeAddr("payout");

        roleManager = new RoleManager(address(this));
        roleManager.grantRole(roleManager.ROLE_CAMPAIGN_ADMIN(), admin);
        roleManager.grantRole(roleManager.ROLE_STRATEGY_ADMIN(), admin);
        roleManager.grantRole(roleManager.ROLE_TREASURY(), admin);
        roleManager.grantRole(roleManager.ROLE_GUARDIAN(), admin);

        strategyRegistry = new StrategyRegistry(address(roleManager));
        usdc = new MockToken();
        vm.prank(admin);
        strategyId = strategyRegistry.createStrategy(
            address(usdc),
            makeAddr("adapter"),
            RegistryTypes.RiskTier.Conservative,
            "ipfs://strategy",
            1_000_000 ether
        );

        campaignRegistry = new CampaignRegistry(address(roleManager), treasury, address(strategyRegistry), 0);

        vm.prank(curator);
        campaignId = campaignRegistry.submitCampaign("ipfs://campaign", curator, payout, RegistryTypes.LockProfile.Days90);

        vm.prank(admin);
        campaignRegistry.approveCampaign(campaignId);

        vm.prank(curator);
        campaignRegistry.attachStrategy(campaignId, strategyId);

        router = new PayoutRouter(address(roleManager), address(campaignRegistry), treasury);
        vm.prank(admin);
        router.setScheduler(address(this), true);

        scheduler = new EpochScheduler(address(roleManager), address(router), address(usdc), 7 days, 10 ether);
        vm.prank(admin);
        router.setScheduler(address(scheduler), true);

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
        scheduler.registerVault(address(vault));
        vm.prank(admin);
        router.registerVault(address(vault), campaignId, strategyId);
        vm.prank(admin);
        router.setAuthorizedCaller(address(vault), true);

        usdc.approve(address(vault), 1_000 ether);
        vault.deposit(1_000 ether, address(this));
    }

    function testKeeperProcessesEpoch() public {
        usdc.transfer(address(router), 1_000 ether);
        (, uint256 reward) = scheduler.config();
        usdc.transfer(address(scheduler), reward);

        (uint256 duration,) = scheduler.config();
        vm.warp(block.timestamp + duration);

        vm.prank(address(1));
        scheduler.processEpoch(address(vault), address(usdc), 1_000 ether);

        uint256 protocolFee = (1_000 ether * router.PROTOCOL_FEE_BPS()) / router.BASIS_POINTS();
        assertEq(usdc.balanceOf(treasury), protocolFee);
        assertEq(usdc.balanceOf(address(1)), reward);
        assertEq(usdc.balanceOf(payout), 1_000 ether - protocolFee);
    }
}

contract MockToken is ERC20 {
    constructor() ERC20("Mock", "MOCK") {
        _mint(msg.sender, 1_000_000 ether);
    }
}
