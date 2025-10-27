// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./utils/BaseProtocolTest.sol";
import "../src/adapters/MockYieldAdapter.sol";

contract MockYieldAdapterTest is BaseProtocolTest {
    MockYieldAdapter internal mock;

    function setUp() public override {
        super.setUp();
        mock = MockYieldAdapter(address(adapter));
        vm.prank(admin);
        mock.setACLManager(address(acl));
    }

    function testHarvestWithYieldAndLossSimulation() public {
        uint256 depositAmount = 500 ether;
        asset.mint(address(vault), depositAmount);

        vm.startPrank(address(vault));
        asset.approve(address(mock), depositAmount);
        mock.invest(depositAmount);
        vm.stopPrank();

        asset.mint(admin, 50 ether);
        vm.startPrank(admin);
        asset.approve(address(mock), 50 ether);
        mock.addYield(50 ether);
        vm.stopPrank();

        vm.prank(address(vault));
        (uint256 profit, uint256 loss) = mock.harvest();
        assertEq(loss, 0);
        assertEq(profit, 50 ether);

        uint256 totalAfterProfit = mock.totalAssets();
        assertEq(totalAfterProfit, depositAmount);
        assertEq(asset.balanceOf(address(vault)), 50 ether);

        vm.prank(admin);
        mock.setLossSimulation(true, 100); // 1%

        vm.prank(address(vault));
        (profit, loss) = mock.harvest();
        assertEq(profit, 0);
        assertEq(loss, (totalAfterProfit * 100) / 10_000);

        uint256 totalAfterLoss = mock.totalAssets();
        assertEq(totalAfterLoss, totalAfterProfit - loss);
    }

    function testEmergencyWithdrawResetsAssets() public {
        asset.mint(address(vault), 200 ether);
        vm.startPrank(address(vault));
        asset.approve(address(mock), 200 ether);
        mock.invest(200 ether);
        vm.stopPrank();

        vm.prank(admin);
        uint256 withdrawn = mock.emergencyWithdraw();
        assertEq(withdrawn, 200 ether);
        assertEq(mock.totalAssets(), 0);
        assertEq(asset.balanceOf(address(vault)), 200 ether);
    }
}
