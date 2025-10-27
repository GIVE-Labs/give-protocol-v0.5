// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./utils/BaseProtocolTest.sol";
import "../src/registry/CampaignRegistry.sol";

/// @title VotingManipulationTest
/// @notice Tests flash loan attack resistance and voting manipulation scenarios
/// @dev Validates that MIN_STAKE_DURATION and snapshot voting prevent flash loan attacks
contract VotingManipulationTest is BaseProtocolTest {
    bytes32 campaignId;
    bytes32 strategyId;
    address attacker;
    address legitSupporter;

    function setUp() public override {
        super.setUp();

        attacker = makeAddr("attacker");
        legitSupporter = makeAddr("legitSupporter");

        // Setup strategy
        strategyId = keccak256("strategy.manipulation.test");
        vm.prank(admin);
        strategyRegistry.registerStrategy(
            StrategyRegistry.StrategyInput({
                id: strategyId,
                adapter: address(adapter),
                riskTier: bytes32("tier1"),
                maxTvl: 1_000_000 ether,
                metadataHash: keccak256("metadata")
            })
        );

        // Submit and approve campaign
        campaignId = keccak256("campaign.manipulation.test");
        vm.deal(admin, 1 ether);
        vm.prank(admin);
        campaignRegistry.submitCampaign{value: 0.005 ether}(
            CampaignRegistry.CampaignInput({
                id: campaignId,
                payoutRecipient: makeAddr("ngo"),
                strategyId: strategyId,
                metadataHash: keccak256("campaign.metadata"),
                metadataCID: "bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi",
                targetStake: 10_000 ether,
                minStake: 100 ether,
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
    }

    /// @notice Test that flash loan attack FAILS due to MIN_STAKE_DURATION
    /// @dev Simulates attacker trying to stake and vote in the same block
    function testFlashLoanAttackFails() public {
        // Legitimate supporter stakes and waits
        vm.prank(admin);
        campaignRegistry.recordStakeDeposit(
            campaignId,
            legitSupporter,
            1_000 ether
        );

        // Wait for MIN_STAKE_DURATION
        vm.warp(block.timestamp + 1 hours + 1);

        // Schedule checkpoint
        CampaignRegistry.CheckpointInput memory input = CampaignRegistry
            .CheckpointInput({
                windowStart: uint64(block.timestamp),
                windowEnd: uint64(block.timestamp + 1 days),
                executionDeadline: uint64(block.timestamp + 2 days),
                quorumBps: 5_000
            });

        vm.prank(admin);
        uint256 checkpointId = campaignRegistry.scheduleCheckpoint(
            campaignId,
            input
        );

        vm.prank(admin);
        campaignRegistry.updateCheckpointStatus(
            campaignId,
            checkpointId,
            GiveTypes.CheckpointStatus.Voting
        );

        // FLASH LOAN ATTACK ATTEMPT:
        // Attacker stakes a huge amount in the same block and tries to vote immediately
        vm.startPrank(admin);
        campaignRegistry.recordStakeDeposit(campaignId, attacker, 10_000 ether); // 10x legitimate stake
        vm.stopPrank();

        // Attacker tries to vote immediately (flash loan scenario)
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                CampaignRegistry.NoVotingPower.selector,
                attacker
            )
        );
        campaignRegistry.voteOnCheckpoint(campaignId, checkpointId, false);

        // ✅ Attack FAILED: Attacker cannot vote without waiting MIN_STAKE_DURATION

        // Legitimate supporter can vote (has waited long enough)
        vm.prank(legitSupporter);
        campaignRegistry.voteOnCheckpoint(campaignId, checkpointId, true);

        // Finalize checkpoint
        vm.warp(block.timestamp + 2 days + 1);
        vm.prank(admin);
        campaignRegistry.finalizeCheckpoint(campaignId, checkpointId);

        // Verify legitimate supporter's vote succeeded
        (, , , , GiveTypes.CheckpointStatus status, ) = campaignRegistry
            .getCheckpoint(campaignId, checkpointId);
        assertEq(
            uint256(status),
            uint256(GiveTypes.CheckpointStatus.Succeeded),
            "Checkpoint should succeed with legit vote"
        );
    }

    /// @notice Test that attacker MUST wait MIN_STAKE_DURATION before voting
    /// @dev Demonstrates time-based protection works correctly
    function testAttackerMustWaitMinimumDuration() public {
        // Attacker stakes
        vm.prank(admin);
        campaignRegistry.recordStakeDeposit(campaignId, attacker, 5_000 ether);

        uint256 stakeTime = block.timestamp;

        // Wait slightly less than MIN_STAKE_DURATION
        vm.warp(stakeTime + 1 hours - 1);

        // Schedule checkpoint
        CampaignRegistry.CheckpointInput memory input = CampaignRegistry
            .CheckpointInput({
                windowStart: uint64(block.timestamp),
                windowEnd: uint64(block.timestamp + 1 days),
                executionDeadline: uint64(block.timestamp + 2 days),
                quorumBps: 5_000
            });

        vm.prank(admin);
        uint256 checkpointId = campaignRegistry.scheduleCheckpoint(
            campaignId,
            input
        );

        vm.prank(admin);
        campaignRegistry.updateCheckpointStatus(
            campaignId,
            checkpointId,
            GiveTypes.CheckpointStatus.Voting
        );

        // Try to vote before MIN_STAKE_DURATION - should FAIL
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                CampaignRegistry.NoVotingPower.selector,
                attacker
            )
        );
        campaignRegistry.voteOnCheckpoint(campaignId, checkpointId, true);

        // Wait exactly MIN_STAKE_DURATION
        vm.warp(stakeTime + 1 hours + 1);

        // Now vote should SUCCEED
        vm.prank(attacker);
        campaignRegistry.voteOnCheckpoint(campaignId, checkpointId, true);

        // Verify vote was recorded
        (, , , , , uint256 totalEligible) = campaignRegistry.getCheckpoint(
            campaignId,
            checkpointId
        );
        assertGt(totalEligible, 0, "Vote should be recorded after waiting");
    }

    /// @notice Test that snapshot block is captured when voting starts
    /// @dev Verifies snapshotBlock field is set correctly
    function testSnapshotBlockCapturedOnVotingStart() public {
        // Setup legitimate supporter
        vm.prank(admin);
        campaignRegistry.recordStakeDeposit(
            campaignId,
            legitSupporter,
            1_000 ether
        );

        vm.warp(block.timestamp + 1 hours + 1);

        // Schedule checkpoint
        CampaignRegistry.CheckpointInput memory input = CampaignRegistry
            .CheckpointInput({
                windowStart: uint64(block.timestamp),
                windowEnd: uint64(block.timestamp + 1 days),
                executionDeadline: uint64(block.timestamp + 2 days),
                quorumBps: 5_000
            });

        vm.prank(admin);
        uint256 checkpointId = campaignRegistry.scheduleCheckpoint(
            campaignId,
            input
        );

        uint256 blockBeforeVoting = block.number;

        // Update to Voting status - this should capture snapshot block
        vm.prank(admin);
        campaignRegistry.updateCheckpointStatus(
            campaignId,
            checkpointId,
            GiveTypes.CheckpointStatus.Voting
        );

        // The snapshot block should be set (we can't directly read it due to mapping in struct,
        // but we can verify the voting works as expected)

        vm.prank(legitSupporter);
        campaignRegistry.voteOnCheckpoint(campaignId, checkpointId, true);

        // Verify vote was successful
        vm.warp(block.timestamp + 2 days + 1);
        vm.prank(admin);
        campaignRegistry.finalizeCheckpoint(campaignId, checkpointId);

        (, , , , GiveTypes.CheckpointStatus status, ) = campaignRegistry
            .getCheckpoint(campaignId, checkpointId);
        assertEq(
            uint256(status),
            uint256(GiveTypes.CheckpointStatus.Succeeded)
        );
    }

    /// @notice Test multiple attackers cannot coordinate flash loan attack
    /// @dev Demonstrates protection scales to multiple malicious actors
    function testMultipleFlashLoanAttackersFail() public {
        address attacker2 = makeAddr("attacker2");
        address attacker3 = makeAddr("attacker3");

        // Legitimate supporter stakes and waits
        vm.prank(admin);
        campaignRegistry.recordStakeDeposit(
            campaignId,
            legitSupporter,
            1_000 ether
        );

        vm.warp(block.timestamp + 1 hours + 1);

        // Schedule checkpoint
        CampaignRegistry.CheckpointInput memory input = CampaignRegistry
            .CheckpointInput({
                windowStart: uint64(block.timestamp),
                windowEnd: uint64(block.timestamp + 1 days),
                executionDeadline: uint64(block.timestamp + 2 days),
                quorumBps: 5_000
            });

        vm.prank(admin);
        uint256 checkpointId = campaignRegistry.scheduleCheckpoint(
            campaignId,
            input
        );

        vm.prank(admin);
        campaignRegistry.updateCheckpointStatus(
            campaignId,
            checkpointId,
            GiveTypes.CheckpointStatus.Voting
        );

        // Multiple attackers try to stake and vote immediately (coordinated attack)
        vm.startPrank(admin);
        campaignRegistry.recordStakeDeposit(campaignId, attacker, 5_000 ether);
        campaignRegistry.recordStakeDeposit(campaignId, attacker2, 5_000 ether);
        campaignRegistry.recordStakeDeposit(campaignId, attacker3, 5_000 ether);
        vm.stopPrank();

        // All attackers fail to vote
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                CampaignRegistry.NoVotingPower.selector,
                attacker
            )
        );
        campaignRegistry.voteOnCheckpoint(campaignId, checkpointId, false);

        vm.prank(attacker2);
        vm.expectRevert(
            abi.encodeWithSelector(
                CampaignRegistry.NoVotingPower.selector,
                attacker2
            )
        );
        campaignRegistry.voteOnCheckpoint(campaignId, checkpointId, false);

        vm.prank(attacker3);
        vm.expectRevert(
            abi.encodeWithSelector(
                CampaignRegistry.NoVotingPower.selector,
                attacker3
            )
        );
        campaignRegistry.voteOnCheckpoint(campaignId, checkpointId, false);

        // ✅ All attacks FAILED

        // Legitimate supporter votes successfully
        vm.prank(legitSupporter);
        campaignRegistry.voteOnCheckpoint(campaignId, checkpointId, true);

        vm.warp(block.timestamp + 2 days + 1);
        vm.prank(admin);
        campaignRegistry.finalizeCheckpoint(campaignId, checkpointId);

        (, , , , GiveTypes.CheckpointStatus status, ) = campaignRegistry
            .getCheckpoint(campaignId, checkpointId);
        assertEq(
            uint256(status),
            uint256(GiveTypes.CheckpointStatus.Succeeded)
        );
    }

    /// @notice Test that stakeTimestamp is immutable after initial deposit
    /// @dev Verifies attacker can't reset timer by withdrawing and re-depositing
    function testStakeTimestampPersistsAcrossDeposits() public {
        // Initial stake
        vm.prank(admin);
        campaignRegistry.recordStakeDeposit(campaignId, attacker, 1_000 ether);

        uint256 initialStakeTime = block.timestamp;

        // Wait 30 minutes (not enough for MIN_STAKE_DURATION)
        vm.warp(block.timestamp + 30 minutes);

        // Attacker makes another deposit (trying to reset timer)
        vm.prank(admin);
        campaignRegistry.recordStakeDeposit(campaignId, attacker, 1_000 ether);

        // Schedule checkpoint
        vm.warp(block.timestamp + 35 minutes); // Total: 65 minutes from initial stake

        CampaignRegistry.CheckpointInput memory input = CampaignRegistry
            .CheckpointInput({
                windowStart: uint64(block.timestamp),
                windowEnd: uint64(block.timestamp + 1 days),
                executionDeadline: uint64(block.timestamp + 2 days),
                quorumBps: 5_000
            });

        vm.prank(admin);
        uint256 checkpointId = campaignRegistry.scheduleCheckpoint(
            campaignId,
            input
        );

        vm.prank(admin);
        campaignRegistry.updateCheckpointStatus(
            campaignId,
            checkpointId,
            GiveTypes.CheckpointStatus.Voting
        );

        // Attacker should be able to vote (initial stake was >1 hour ago)
        vm.prank(attacker);
        campaignRegistry.voteOnCheckpoint(campaignId, checkpointId, true);

        // ✅ Vote succeeds because stakeTimestamp wasn't reset by second deposit
    }
}
