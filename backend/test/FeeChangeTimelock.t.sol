// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./utils/BaseProtocolTest.sol";
import "../src/payout/PayoutRouter.sol";

/// @title FeeChangeTimelockTest
/// @notice Tests fee change timelock and governance delay
contract FeeChangeTimelockTest is BaseProtocolTest {
    function setUp() public override {
        super.setUp();
        // Admin already has FEE_MANAGER_ROLE from BaseProtocolTest
    }

    /// @notice Test fee decrease is instant (no timelock)
    function testFeeDecreaseIsInstant() public {
        // First set fee to 500 (5%)
        vm.prank(admin);
        router.proposeFeeChange(admin, 500);
        vm.warp(block.timestamp + 7 days + 1);
        router.executeFeeChange(0);

        // Now test instant decrease to 250 (2.5%)
        vm.prank(admin);
        router.proposeFeeChange(admin, 250);

        // Check fee was updated immediately
        assertEq(router.feeBps(), 250, "Fee should decrease immediately");
    }

    /// @notice Test fee increase requires timelock
    function testFeeIncreaseRequiresTimelock() public {
        // Current fee: 0
        uint256 currentFee = router.feeBps();

        // Propose fee increase to 400 (4%)
        vm.prank(admin);
        router.proposeFeeChange(admin, 400);

        // Fee should NOT be updated immediately
        assertEq(router.feeBps(), currentFee, "Fee should not increase immediately");

        // Should create pending change
        (uint256 newFee, address recipient, uint256 effectiveTime, bool exists) = router.getPendingFeeChange(0);
        assertTrue(exists, "Pending change should exist");
        assertEq(newFee, 400, "Pending fee should be 400");
    }

    /// @notice Test cannot execute fee change before timelock
    function testCannotExecuteBeforeTimelock() public {
        // Propose fee increase
        vm.prank(admin);
        router.proposeFeeChange(admin, 400);

        // Try to execute immediately (should fail)
        vm.expectRevert(); // TimelockNotExpired
        router.executeFeeChange(0);

        // Try after 6 days (should still fail)
        vm.warp(block.timestamp + 6 days);
        vm.expectRevert(); // TimelockNotExpired
        router.executeFeeChange(0);
    }

    /// @notice Test can execute fee change after timelock
    function testCanExecuteAfterTimelock() public {
        // Propose fee increase
        vm.prank(admin);
        router.proposeFeeChange(admin, 400);

        // Wait for timelock (7 days + 1 second)
        vm.warp(block.timestamp + 7 days + 1);

        // Execute (anyone can call)
        router.executeFeeChange(0);

        // Verify fee was updated
        assertEq(router.feeBps(), 400, "Fee should be updated after timelock");

        // Verify pending change was removed
        (,,, bool exists) = router.getPendingFeeChange(0);
        assertFalse(exists, "Pending change should be removed");
    }

    /// @notice Test fee increase limited to max per change
    function testFeeIncreaseLimited() public {
        // Current fee: 250 bps (2.5%)
        // Try to increase by 300 bps (to 550 = 5.5%) - should fail, max increase is 250 bps
        vm.prank(admin);
        vm.expectRevert(); // FeeIncreaseTooLarge
        router.proposeFeeChange(admin, 550);
    }

    /// @notice Test multiple fee increases can be staged
    function testMultipleFeeIncreasesCanBeStaged() public {
        // Current fee: 250 bps (2.5%)

        // First increase to 500 (5%)
        vm.prank(admin);
        router.proposeFeeChange(admin, 500);

        // Wait and execute
        vm.warp(block.timestamp + 7 days + 1);
        router.executeFeeChange(0);

        // Second increase to 750 (7.5%)
        vm.prank(admin);
        router.proposeFeeChange(admin, 750);

        // Wait and execute (need another full 7 days from the new timestamp)
        vm.warp(block.timestamp + 7 days + 2);
        router.executeFeeChange(1);

        // Verify final fee
        assertEq(router.feeBps(), 750, "Fee should be 7.5% after two increases");
    }
    /// @notice Test admin can cancel pending fee change

    function testAdminCanCancelPendingChange() public {
        // Propose fee increase (from 250 to 500)
        vm.prank(admin);
        router.proposeFeeChange(admin, 500);

        // Verify pending change exists
        (,,, bool exists) = router.getPendingFeeChange(0);
        assertTrue(exists, "Pending change should exist");

        // Admin cancels
        vm.prank(admin);
        router.cancelFeeChange(0);

        // Verify pending change removed
        (,,, exists) = router.getPendingFeeChange(0);
        assertFalse(exists, "Pending change should be removed");

        // Cannot execute cancelled change
        vm.warp(block.timestamp + 7 days + 1);
        vm.expectRevert(); // FeeChangeNotFound
        router.executeFeeChange(0);
    }

    /// @notice Test non-admin cannot propose fee change
    function testNonAdminCannotProposeFeeChange() public {
        address attacker = makeAddr("attacker");

        vm.prank(attacker);
        vm.expectRevert(); // Unauthorized
        router.proposeFeeChange(attacker, 500);
    }

    /// @notice Test non-admin cannot cancel fee change
    function testNonAdminCannotCancelFeeChange() public {
        // Propose fee increase
        vm.prank(admin);
        router.proposeFeeChange(admin, 500);

        // Attacker tries to cancel
        address attacker = makeAddr("attacker");
        vm.prank(attacker);
        vm.expectRevert(); // Unauthorized
        router.cancelFeeChange(0);
    }

    /// @notice Test isFeeChangeReady view function
    function testIsFeeChangeReadyView() public {
        // Propose fee increase
        vm.prank(admin);
        router.proposeFeeChange(admin, 500);

        // Should not be ready immediately
        assertFalse(router.isFeeChangeReady(0), "Should not be ready immediately");

        // Should not be ready after 6 days
        vm.warp(block.timestamp + 6 days);
        assertFalse(router.isFeeChangeReady(0), "Should not be ready after 6 days");

        // Should be ready after 7 days
        vm.warp(block.timestamp + 1 days + 1);
        assertTrue(router.isFeeChangeReady(0), "Should be ready after 7 days");
    }

    /// @notice Test fee change events
    function testFeeChangeEvents() public {
        // Expect FeeChangeProposed event
        vm.expectEmit(true, true, false, true);
        emit PayoutRouter.FeeChangeProposed(0, admin, 500, block.timestamp + 7 days);

        vm.prank(admin);
        router.proposeFeeChange(admin, 500);

        // Wait for timelock
        vm.warp(block.timestamp + 7 days + 1);

        // Expect FeeChangeExecuted event
        vm.expectEmit(true, false, false, true);
        emit PayoutRouter.FeeChangeExecuted(0, 500, admin);

        router.executeFeeChange(0);
    }

    /// @notice Test fee change respects MAX_FEE_BPS
    function testFeeChangeRespectsMaxFee() public {
        // Try to set fee above max (10%)
        vm.prank(admin);
        vm.expectRevert(); // InvalidConfiguration
        router.proposeFeeChange(admin, 1100); // 11%
    }
}
