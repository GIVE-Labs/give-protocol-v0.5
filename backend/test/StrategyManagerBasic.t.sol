// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/vault/GiveVault4626.sol";
import "../src/manager/StrategyManager.sol";
import "../src/governance/ACLManager.sol";
import "../src/registry/StrategyRegistry.sol";
import "../src/registry/CampaignRegistry.sol";
import "../src/interfaces/IYieldAdapter.sol";

contract StrategyManagerBasicTest is Test {
    GiveVault4626 public vault;
    StrategyManager public manager;
    ACLManager public acl;
    StrategyRegistry public strategyRegistry;
    CampaignRegistry public campaignRegistry;
    MockERC20 public usdc;
    MockAdapter public adapter;

    address public admin = address(0xA11CE);

    function setUp() public {
        // Deploy ACL
        ACLManager aclImpl = new ACLManager();
        ERC1967Proxy aclProxy =
            new ERC1967Proxy(address(aclImpl), abi.encodeCall(ACLManager.initialize, (admin, admin)));
        acl = ACLManager(address(aclProxy));

        // Deploy StrategyRegistry
        StrategyRegistry strategyImpl = new StrategyRegistry();
        ERC1967Proxy strategyProxy =
            new ERC1967Proxy(address(strategyImpl), abi.encodeCall(StrategyRegistry.initialize, (address(acl))));
        strategyRegistry = StrategyRegistry(address(strategyProxy));

        // Deploy CampaignRegistry
        CampaignRegistry campaignImpl = new CampaignRegistry();
        ERC1967Proxy campaignProxy = new ERC1967Proxy(
            address(campaignImpl),
            abi.encodeCall(CampaignRegistry.initialize, (address(acl), address(strategyRegistry)))
        );
        campaignRegistry = CampaignRegistry(address(campaignProxy));

        usdc = new MockERC20("Test USDC", "TUSDC", 6);
        vault = new GiveVault4626(IERC20(address(usdc)), "GIVE USDC", "gvUSDC", admin);
        manager = new StrategyManager(address(vault), admin, address(strategyRegistry), address(campaignRegistry));
        adapter = new MockAdapter(IERC20(address(usdc)), address(vault));

        // Grant the manager permission to call vault setters invoked by manager
        vm.startPrank(admin);
        vault.grantRole(vault.VAULT_MANAGER_ROLE(), address(manager));

        // Create and grant strategy manager roles
        acl.createRole(manager.STRATEGY_MANAGER_ROLE(), admin);
        acl.createRole(manager.EMERGENCY_ROLE(), admin);
        acl.createRole(manager.STRATEGY_ADMIN_ROLE(), admin);
        acl.grantRole(manager.STRATEGY_MANAGER_ROLE(), admin);
        vm.stopPrank();
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

    function testSetDonationRouter() public {
        address router = makeAddr("router");
        vm.prank(admin);
        manager.setDonationRouter(router);
        assertEq(address(vault.donationRouter()), router);
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
