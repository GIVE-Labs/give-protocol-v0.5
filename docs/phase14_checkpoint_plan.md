# Phase 14 – Checkpoint Voting & Stake Withdrawal

## Goals
- Allow campaigns to define checkpoint schedule & quorum requirements.
- Enable supporters to vote on checkpoints using staked amounts or share snapshots.
- Provide an exit path for supporters if checkpoints fail.
- Halt payouts and unlock withdrawals when campaign fails checkpoints.

## Decisions
- Voting weight: vault shares + optional ve-style escrow boost (capped at 50%).
- Stake storage: `SupporterStake` struct per supporter with OZ-style checkpoints for snapshots.
- Campaign failure: set `campaign.payoutsHalted = true`; vault unlocks per lock profile, router halts payouts.

## Proposed Components
1. `CampaignRegistry` additions:
   - `CheckpointConfig` struct with quorumBps, window start/end, etc.
   - mapping of checkpoint index => Checkpoint data (status, votes for/against).
   - stake snapshot per supporter per checkpoint.
2. API
   - `scheduleCheckpoint`, `submitCheckpoint`, `voteOnCheckpoint`, `finalizeCheckpoint`, `requestStakeExit`.
3. Router integration
   - When campaign status becomes `Failed` or `Paused`, router should skip payouts.
4. Vault integration
   - `CampaignVault` should allow withdrawals without penalty if checkpoint fails.

## Testing Plan
- Unit tests for checkpoint scheduling, voting, quorum passes/fails.
- Integration tests ensuring router skips payouts on failed checkpoint.
- Exit tests: supporter withdraws stake/ receives refunds.

## Next Steps
- Confirm stake source (escrow contract vs vault shares).
- Define event schema for checkpoints.
- Align Phase 15 strategy manager with new statuses.

## Implemented
- `SupporterStake` shares with checkpoint snapshots.
- `scheduleCheckpoint`, `voteOnCheckpoint`, `finishCheckpoint` (admin finalize) with quorum and payout halting.
- `PayoutRouter` rejects distributions when campaign has `payoutsHalted`.
- Tests cover success/failure voting flows and halted payouts.
