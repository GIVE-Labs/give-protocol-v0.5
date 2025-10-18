// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../src/vault/GiveVault4626.sol";
import "../src/manager/StrategyManager.sol";
import "../src/interfaces/IYieldAdapter.sol";
import "../src/access/RoleManager.sol";
import "../src/manager/StrategyRegistry.sol";
import "../src/manager/RegistryTypes.sol";
import "../src/campaign/CampaignRegistry.sol";
import "../src/payout/PayoutRouter.sol";

contract StrategyManagerBasicTest is Test {
    GiveVault4626 public vault;
    StrategyManager public manager;
    MockERC20 public usdc;
    MockAdapter public adapter;
    RoleManager public roleManager;
    StrategyRegistry public strategyRegistry;
    uint64 public registryStrategyId;

    address public admin = address(0xA11CE);

    function setUp() public {
        usdc = new MockERC20("Test USDC", "TUSDC", 6);
        roleManager = new RoleManager(address(this));
        roleManager.grantRole(roleManager.ROLE_VAULT_OPS(), admin);
        roleManager.grantRole(roleManager.ROLE_GUARDIAN(), admin);
        roleManager.grantRole(roleManager.ROLE_STRATEGY_ADMIN(), admin);
        roleManager.grantRole(roleManager.ROLE_TREASURY(), admin);
        roleManager.grantRole(roleManager.ROLE_CAMPAIGN_ADMIN(), admin);

        vault = new GiveVault4626(IERC20(address(usdc)), "GIVE USDC", "gvUSDC", address(roleManager));
        manager = new StrategyManager(address(vault), address(roleManager));
        adapter = new MockAdapter(IERC20(address(usdc)), address(vault));
        strategyRegistry = new StrategyRegistry(address(roleManager));

        roleManager.grantRole(roleManager.ROLE_VAULT_OPS(), address(manager));

        vm.prank(admin);
        registryStrategyId = strategyRegistry.createStrategy(
            address(usdc), address(adapter), RegistryTypes.RiskTier.Conservative, "ipfs://strategy", 1_000_000 ether
        );
    }

    function testActivateStrategyFromRegistry() public {
        vm.prank(admin);
        manager.setStrategyRegistry(address(strategyRegistry));

        vm.prank(admin);
        manager.activateStrategyFromRegistry(registryStrategyId);

        assertEq(address(vault.activeAdapter()), address(adapter));
    }

    function testApproveAndActivateAdapter() public {
        vm.prank(admin);
        manager.setAdapterApproval(address(adapter), true);
        vm.prank(admin);
        manager.setActiveAdapter(address(adapter));
        assertEq(address(vault.activeAdapter()), address(adapter));
    }

    function testUpdateVaultParameters() public {
        vm.prank(admin);
        manager.updateVaultParameters(200, 75, 100);
        (uint256 cash,, uint256 maxLoss,,) = vault.getConfiguration();
        assertEq(cash, 200);
        assertEq(maxLoss, 100);
    }

    function testSetPayoutRouter() public {
        CampaignRegistry campaignRegistry =
            new CampaignRegistry(address(roleManager), admin, address(strategyRegistry), 0);
        PayoutRouter router = new PayoutRouter(address(roleManager), address(campaignRegistry), admin);
        vm.prank(admin);
        manager.setPayoutRouter(address(router));
        assertEq(address(vault.payoutRouter()), address(router));
    }
}

contract MockERC20 is ERC20 {
    uint8 private _d;

    constructor(string memory n, string memory s, uint8 d) ERC20(n, s) {
        _d = d;
    }

    function decimals() public view override returns (uint8) {
        return _d;
    }
}

contract MockAdapter is IYieldAdapter {
    IERC20 public override asset;
    address public override vault;
    uint256 public invested;

    constructor(IERC20 _a, address _v) {
        asset = _a;
        vault = _v;
    }

    function totalAssets() external view override returns (uint256) {
        return invested;
    }

    function invest(uint256 assets) external override {
        require(msg.sender == vault, "only vault");
        invested += assets;
        emit Invested(assets);
    }

    function divest(uint256 assets) external override returns (uint256) {
        require(msg.sender == vault, "only vault");
        emit Divested(assets, assets);
        return assets;
    }

    function harvest() external override returns (uint256, uint256) {
        require(msg.sender == vault, "only vault");
        emit Harvested(0, 0);
        return (0, 0);
    }

    function emergencyWithdraw() external override returns (uint256) {
        emit EmergencyWithdraw(0);
        return 0;
    }
}
