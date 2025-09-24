// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {CampaignVaultFactory, IConfigurableAdapter} from "../src/vault/CampaignVaultFactory.sol";
import {CampaignRegistry} from "../src/campaign/CampaignRegistry.sol";
import {StrategyRegistry} from "../src/manager/StrategyRegistry.sol";
import {RoleManager} from "../src/access/RoleManager.sol";
import {RegistryTypes} from "../src/manager/RegistryTypes.sol";
import {StrategyManager} from "../src/manager/StrategyManager.sol";
import {CampaignVault} from "../src/vault/CampaignVault.sol";
import {PayoutRouter} from "../src/payout/PayoutRouter.sol";
import {IYieldAdapter} from "../src/interfaces/IYieldAdapter.sol";
import {Errors} from "../src/utils/Errors.sol";

contract CampaignVaultFactoryTest is Test {
    RoleManager internal roleManager;
    StrategyRegistry internal strategyRegistry;
    CampaignRegistry internal campaignRegistry;
    CampaignVaultFactory internal factory;
    PayoutRouter internal payoutRouter;

    address internal admin;
    address internal curator;
    address internal treasury;
    address internal payout;
    ConfigurableAdapter internal adapter;
    MockERC20 internal usdc;

    uint64 internal strategyId;
    uint64 internal campaignId;

    function setUp() public {
        admin = makeAddr("admin");
        curator = makeAddr("curator");
        treasury = makeAddr("treasury");
        payout = makeAddr("payout");
        usdc = new MockERC20("USD Coin", "USDC", 6);
        adapter = new ConfigurableAdapter(address(usdc));

        roleManager = new RoleManager(address(this));
        roleManager.grantRole(roleManager.ROLE_CAMPAIGN_ADMIN(), admin);
        roleManager.grantRole(roleManager.ROLE_STRATEGY_ADMIN(), admin);
        roleManager.grantRole(roleManager.ROLE_GUARDIAN(), admin);

        strategyRegistry = new StrategyRegistry(address(roleManager));
        vm.prank(admin);
        strategyId = strategyRegistry.createStrategy(
            address(usdc), address(adapter), RegistryTypes.RiskTier.Conservative, "ipfs://strategy", 1_000_000 ether
        );

        campaignRegistry = new CampaignRegistry(address(roleManager), treasury, address(strategyRegistry), 0);

        vm.prank(curator);
        campaignId =
            campaignRegistry.submitCampaign("ipfs://campaign", curator, payout, RegistryTypes.LockProfile.Days90);

        vm.prank(admin);
        campaignRegistry.approveCampaign(campaignId);

        vm.prank(curator);
        campaignRegistry.attachStrategy(campaignId, strategyId);

        payoutRouter = new PayoutRouter(address(roleManager), address(campaignRegistry), treasury);

        factory = new CampaignVaultFactory(
            address(roleManager), address(strategyRegistry), address(campaignRegistry), address(payoutRouter)
        );

        // Grant factory the privileges it needs to perform deployments.
        roleManager.grantRole(roleManager.DEFAULT_ADMIN_ROLE(), address(factory));
        roleManager.grantRole(roleManager.ROLE_STRATEGY_ADMIN(), address(factory));
        roleManager.grantRole(roleManager.ROLE_CAMPAIGN_ADMIN(), address(factory));
    }

    function testDeployCampaignVaultCreatesVaultAndManager() public {
        vm.prank(curator);
        CampaignVaultFactory.Deployment memory deployment = factory.deployCampaignVault(
            campaignId, strategyId, RegistryTypes.LockProfile.Days90, "Campaign Vault", "cvUSDC", 1e6
        );

        assertEq(factory.deploymentsLength(), 1);
        assertEq(deployment.campaignId, campaignId);
        assertEq(deployment.strategyId, strategyId);
        assertEq(uint8(deployment.lockProfile), uint8(RegistryTypes.LockProfile.Days90));

        CampaignVault vault = CampaignVault(payable(deployment.vault));
        assertEq(vault.campaignId(), campaignId);
        assertEq(vault.strategyId(), strategyId);
        assertEq(address(vault.asset()), address(usdc));

        StrategyManager manager = StrategyManager(deployment.strategyManager);
        assertEq(address(manager.vault()), address(vault));
        assertTrue(roleManager.hasRole(roleManager.ROLE_VAULT_OPS(), address(manager)));

        (uint64 regCampaignId, uint64 regStrategyId, address regAsset, bool registered) =
            payoutRouter.vaultInfo(address(vault));
        assertTrue(registered);
        assertEq(regCampaignId, campaignId);
        assertEq(regStrategyId, strategyId);
        assertEq(regAsset, address(usdc));
    }

    function testDeployVaultRevertsIfStrategyNotAttached() public {
        vm.prank(admin);
        uint64 unattachedStrategy = strategyRegistry.createStrategy(
            makeAddr("asset2"), makeAddr("adapter2"), RegistryTypes.RiskTier.Moderate, "ipfs://strategy2", 500_000 ether
        );

        vm.prank(curator);
        vm.expectRevert(Errors.StrategyNotFound.selector);
        factory.deployCampaignVault(campaignId, unattachedStrategy, RegistryTypes.LockProfile.Days30, "Vault", "v2", 1e6);
    }

    function testDeployVaultRequiresActiveCampaign() public {
        vm.prank(admin);
        campaignRegistry.setFinalStatus(campaignId, RegistryTypes.CampaignStatus.Completed);

        vm.prank(curator);
        vm.expectRevert(Errors.CampaignNotActive.selector);
        factory.deployCampaignVault(campaignId, strategyId, RegistryTypes.LockProfile.Days90, "Vault", "v", 1e6);
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

contract ConfigurableAdapter is IYieldAdapter, IConfigurableAdapter {
    IERC20 private immutable _asset;
    address private _vault;

    constructor(address asset_) {
        _asset = IERC20(asset_);
    }

    function configureForVault(address vault_) external override {
        _vault = vault_;
    }

    function asset() external view override returns (IERC20) {
        return _asset;
    }

    function totalAssets() external view override returns (uint256) {
        return 0;
    }

    function invest(uint256) external pure override {}

    function divest(uint256 assets) external pure override returns (uint256) {
        return assets;
    }

    function harvest() external pure override returns (uint256, uint256) {
        return (0, 0);
    }

    function emergencyWithdraw() external pure override returns (uint256) {
        return 0;
    }

    function vault() external view override returns (address) {
        return _vault;
    }
}
