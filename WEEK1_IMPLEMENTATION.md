# Week 1 Critical Fixes - Implementation Plan

**Status:** � STAGE 3 COMPLETE - Moving to Stage 4  
**Date Started:** October 23, 2025  
**Last Updated:** October 23, 2025

---

## Stage 1: Add Storage Gaps to Core Structs (Day 1 Morning) ✅

### Stage 1A: SystemConfig & VaultConfig ✅
- [x] Add `__gap` to `SystemConfig`
- [x] Add `__gap` to `VaultConfig`
- [x] Run tests: `forge test`
- [x] Verify no breaks

### Stage 1B: AssetConfig, AdapterConfig, RiskConfig ✅
- [x] Add `__gap` to `AssetConfig`
- [x] Add `__gap` to `AdapterConfig`
- [x] Add `__gap` to `RiskConfig`
- [x] Run tests: `forge test`
- [x] Verify no breaks

### Stage 1C: Position, Role, Synthetic Structs ✅
- [x] Add `__gap` to `PositionState`
- [x] Add `__gap` to `RoleAssignments` (has mapping, documented)
- [x] Add `__gap` to `SyntheticAsset` (has mapping, documented)
- [x] Run tests: `forge test`
- [x] Verify no breaks

---

## Stage 2: Add Storage Gaps to Registry Structs (Day 1 Afternoon) ✅

### Stage 2A: Strategy & Campaign Structs ✅
- [x] Add `__gap` to `StrategyConfig`
- [x] Add `__gap` to `CampaignConfig`
- [x] Add `__gap` to `SupporterStake`
- [x] Add `__gap` to `UserPreference`
- [x] Add `__gap` to `CampaignPreference`
- [x] Add `__gap` to `NGOInfo`
- [x] Run tests: `forge test`
- [x] Verify no breaks

### Stage 2B: Checkpoint & State Structs ✅
- [x] Add `__gap` to `CampaignCheckpoint` (has nested mappings, documented)
- [x] Add `__gap` to `CampaignStakeState` (has nested mappings, documented)
- [x] Add `__gap` to `CampaignCheckpointState` (has nested mappings, documented)
- [x] Add `__gap` to `CampaignVaultMeta`
- [x] Document complex state structs (NGORegistryState, PayoutRouterState, DonationRouterState)
- [x] Run tests: `forge test`
- [x] Verify no breaks

### Stage 2C: Router State Structs ✅
- [x] Fixed PayoutRouter.sol struct initialization (changed from literal to field assignment)
- [x] All tests passing

---

## Stage 3: Add Gaps to GiveStorage.Store (Day 2 Morning) ✅

### Stage 3A: Add Inter-Struct Gaps ✅
- [x] Add gap after `SystemConfig system` (50 slots)
- [x] Document mapping storage (mappings don't need gaps between them)
- [x] Add comprehensive comments explaining upgrade safety rules
- [x] Document slot layout (SystemConfig: 0-56, Gap: 57-106, Mappings: dynamic)
- [x] Run tests: `forge test`
- [x] Verify no breaks - ALL 48 TESTS PASSING

---

## Stage 4: Create Storage Layout Tests (Day 2 Afternoon) ✅

### Stage 4A: Basic Storage Test Framework ✅
- [x] Create `test/StorageLayout.t.sol`
- [x] Add test harness setup
- [x] Add struct size verification tests
- [x] Run tests: `forge test --match-test Storage` - 18 TESTS PASSING

### Stage 4B: Field Offset Verification ✅
- [x] Add gap verification for all 13 structs with gaps
- [x] Add upgrade simulation test
- [x] Add documentation verification for structs with mappings
- [x] Add upgrade safety rules documentation test
- [x] Add 50-slot convention verification test
- [x] Run tests: ALL 66 TESTS PASSING (48 original + 18 storage layout)

### Stage 4C: Upgrade Simulation ✅
- [x] Add mock V2 struct simulation (testUpgradeSimulation_AddFieldsToVaultConfig)
- [x] Test that gaps protect against corruption
- [x] Document upgrade procedures in test comments
- [x] Run full test suite: `forge test` - ALL PASSING

---

## ✅ CRITICAL ISSUE #1 - STORAGE GAPS: COMPLETE

**Summary:**
- ✅ 13 structs with storage gaps added (50 slots each)
- ✅ 8 structs with mappings documented (cannot have gaps)
- ✅ GiveStorage.Store gap added (50 slots after SystemConfig)
- ✅ PayoutRouter.sol struct initialization fixed
- ✅ 18 comprehensive storage layout tests created
- ✅ All 66 tests passing (100% success rate)

**Files Modified:**
1. `backend/src/types/GiveTypes.sol` - Added gaps & documentation
2. `backend/src/storage/GiveStorage.sol` - Added gap & comprehensive docs
3. `backend/src/payout/PayoutRouter.sol` - Fixed struct literal initialization
4. `backend/test/StorageLayout.t.sol` - NEW: 18 verification tests

**Upgrade Safety Protected:**
- SystemConfig: Slots 0-56 (with 50-slot gap)
- Gap after SystemConfig: Slots 57-106
- All mappings: Dynamic storage (keccak256-based, naturally isolated)
- Future upgrades: Can add up to 50 new fields per struct safely

---

## Stage 5: Flash Loan Voting Fix - Preparation (Day 3 Morning)

### Stage 5A: Add Snapshot Fields to Types
- [ ] Add `snapshotBlock` to `CampaignCheckpoint`
- [ ] Add `snapshotId` (if using ERC20Votes)
- [ ] Run tests: `forge test`
- [ ] Verify no breaks

### Stage 5B: Add Stake Tracking to Types
- [ ] Add `stakeTimestamp` mapping concept to docs
- [ ] Add `MIN_STAKE_DURATION` constant
- [ ] Document in GiveTypes
- [ ] Run tests: `forge test`

---

## Stage 6: Flash Loan Voting Fix - Implementation (Day 3-5)

### Stage 6A: Modify scheduleCheckpoint
- [ ] Capture snapshot block when scheduling
- [ ] Emit snapshot in events
- [ ] Run tests: `forge test --match-contract CampaignRegistry`

### Stage 6B: Add Stake Duration Tracking
- [ ] Add stakeTimestamp storage to CampaignRegistry
- [ ] Track deposit time in recordStakeDeposit
- [ ] Run tests: `forge test --match-contract CampaignRegistry`

### Stage 6C: Modify voteOnCheckpoint
- [ ] Add mustBeStakedFor modifier
- [ ] Use snapshot balance instead of current
- [ ] Run tests: `forge test --match-contract CampaignRegistry`

### Stage 6D: Create Attack Resistance Tests
- [ ] Create `test/VotingManipulation.t.sol`
- [ ] Test flash loan attack fails
- [ ] Test snapshot voting works correctly
- [ ] Test stake duration enforcement
- [ ] Run full test suite: `forge test`

---

## Testing Checkpoints

After each stage:
```bash
# Quick test
forge test

# Full test with gas report
forge test --gas-report

# Specific contract test
forge test --match-contract [ContractName]

# Coverage check
forge coverage
```

---

## Success Criteria

- [x] ✅ All tests pass after each stage (Stages 1-4 complete)
- [x] ✅ No gas increase >5% on existing tests (negligible impact observed)
- [x] ✅ Storage layout tests verify gap sizes (18 tests created and passing)
- [x] ✅ Upgrade simulation proves safety (testUpgradeSimulation_AddFieldsToVaultConfig passing)
- [ ] Flash loan attack tests prove resistance (Stage 6D)
- [ ] Stake duration properly enforced (Stage 6B-C)
- [ ] Code review by senior dev (pending)

---

## Rollback Plan

Each stage is in Git. If anything breaks:
```bash
git diff HEAD -- path/to/file
git checkout HEAD -- path/to/file  # Rollback specific file
git reset --hard HEAD~1            # Rollback last commit
```

---

**Next:** Start with Stage 1A
