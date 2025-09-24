// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {RoleManager} from "../src/access/RoleManager.sol";
import {StrategyRegistry} from "../src/manager/StrategyRegistry.sol";
import {CampaignRegistry} from "../src/campaign/CampaignRegistry.sol";
import {PayoutRouter} from "../src/payout/PayoutRouter.sol";
import {CampaignVaultFactory} from "../src/vault/CampaignVaultFactory.sol";
import {CampaignVault} from "../src/vault/CampaignVault.sol";
import {StrategyManager} from "../src/manager/StrategyManager.sol";
import {RegistryTypes} from "../src/manager/RegistryTypes.sol";
import {MockYieldAdapter} from "../src/adapters/MockYieldAdapter.sol";
import {Errors} from "../src/utils/Errors.sol";

contract CampaignVaultETHTest is Test {
    RoleManager internal roleManager;
    StrategyRegistry internal strategyRegistry;
    CampaignRegistry internal campaignRegistry;
    PayoutRouter internal payoutRouter;
    CampaignVaultFactory internal factory;

    CampaignVault internal vault;
    StrategyManager internal manager;
    MockYieldAdapter internal adapter;
    MockWETH internal weth;

    address internal admin;
    address internal curator;
    address internal payout;
    uint64 internal strategyId;
    uint64 internal campaignId;

    function setUp() public {
        admin = makeAddr("admin");
        curator = makeAddr("curator");
        payout = makeAddr("payout");

        weth = new MockWETH();

        roleManager = new RoleManager(address(this));
        roleManager.grantRole(roleManager.DEFAULT_ADMIN_ROLE(), admin);
        roleManager.grantRole(roleManager.ROLE_VAULT_OPS(), admin);
        roleManager.grantRole(roleManager.ROLE_STRATEGY_ADMIN(), admin);
        roleManager.grantRole(roleManager.ROLE_CAMPAIGN_ADMIN(), admin);
        roleManager.grantRole(roleManager.ROLE_CAMPAIGN_ADMIN(), curator);
        roleManager.grantRole(roleManager.ROLE_GUARDIAN(), admin);
        roleManager.grantRole(roleManager.ROLE_TREASURY(), admin);

        strategyRegistry = new StrategyRegistry(address(roleManager));
        campaignRegistry = new CampaignRegistry(address(roleManager), admin, address(strategyRegistry), 0);
        payoutRouter = new PayoutRouter(address(roleManager), address(campaignRegistry), admin);
        factory = new CampaignVaultFactory(
            address(roleManager), address(strategyRegistry), address(campaignRegistry), address(payoutRouter)
        );

        roleManager.grantRole(roleManager.DEFAULT_ADMIN_ROLE(), address(factory));
        roleManager.grantRole(roleManager.ROLE_STRATEGY_ADMIN(), address(factory));
        roleManager.grantRole(roleManager.ROLE_CAMPAIGN_ADMIN(), address(factory));

        uint256 predictedNonce = vm.getNonce(address(factory));
        address predictedVault = vm.computeCreateAddress(address(factory), predictedNonce);
        adapter = new MockYieldAdapter(address(roleManager), address(weth), predictedVault);

        vm.prank(admin);
        strategyId = strategyRegistry.createStrategy(
            address(weth), address(adapter), RegistryTypes.RiskTier.Moderate, "ipfs://strategy/weth", type(uint256).max
        );
        vm.stopPrank();

        campaignId =
            campaignRegistry.submitCampaign("ipfs://campaign/water", curator, payout, RegistryTypes.LockProfile.Days90);

        vm.prank(admin);
        campaignRegistry.approveCampaign(campaignId);
        vm.prank(admin);
        campaignRegistry.attachStrategy(campaignId, strategyId);

        vm.prank(curator);
        CampaignVaultFactory.Deployment memory deployment = factory.deployCampaignVault(
            campaignId, strategyId, RegistryTypes.LockProfile.Days90, "Campaign WETH Vault", "cvWETH", 0.001 ether
        );

        vault = CampaignVault(payable(deployment.vault));
        manager = StrategyManager(deployment.strategyManager);

        vm.prank(admin);
        vault.setWrappedNative(address(weth));
        vm.prank(admin);
        manager.updateVaultParameters(100, 50, 50);
    }

    function testDepositETHInvestsExcessAndMintsShares() public {
        address supporter = makeAddr("supporter");
        vm.deal(supporter, 20 ether);

        vm.startPrank(supporter);
        vm.expectRevert(Errors.OperationNotAllowed.selector);
        vault.depositETH{value: 10 ether}(supporter, 0);
        vm.stopPrank();
    }

    function testRedeemETHReturnsPrincipal() public {
        address supporter = makeAddr("supporter2");
        vm.deal(supporter, 5 ether);

        vm.startPrank(supporter);
        weth.deposit{value: 5 ether}();
        weth.approve(address(vault), 5 ether);
        uint256 shares = vault.deposit(5 ether, supporter);
        vm.stopPrank();

        uint256 unlockTime = vault.getNextUnlockTime(supporter);
        vm.warp(unlockTime + 1);

        vm.startPrank(supporter);
        uint256 balanceBefore = weth.balanceOf(supporter);
        uint256 assets = vault.redeem(shares, supporter, supporter);
        vm.stopPrank();

        assertApproxEqAbs(assets, 5 ether, 1);
        assertEq(weth.balanceOf(supporter), balanceBefore + assets);
        assertEq(vault.balanceOf(supporter), 0);
    }
}

contract MockWETH is ERC20 {
    constructor() ERC20("Mock WETH", "mWETH") {}

    receive() external payable {
        deposit();
    }

    function deposit() public payable {
        _mint(msg.sender, msg.value);
    }

    function withdraw(uint256 wad) public {
        _burn(msg.sender, wad);
        payable(msg.sender).transfer(wad);
    }
}
