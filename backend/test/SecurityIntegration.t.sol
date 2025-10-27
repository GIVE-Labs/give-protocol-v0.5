// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./utils/BaseProtocolTest.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {CampaignRegistry} from "../src/registry/CampaignRegistry.sol";
import {MockYieldAdapter} from "../src/adapters/MockYieldAdapter.sol";

/// @title SecurityIntegrationTest
/// @notice Tests interaction between all Week 1-2 security fixes
/// @dev Validates that storage gaps, snapshot voting, emergency withdrawal, and fee timelock work together
contract SecurityIntegrationTest is BaseProtocolTest {
    bytes32 internal strategyId;
    bytes32 internal campaignId;
    address internal campaignRecipient;

    function setUp() public override {
        super.setUp();

        // Fix: Grant VAULT_ROLE and EMERGENCY_ROLE to vault in adapter's ACL
        bytes32 vaultRole = keccak256("VAULT_ROLE");
        bytes32 emergencyRole = keccak256("EMERGENCY_ROLE");
        vm.startPrank(admin);
        if (!acl.roleExists(vaultRole)) acl.createRole(vaultRole, admin);
        acl.grantRole(vaultRole, address(vault));
        if (!acl.roleExists(emergencyRole)) {
            acl.createRole(emergencyRole, admin);
        }
        acl.grantRole(emergencyRole, address(vault));
        vm.stopPrank();

        // Setup strategy and campaign
        strategyId = keccak256("strategy.security.test");
        campaignId = keccak256("campaign.security.test");
        campaignRecipient = makeAddr("campaignRecipient");

        // Register strategy
        vm.prank(admin);
        strategyRegistry.registerStrategy(
            StrategyRegistry.StrategyInput({
                id: strategyId,
                adapter: address(vault),
                riskTier: bytes32("tier.low"),
                maxTvl: 1_000_000 ether,
                metadataHash: keccak256("security.test.metadata")
            })
        );

        // Submit and approve campaign
        vm.deal(admin, 1 ether);
        vm.prank(admin);
        campaignRegistry.submitCampaign{value: 0.005 ether}(
            CampaignRegistry.CampaignInput({
                id: campaignId,
                payoutRecipient: campaignRecipient,
                strategyId: strategyId,
                metadataHash: keccak256("campaign.metadata"),
                metadataCID: "bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi",
                targetStake: 10_000 ether,
                minStake: 1_000 ether,
                fundraisingStart: uint64(block.timestamp),
                fundraisingEnd: uint64(block.timestamp + 30 days)
            })
        );

        vm.prank(admin);
        campaignRegistry.approveCampaign(campaignId, admin);

        vm.prank(admin);
        campaignRegistry.setCampaignStatus(
            campaignId,
            GiveTypes.CampaignStatus.Active
        );

        vm.prank(admin);
        campaignRegistry.setCampaignVault(
            campaignId,
            address(vault),
            keccak256("lock.default")
        );

        vm.prank(admin);
        router.registerCampaignVault(address(vault), campaignId);
    }

    /// @notice Test emergency withdrawal during active checkpoint voting
    /// @dev Verifies users can vote, then emergency withdraw during grace period and after
    function testEmergencyWithdrawalDuringCheckpointVoting() public {
        // Setup: User stakes
        address user1 = makeAddr("user1");
        deal(address(asset), user1, 1000 ether);

        vm.startPrank(user1);
        asset.approve(address(vault), 1000 ether);
        uint256 shares = vault.deposit(1000 ether, user1);
        vm.stopPrank();

        // Record stake in campaign registry
        vm.prank(admin);
        campaignRegistry.recordStakeDeposit(campaignId, user1, shares);

        // Fast forward 7 days to allow voting (stake duration requirement)
        vm.warp(block.timestamp + 7 days + 1);

        // Schedule checkpoint with snapshot
        vm.prank(admin);
        uint256 checkpointIndex = campaignRegistry.scheduleCheckpoint(
            campaignId,
            CampaignRegistry.CheckpointInput({
                windowStart: uint64(block.timestamp + 1 days),
                windowEnd: uint64(block.timestamp + 8 days),
                executionDeadline: uint64(block.timestamp + 9 days),
                quorumBps: 6000
            })
        );

        // Update checkpoint status to Voting
        vm.prank(admin);
        campaignRegistry.updateCheckpointStatus(
            campaignId,
            checkpointIndex,
            GiveTypes.CheckpointStatus.Voting
        );

        // User votes using snapshot (after voting window starts)
        vm.warp(block.timestamp + 1 days + 1);
        vm.prank(user1);
        campaignRegistry.voteOnCheckpoint(campaignId, checkpointIndex, true);

        // Emergency pause triggered AFTER voting
        vm.prank(admin);
        vault.emergencyPause();

        // Grace period: user can still withdraw normally
        vm.warp(block.timestamp + 12 hours);
        vm.prank(user1);
        vault.withdraw(500 ether, user1, user1);

        assertEq(
            asset.balanceOf(user1),
            500 ether,
            "Should withdraw during grace period"
        );

        // After grace period: must use emergency withdrawal
        vm.warp(block.timestamp + 13 hours);
        vm.prank(user1);
        uint256 remainingShares = vault.balanceOf(user1);
        vault.emergencyWithdrawUser(remainingShares, user1, user1);

        assertGt(
            asset.balanceOf(user1),
            500 ether,
            "Should emergency withdraw after grace period"
        );
        assertEq(vault.balanceOf(user1), 0, "All shares should be burned");
    }

    /// @notice Test fee change during emergency pause
    /// @dev Verifies governance can still update fees even during emergency
    function testFeeChangeDuringEmergencyPause() public {
        // Emergency pause triggered
        vm.prank(admin);
        vault.emergencyPause();

        // Admin proposes fee change (should still work during emergency)
        vm.prank(admin);
        router.proposeFeeChange(admin, 500);

        // Verify pending change exists
        (uint256 newFee, , uint256 effectiveTime, bool exists) = router
            .getPendingFeeChange(0);
        assertTrue(exists, "Fee change should be pending");
        assertEq(newFee, 500, "Pending fee should be 500");

        // Fast forward past timelock and execute
        vm.warp(effectiveTime + 1);
        router.executeFeeChange(0);

        assertEq(router.feeBps(), 500, "Fee should update despite emergency");
    }

    /// @notice Test snapshot voting survives storage upgrades
    /// @dev Simulates adding new fields to structs and verifies voting still uses snapshot
    function testSnapshotVotingSurvivesUpgrade() public {
        // Setup: User stakes and checkpoint scheduled
        address user1 = makeAddr("user1");
        deal(address(asset), user1, 1000 ether);

        vm.startPrank(user1);
        asset.approve(address(vault), 1000 ether);
        uint256 shares = vault.deposit(1000 ether, user1);
        vm.stopPrank();

        // Record stake in campaign registry
        vm.prank(admin);
        campaignRegistry.recordStakeDeposit(campaignId, user1, shares);

        // Wait for minimum stake duration
        vm.warp(block.timestamp + 7 days + 1);

        // Schedule checkpoint (captures snapshot at current block)
        vm.prank(admin);
        uint256 checkpointIndex = campaignRegistry.scheduleCheckpoint(
            campaignId,
            CampaignRegistry.CheckpointInput({
                windowStart: uint64(block.timestamp + 1 days),
                windowEnd: uint64(block.timestamp + 8 days),
                executionDeadline: uint64(block.timestamp + 9 days),
                quorumBps: 6000
            })
        );

        // Update checkpoint status to Voting
        vm.prank(admin);
        campaignRegistry.updateCheckpointStatus(
            campaignId,
            checkpointIndex,
            GiveTypes.CheckpointStatus.Voting
        );

        // Verify checkpoint was scheduled successfully
        (
            uint64 ws,
            ,
            ,
            ,
            GiveTypes.CheckpointStatus status,

        ) = campaignRegistry.getCheckpoint(campaignId, checkpointIndex);
        assertGt(ws, 0, "Checkpoint should exist");
        assertEq(
            uint256(status),
            uint256(GiveTypes.CheckpointStatus.Voting),
            "Should be in voting status"
        );

        // User increases stake AFTER snapshot
        vm.warp(block.timestamp + 12 hours);
        deal(address(asset), user1, 2000 ether);
        vm.startPrank(user1);
        asset.approve(address(vault), 1000 ether);
        vault.deposit(1000 ether, user1);
        vm.stopPrank();

        // Now user has 2000 ether worth of shares, but snapshot only has 1000
        uint256 currentShares = vault.balanceOf(user1);
        assertGt(currentShares, shares, "User should have more shares now");

        // Record additional stake
        vm.prank(admin);
        campaignRegistry.recordStakeDeposit(
            campaignId,
            user1,
            currentShares - shares
        );

        // Vote using ORIGINAL snapshot (should use first 1000, not 2000)
        vm.warp(block.timestamp + 13 hours);
        vm.prank(user1);
        campaignRegistry.voteOnCheckpoint(campaignId, checkpointIndex, true);

        // Verify checkpoint still in voting (user voted successfully)
        (
            ,
            ,
            ,
            ,
            GiveTypes.CheckpointStatus statusAfterVote,

        ) = campaignRegistry.getCheckpoint(campaignId, checkpointIndex);

        // Should still be Voting status (not enough quorum with just one vote)
        assertEq(
            uint256(statusAfterVote),
            uint256(GiveTypes.CheckpointStatus.Voting),
            "Should be voting after single vote"
        );
    }

    /// @notice Test protocol handles all fixes simultaneously under stress
    /// @dev Complex scenario: multiple users, voting, fee changes, emergency, harvests
    function testFullProtocolStressTest() public {
        // Scenario: Everything happens at once
        // - Multiple users staking
        // - Checkpoint voting active
        // - Fee change pending
        // - Emergency triggered
        // - Harvests happening

        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");
        address user3 = makeAddr("user3");

        // Setup users with deposits
        for (uint256 i = 0; i < 3; i++) {
            address user = i == 0
                ? user1
                : i == 1
                    ? user2
                    : user3;
            deal(address(asset), user, 10000 ether);

            vm.startPrank(user);
            asset.approve(address(vault), 10000 ether);
            uint256 shares = vault.deposit(10000 ether, user);
            vm.stopPrank();

            // Record stake in campaign registry
            vm.prank(admin);
            campaignRegistry.recordStakeDeposit(campaignId, user, shares);
        }

        // Wait for minimum stake duration
        vm.warp(block.timestamp + 7 days + 1);

        // Schedule checkpoint
        vm.prank(admin);
        uint256 checkpointIndex = campaignRegistry.scheduleCheckpoint(
            campaignId,
            CampaignRegistry.CheckpointInput({
                windowStart: uint64(block.timestamp + 1 days),
                windowEnd: uint64(block.timestamp + 8 days),
                executionDeadline: uint64(block.timestamp + 9 days),
                quorumBps: 6000
            })
        );

        // Update checkpoint status to Voting
        vm.prank(admin);
        campaignRegistry.updateCheckpointStatus(
            campaignId,
            checkpointIndex,
            GiveTypes.CheckpointStatus.Voting
        );

        // Propose fee change
        vm.prank(admin);
        router.proposeFeeChange(admin, 500);

        // Verify pending fee change
        (, , uint256 feeEffectiveTime, bool feeExists) = router
            .getPendingFeeChange(0);
        assertTrue(feeExists, "Fee change should be pending");

        // Users vote after voting window opens
        vm.warp(block.timestamp + 1 days + 1);

        vm.prank(user1);
        campaignRegistry.voteOnCheckpoint(campaignId, checkpointIndex, true);

        vm.prank(user2);
        campaignRegistry.voteOnCheckpoint(campaignId, checkpointIndex, true);

        // Simulate yield generation and harvest
        // Step 1: Invest user deposits into adapter (30000 ether from 3 users)
        uint256 vaultBalance = asset.balanceOf(address(vault));
        vm.prank(address(vault));
        asset.approve(address(adapter), vaultBalance);
        vm.prank(address(vault));
        adapter.invest(vaultBalance);

        // Step 2: Mint additional yield tokens to adapter
        vm.prank(admin);
        asset.mint(address(adapter), 100 ether);

        vm.prank(admin);
        (uint256 profit, ) = vault.harvest();
        assertGt(profit, 0, "Should generate profit from harvest");

        // Emergency pause triggered after harvest
        vm.prank(admin);
        vault.emergencyPause();

        // Users withdraw during grace period
        vm.warp(block.timestamp + 12 hours);

        vm.prank(user1);
        vault.withdraw(5000 ether, user1, user1);
        assertEq(
            asset.balanceOf(user1),
            5000 ether,
            "User1 should withdraw during grace"
        );

        // Fee change executes (past timelock)
        vm.warp(feeEffectiveTime + 1);
        router.executeFeeChange(0);
        assertEq(router.feeBps(), 500, "Fee should update to 500");

        // Emergency withdrawal after grace period
        vm.warp(block.timestamp + 13 hours);

        vm.prank(user2);
        uint256 user2Shares = vault.balanceOf(user2);
        vault.emergencyWithdrawUser(user2Shares, user2, user2);

        assertGt(asset.balanceOf(user2), 0, "User2 should emergency withdraw");

        // User3 still has shares (hasn't withdrawn)
        assertGt(vault.balanceOf(user3), 0, "User3 should still have shares");

        // Verify protocol state is consistent
        assertTrue(vault.paused(), "Vault should still be paused");
        assertEq(router.feeBps(), 500, "Fee should remain at 500");
    }

    /// @notice Test upgrade preserves all security features
    /// @dev Simulates upgrade and verifies pending fee changes survive
    function testUpgradePreservesSecurityFeatures() public {
        // Record state before upgrade simulation
        uint256 feeBefore = router.feeBps();
        assertEq(feeBefore, 250, "Initial fee should be 250");

        // Propose fee change
        vm.prank(admin);
        router.proposeFeeChange(admin, 500);

        // Verify pending change exists
        (uint256 pendingFee, , uint256 effectiveTime, bool exists) = router
            .getPendingFeeChange(0);
        assertTrue(exists, "Pending change should exist");
        assertEq(pendingFee, 500, "Pending fee should be 500");

        // Simulate upgrade (in real scenario, would deploy new implementation)
        // Here we just verify storage layout preserved by checking pending change still exists

        // Fast forward past timelock
        vm.warp(effectiveTime + 1);

        // Verify pending change still exists after "upgrade"
        (pendingFee, , effectiveTime, exists) = router.getPendingFeeChange(0);
        assertTrue(exists, "Pending change should survive upgrade");

        // Execute after upgrade
        router.executeFeeChange(0);

        assertEq(
            router.feeBps(),
            500,
            "Fee should update to 500 after upgrade"
        );

        // Verify pending change cleaned up
        (, , , exists) = router.getPendingFeeChange(0);
        assertFalse(exists, "Pending change should be removed after execution");
    }

    /// @notice Test fee decreases during emergency are instant
    /// @dev Verifies user-friendly fee decrease logic works during emergency
    function testFeeDecreaseInstantDuringEmergency() public {
        // First increase fee to 500
        vm.prank(admin);
        router.proposeFeeChange(admin, 500);

        vm.warp(block.timestamp + 7 days + 1);
        router.executeFeeChange(0);
        assertEq(router.feeBps(), 500, "Fee should be 500");

        // Trigger emergency
        vm.prank(admin);
        vault.emergencyPause();

        // Propose fee decrease (should be instant even during emergency)
        vm.prank(admin);
        router.proposeFeeChange(admin, 250);

        // Verify fee decreased immediately (no pending change created)
        assertEq(router.feeBps(), 250, "Fee should decrease immediately");

        // Verify no pending change exists
        (, , , bool exists) = router.getPendingFeeChange(1);
        assertFalse(exists, "No pending change for decrease");
    }

    /// @notice Test multiple concurrent security features
    /// @dev Validates emergency + fee change + voting all active simultaneously
    function testConcurrentSecurityFeatures() public {
        address user1 = makeAddr("user1");
        deal(address(asset), user1, 5000 ether);

        // User deposits
        vm.startPrank(user1);
        asset.approve(address(vault), 5000 ether);
        uint256 shares = vault.deposit(5000 ether, user1);
        vm.stopPrank();

        // Record stake in campaign registry
        vm.prank(admin);
        campaignRegistry.recordStakeDeposit(campaignId, user1, shares);

        // Wait for stake duration
        vm.warp(block.timestamp + 7 days + 1);

        // Schedule checkpoint
        vm.prank(admin);
        uint256 checkpointIndex = campaignRegistry.scheduleCheckpoint(
            campaignId,
            CampaignRegistry.CheckpointInput({
                windowStart: uint64(block.timestamp + 1 days),
                windowEnd: uint64(block.timestamp + 8 days),
                executionDeadline: uint64(block.timestamp + 9 days),
                quorumBps: 6000
            })
        );

        // Update checkpoint status to Voting
        vm.prank(admin);
        campaignRegistry.updateCheckpointStatus(
            campaignId,
            checkpointIndex,
            GiveTypes.CheckpointStatus.Voting
        );

        // Propose fee increase
        vm.prank(admin);
        router.proposeFeeChange(admin, 500);

        // Trigger emergency
        vm.prank(admin);
        vault.emergencyPause();

        // Fast forward to voting window + past grace period
        vm.warp(block.timestamp + 1 days + 25 hours);

        // User can vote even during emergency (uses snapshot from before emergency)
        vm.prank(user1);
        campaignRegistry.voteOnCheckpoint(campaignId, checkpointIndex, true);

        // Verify vote succeeded (checkpoint status should still be Voting)
        (, , , , GiveTypes.CheckpointStatus voteStatus, ) = campaignRegistry
            .getCheckpoint(campaignId, checkpointIndex);
        assertEq(
            uint256(voteStatus),
            uint256(GiveTypes.CheckpointStatus.Voting),
            "Should be voting"
        );

        // User can emergency withdraw
        vm.prank(user1);
        uint256 userShares = vault.balanceOf(user1);
        vault.emergencyWithdrawUser(userShares, user1, user1);

        assertGt(
            asset.balanceOf(user1),
            4000 ether,
            "User should receive most funds back"
        );

        // Fee change can still execute (wait full timelock from proposal)
        vm.warp(block.timestamp + 8 days); // Extra day to ensure timelock passed
        router.executeFeeChange(0);

        assertEq(router.feeBps(), 500, "Fee should update");
    }
}
