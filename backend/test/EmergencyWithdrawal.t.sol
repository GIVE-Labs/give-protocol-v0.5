// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./utils/BaseProtocolTest.sol";
import "../src/vault/GiveVault4626.sol";

/// @title EmergencyWithdrawalTest
/// @notice Tests emergency withdrawal functionality and grace period behavior
contract EmergencyWithdrawalTest is BaseProtocolTest {
    address user1;
    address user2;

    function setUp() public override {
        super.setUp();

        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        // Give users some tokens
        deal(address(asset), user1, 1000 ether);
        deal(address(asset), user2, 1000 ether);
    }

    /// @notice Test normal withdrawals work during grace period
    function testNormalWithdrawalWorksDuringGracePeriod() public {
        // User1 deposits
        vm.startPrank(user1);
        asset.approve(address(vault), 1000 ether);
        vault.deposit(1000 ether, user1);
        vm.stopPrank();

        // Admin triggers emergency pause
        vm.prank(admin);
        vault.emergencyPause();

        // Within grace period (23 hours after), normal withdrawal should work
        vm.warp(block.timestamp + 23 hours);

        vm.prank(user1);
        vault.withdraw(500 ether, user1, user1);

        assertEq(
            asset.balanceOf(user1),
            500 ether,
            "User should receive assets"
        );
    }

    /// @notice Test normal withdrawals blocked after grace period
    function testNormalWithdrawalBlockedAfterGracePeriod() public {
        // User1 deposits
        vm.startPrank(user1);
        asset.approve(address(vault), 1000 ether);
        vault.deposit(1000 ether, user1);
        vm.stopPrank();

        // Admin triggers emergency pause
        vm.prank(admin);
        vault.emergencyPause();

        // After grace period (25 hours), normal withdrawal should fail
        vm.warp(block.timestamp + 25 hours);

        vm.prank(user1);
        vm.expectRevert(); // GracePeriodExpired
        vault.withdraw(500 ether, user1, user1);
    }

    /// @notice Test emergency withdrawal works after grace period
    function testEmergencyWithdrawalWorksAfterGracePeriod() public {
        // User1 deposits
        vm.startPrank(user1);
        asset.approve(address(vault), 1000 ether);
        uint256 shares = vault.deposit(1000 ether, user1);
        vm.stopPrank();

        // Admin triggers emergency pause
        vm.prank(admin);
        vault.emergencyPause();

        // After grace period (25 hours)
        vm.warp(block.timestamp + 25 hours);

        // Emergency withdrawal should work
        vm.prank(user1);
        uint256 assets = vault.emergencyWithdrawUser(shares, user1, user1);

        assertGt(assets, 0, "Should withdraw assets");
        assertEq(
            asset.balanceOf(user1),
            assets,
            "User should receive all assets"
        );
        assertEq(vault.balanceOf(user1), 0, "Shares should be burned");
    }

    /// @notice Test emergency withdrawal fails during grace period
    function testEmergencyWithdrawalFailsDuringGracePeriod() public {
        // User1 deposits
        vm.startPrank(user1);
        asset.approve(address(vault), 1000 ether);
        uint256 shares = vault.deposit(1000 ether, user1);
        vm.stopPrank();

        // Admin triggers emergency pause
        vm.prank(admin);
        vault.emergencyPause();

        // Within grace period (10 hours)
        vm.warp(block.timestamp + 10 hours);

        // Emergency withdrawal should fail (use normal withdrawal instead)
        vm.prank(user1);
        vm.expectRevert(); // GracePeriodActive
        vault.emergencyWithdrawUser(shares, user1, user1);
    }

    /// @notice Test emergency withdrawal fails when not in emergency
    function testEmergencyWithdrawalFailsWhenNotInEmergency() public {
        // User1 deposits
        vm.startPrank(user1);
        asset.approve(address(vault), 1000 ether);
        uint256 shares = vault.deposit(1000 ether, user1);
        vm.stopPrank();

        // Try emergency withdrawal without emergency pause
        vm.prank(user1);
        vm.expectRevert(); // NotInEmergency
        vault.emergencyWithdrawUser(shares, user1, user1);
    }

    /// @notice Test emergency withdrawal respects allowances
    function testEmergencyWithdrawalRespectsAllowances() public {
        // User1 deposits
        vm.startPrank(user1);
        asset.approve(address(vault), 1000 ether);
        uint256 shares = vault.deposit(1000 ether, user1);

        // Approve user2 to spend 500 shares
        vault.approve(user2, 500 ether);
        vm.stopPrank();

        // Admin triggers emergency pause
        vm.prank(admin);
        vault.emergencyPause();

        // After grace period
        vm.warp(block.timestamp + 25 hours);

        // User2 can withdraw up to allowance
        vm.prank(user2);
        vault.emergencyWithdrawUser(500 ether, user2, user1);

        assertGt(asset.balanceOf(user2), 0, "User2 should receive assets");

        // User2 cannot withdraw more than allowance
        vm.prank(user2);
        vm.expectRevert(); // InsufficientAllowance
        vault.emergencyWithdrawUser(100 ether, user2, user1);
    }

    /// @notice Test multiple users can emergency withdraw
    function testMultipleUsersCanEmergencyWithdraw() public {
        // User1 deposits
        vm.startPrank(user1);
        asset.approve(address(vault), 1000 ether);
        uint256 shares1 = vault.deposit(1000 ether, user1);
        vm.stopPrank();

        // User2 deposits
        vm.startPrank(user2);
        asset.approve(address(vault), 1000 ether);
        uint256 shares2 = vault.deposit(1000 ether, user2);
        vm.stopPrank();

        // Admin triggers emergency pause
        vm.prank(admin);
        vault.emergencyPause();

        // After grace period
        vm.warp(block.timestamp + 25 hours);

        // User1 withdraws
        vm.prank(user1);
        uint256 assets1 = vault.emergencyWithdrawUser(shares1, user1, user1);

        // User2 withdraws
        vm.prank(user2);
        uint256 assets2 = vault.emergencyWithdrawUser(shares2, user2, user2);

        assertGt(assets1, 0, "User1 should receive assets");
        assertGt(assets2, 0, "User2 should receive assets");
    }

    /// @notice Test emergency withdrawal emits correct event
    function testEmergencyWithdrawalEmitsEvent() public {
        // User1 deposits
        vm.startPrank(user1);
        asset.approve(address(vault), 1000 ether);
        uint256 shares = vault.deposit(1000 ether, user1);
        vm.stopPrank();

        // Admin triggers emergency pause
        vm.prank(admin);
        vault.emergencyPause();

        // After grace period
        vm.warp(block.timestamp + 25 hours);

        // Expect event (note: cannot predict exact assets amount due to rounding)
        vm.expectEmit(true, true, false, false);
        emit GiveVault4626.EmergencyWithdrawal(user1, user1, shares, 0);

        vm.prank(user1);
        vault.emergencyWithdrawUser(shares, user1, user1);
    }
}
