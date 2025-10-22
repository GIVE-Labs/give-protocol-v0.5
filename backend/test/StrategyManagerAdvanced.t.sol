// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./utils/BaseProtocolTest.sol";
import "../src/manager/StrategyManager.sol";
import "../src/interfaces/IYieldAdapter.sol";
import "../src/utils/Errors.sol";

contract StaticYieldAdapter is IYieldAdapter {
    IERC20 private immutable adapterAsset;
    address private immutable adapterVault;
    uint256 internal assetsHeld;

    constructor(address asset_, address vault_) {
        adapterAsset = IERC20(asset_);
        adapterVault = vault_;
    }

    modifier onlyVault() {
        if (msg.sender != adapterVault) revert Errors.OnlyVault();
        _;
    }

    function asset() external view override returns (IERC20) {
        return adapterAsset;
    }

    function totalAssets() external view override returns (uint256) {
        return assetsHeld;
    }

    function invest(uint256 amount) external override onlyVault {
        assetsHeld += amount;
        emit Invested(amount);
    }

    function divest(uint256 amount) external override onlyVault returns (uint256 returned) {
        returned = amount > assetsHeld ? assetsHeld : amount;
        assetsHeld -= returned;
        emit Divested(amount, returned);
    }

    function harvest() external override onlyVault returns (uint256 profit, uint256 loss) {
        emit Harvested(0, 0);
        return (0, 0);
    }

    function emergencyWithdraw() external override onlyVault returns (uint256 returned) {
        returned = assetsHeld;
        assetsHeld = 0;
        emit EmergencyWithdraw(returned);
    }

    function vault() external view override returns (address) {
        return adapterVault;
    }

    function setAssets(uint256 newAssets) external {
        assetsHeld = newAssets;
    }
}

contract StrategyManagerAdvancedTest is BaseProtocolTest {
    StrategyManager internal manager;
    StaticYieldAdapter internal adapterA;
    StaticYieldAdapter internal adapterB;

    function setUp() public override {
        super.setUp();
        manager = new StrategyManager(address(vault), admin);

        vm.startPrank(admin);
        vault.grantRole(vault.VAULT_MANAGER_ROLE(), address(manager));
        vault.grantRole(vault.PAUSER_ROLE(), address(manager));
        manager.setACLManager(address(acl));
        vm.stopPrank();

        adapterA = new StaticYieldAdapter(address(asset), address(vault));
        adapterB = new StaticYieldAdapter(address(asset), address(vault));
    }

    function testAdapterApprovalLifecycleAndRebalance() public {
        vm.startPrank(admin);
        manager.setAdapterApproval(address(adapterA), true);
        manager.setAdapterApproval(address(adapterB), true);
        manager.setActiveAdapter(address(adapterA));
        vm.stopPrank();

        adapterA.setAssets(50 ether);
        adapterB.setAssets(100 ether);

        vm.prank(admin);
        manager.rebalance();
        assertEq(address(vault.activeAdapter()), address(adapterB));

        vm.startPrank(admin);
        manager.setAdapterApproval(address(adapterB), false);
        vm.expectRevert(Errors.InvalidAdapter.selector);
        manager.setActiveAdapter(address(adapterB));
        vm.stopPrank();

        address[] memory approved = manager.getApprovedAdapters();
        assertEq(approved.length, 1);
        assertEq(approved[0], address(adapterA));
    }

    function testEmergencyControls() public {
        vm.startPrank(admin);
        manager.setAdapterApproval(address(adapterA), true);
        manager.setActiveAdapter(address(adapterA));
        vm.expectRevert(Errors.ParameterOutOfRange.selector);
        manager.setEmergencyExitThreshold(6000);
        manager.setEmergencyExitThreshold(2000);
        manager.setAutoRebalanceEnabled(false);
        vm.expectRevert(Errors.ParameterOutOfRange.selector);
        manager.setRebalanceInterval(30 minutes);
        manager.setRebalanceInterval(2 hours);
        vm.stopPrank();

        vm.prank(admin);
        manager.activateEmergencyMode();
        assertTrue(manager.emergencyMode());

        vm.prank(admin);
        manager.setInvestPaused(true);
        assertTrue(vault.investPaused());

        vm.prank(admin);
        manager.setHarvestPaused(true);
        assertTrue(vault.harvestPaused());

        vm.prank(admin);
        manager.deactivateEmergencyMode();
        assertFalse(manager.emergencyMode());
    }
}
