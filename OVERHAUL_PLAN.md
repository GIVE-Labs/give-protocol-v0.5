# GIVE Protocol Architecture Revamp Plan

This plan replaces all previous overhaul documents. It is the single source of truth for migrating the current MVP to the modular, UUPS-upgradeable architecture described by the latest system flowchart. Every task below must be tracked with a checkbox; update the plan as work progresses.

---

## Target Architecture Summary
- **Governance:** Timelock → Multisig → ACL Manager. The ACL Manager issues/rotates functional roles and the Upgrader role that owns every UUPS proxy.
- **Core Composition:** A lean `GiveProtocolCore` proxy delegates to module libraries (`VaultModule`, `AdapterModule`, `DonationModule`, `SyntheticModule`, `RiskModule`, `EmergencyModule`) that all operate on a single shared storage struct through `StorageLib`.
- **Shared State:** `GiveTypes` defines canonical structs; `GiveStorage` (plus namespaced `StorageLib`) prevents slot clashes across modules, proxies, and adapters.
- **Peripheral Contracts:** Vault, Donation Router, NGO Registry, Synthetic Asset storage proxy, and each adapter (compounding, claimable yield, growth, PT rollover) run behind independent UUPS proxies controlled by the Upgrader role.
- **Bootstrap & Observability:** A deterministic bootstrap script deploys proxies/implementations, wires roles, sets configs, and prefunds approvals. Foundry test harness and indexers consume emitted lifecycle events.

---

## Execution Plan

### Phase 0 – Preparation & Documentation Alignment
- [x] Create a dedicated refactor branch `v-0.5` and snapshot current build/test status.
- [x] Update root and backend READMEs to state the migration objective and reference this plan; remove or edit any docs that contradict the new architecture.
- [x] Record existing deployment addresses/tests that must remain accessible during migration (for parity checks). _Forge test snapshot captured (36 passing tests) before revamp._

### Phase 1 – Shared Foundations
- [x] Implement `backend/src/types/GiveTypes.sol` with canonical structs (`VaultConfig`, `AssetConfig`, `PositionState`, `CallbackPayload`, role descriptors, risk configs, adapter descriptors).
- [x] Add `backend/src/storage/GiveStorage.sol` containing the single storage struct and dedicated storage slot getter.
- [x] Author `backend/src/storage/StorageLib.sol` with namespaced read/write helpers, version guards, and modifiers for module access.
- [x] Introduce `backend/src/storage/StorageKeys.sol` (or similar constants) to de-duplicate storage identifiers across modules and adapters.
- [x] Wire linting/tests to include the new directories. _Defaults already cover `src/`; no additional config required._

### Phase 2 – Governance Core
- [x] Build `ACLManager.sol` (UUPS optional) supporting dynamic role creation, enumeration, propose/accept admin transfers, recursion guard, and Upgrader role management.
- [x] Replace `AccessControl` usage in legacy contracts with temporary shims that delegate permission checks to the ACL Manager (until full module migration completes).
- [x] Add Foundry tests covering: role creation, grant/revoke, circular admin prevention, propose/accept flow, and Upgrader role restrictions.

### Phase 3 – Core Orchestrator Skeleton
- [x] Scaffold `GiveProtocolCore.sol` as a UUPS implementation with ACL-managed upgrade auth and shared storage initialization.
- [x] Add stub libraries for `VaultModule`, `AdapterModule`, `DonationModule`, `SyntheticModule`, `RiskModule`, and `EmergencyModule` operating on the shared storage struct.
- [x] Wire `GiveProtocolCore` entrypoints to the module libraries and emit placeholder events.
- [x] Add smoke tests ensuring only holders of module manager roles can invoke the new entrypoints.

### Phase 4 – Vault Stack Migration
- [x] Extract `VaultTokenBase.sol` with shared storage helpers and ACL hooks for vault implementations.
- [x] Refactor `GiveVault4626` to operate via the shared storage struct, replacing legacy state variables and wiring wrapped-native/adapter config.
- [x] Ensure manager interactions/setters work with storage-backed getters while leaving adapter APIs intact.
- [x] Update and run vault-related Foundry tests to confirm behaviour parity under the new storage layout.

### Phase 5 – Donation & NGO Modules
- [x] Port `DonationRouter` to the shared storage model and convert it to a UUPS implementation (initializer, upgrade guard, events aligned with new types).
- [x] Port `NGORegistry` to shared storage with versioned metadata and approval flows.
- [x] Expand `DonationModule` to orchestrate router configuration via storage-backed helpers.
- [x] Update Foundry tests to operate against the new DonationRouter/NGORegistry architecture.

### Phase 6 – Synthetic Asset Support
- [x] Deploy a storage-only `SyntheticProxy` contract that anchors synthetic storage without execution logic.
- [x] Implement `SyntheticLogic` to manage shared storage, mint/burn, and balance accounting for synthetic assets.
- [x] Integrate synthetic flows into `GiveProtocolCore` (configure/mint/burn + view helpers) and add tests validating role gating and storage updates.

### Phase 7 – Yield Adapters Suite
- [x] Define a shared adapter base and storage-backed module configuration (asset/vault metadata).
- [x] Implement adapter variants for compounding, claimable yield, balance-growth, and PT rollover behaviour.
- [x] Extend GiveProtocolCore with adapter config getters and delegations.
- [x] Add Foundry tests exercising the new adapters and ACL role gating.
### Phase 8 – Risk & Emergency Controls
- [x] Flesh out `RiskModule` for structured risk configs (LTV, thresholds, penalties, caps) with timestamped versions and invariant checks before operations.
- [x] Implement `EmergencyModule` coordinating pauses, emergency withdrawals, and liquidation actions across vault and adapters.
- [x] Emit events for risk updates, invariant violations, and emergency actions suitable for indexers.
- [x] Extend tests to cover risk config changes, invariant enforcement, and emergency scenarios.

### Phase 9 – Bootstrap Automation
- [x] Replace existing deployment scripts with a deterministic `Bootstrap.s.sol` that:
  - Deploys all implementations and proxies.
  - Initializes storage, assigns roles via ACL Manager, sets configs, prefunds approvals.
  - Logs addresses and role assignments for documentation.
- [x] Provide environment-specific configuration (local, testnet, mainnet) for the bootstrap script.
- [x] Add tests or dry-run scripts verifying bootstrap determinism and idempotency.

### Phase 10 – Testing Harness & Coverage
- [x] Create a Foundry base harness deploying the entire stack once per test file, exposing helper functions for scenarios.
- [x] Port representative unit and integration tests to the new harness (governance, risk, donation router, strategy manager, bootstrap, mock adapters).
- [ ] Integrate gas reports and coverage checks into CI (update Makefile as needed).

### Phase 11 – Campaign Architecture Pivot (Governance & Registries)
- [ ] Introduce `RoleManager` (central ACL) replacing scattered AccessControl usage; migrate `GiveProtocolCore`, routers, vaults, and managers to pull permissions from it.
- [ ] Implement `StrategyRegistry` with strategy CRUD, metadata (risk tier, adapter address, max TVL), lifecycle states (`Active`, `FadingOut`, `Deprecated`), and events.
- [ ] Implement `CampaignRegistry` supporting campaign submission, approval/rejection, curator assignment, payout destinations, and stake escrow.
- [ ] Wire `CampaignRegistry` to escrow/supporter stake logic and emit events for checkpoints (`CampaignSubmitted`, `CheckpointReached`, `StakeWithdrawn`).
- [ ] Add Foundry tests covering registry permissions, stake escrow, and checkpoint vote recording.

### Phase 12 – Vault Factory & Campaign Vaults
- [ ] Build `CampaignVaultFactory` that deploys minimal proxy `CampaignVault4626` instances per `(campaignId, strategyId, lockProfile)`.
- [ ] Extend `CampaignVault4626` with immutable campaign metadata, lock-profile enforcement, and RoleManager powered access checks.
- [ ] Integrate factory output with registries (auto-register vault + attach strategy) and emit `VaultCreated`.
- [ ] Update bootstrap script & harness to deploy example campaign + strategy + vault.
- [ ] Add tests proving factory deployments, lock-in enforcement, and strategy attachment workflows.

### Phase 13 – Payout Router & Yield Allocation
- [ ] Refactor DonationRouter into campaign-aware `PayoutRouter` consuming campaign IDs, storing per-vault supporter preferences, and tracking protocol fees by campaign.
- [ ] Implement user yield allocation control: per vault preference (50%, 75%, 100%), beneficiary address, default 100% to campaign.
- [ ] Modify harvest and distribution flows to respect allocations, emit new events (`YieldPreferenceUpdated`, `CampaignPayoutExecuted`).
- [ ] Add integration tests using time warp & mocked adapters to validate multi-campaign payouts, preference splits, and fee accrual.
- [ ] Document preference schema and update harness utilities to set allocations easily.

### Phase 14 – Checkpoint Voting & Stake Withdrawal
- [ ] Implement checkpoint mechanism inside `CampaignRegistry`: define milestones per campaign, allow supporters (stake depositors) to vote after each milestone window.
- [ ] Add majority vote tracking and conditional stake withdrawal (supporters can exit if majority votes to end campaign).
- [ ] Expose `submitCheckpoint`, `voteOnCheckpoint`, `finalizeCheckpoint`, and `requestStakeWithdrawal` functions with events (`CheckpointSubmitted`, `CheckpointApproved`, `StakeReleased`).
- [ ] Integrate voting outcomes with `CampaignVault` (pause vault or allow withdrawals) and router (halt payouts) when campaign fails a checkpoint.
- [ ] Cover scenarios in Foundry: successful checkpoints, failed majority, stake refunds, and vault pause/unpause.

### Phase 15 – Strategy Manager & Adapter Alignment
- [ ] Update `StrategyManager` to source adapter metadata from `StrategyRegistry`, enforce allowed strategies per campaign, and honor RoleManager roles.
- [ ] Harden adapters (Aave + mocks) with allowance hygiene, health checks, and event coverage as per earlier reviews.
- [ ] Add keepers or simulated keeper tests to exercise rebalance, auto-checks, and emergency exits in campaign context.
- [ ] Expand coverage for multi-adapter scenarios, verifying vault harvest impacts campaign payouts.

### Phase 16 – Documentation, Observability & Cleanup
- [ ] Update `/docs/` with the campaign-based architecture (Mermaid diagrams, role matrix, registry interactions, checkpoint flow).
- [ ] Document stake escrow, checkpoint voting, preference management, and vault factory runbooks.
- [ ] Specify event schemas for indexers (campaign submission, checkpoint events, vault creations, payouts).
- [ ] Remove obsolete NGO-specific contracts/docs/scripts, update migration notes for campaign-first design, and ensure changelog reflects the pivot.
- [ ] Run full suite + lint/format + coverage report; target ≥80% line coverage on new campaign modules.

---

**Guidance:**  
- Update the checkboxes in this document as milestones complete.  
- Any deviation from this plan must be documented here to maintain a single authoritative roadmap.  
- Keep commit history aligned with phases for review clarity.  
