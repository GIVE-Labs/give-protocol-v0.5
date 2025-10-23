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
- [x] Storage & Types: extend `GiveTypes`/`GiveStorage` with canonical structs for strategies, campaigns, supporter stakes, and checkpoint windows; add `StorageLib` accessors and guards.
- [x] Role Management: evolve the existing `ACLManager` into the canonical `RoleManager` (same proxy), add campaign/strategy/checkpoint role ids + helper getters, and migrate `ACLShim` consumers (vaults, router, registry, adapters) to use the expanded interface without altering upgrade auth.
- [x] StrategyRegistry: build UUPS registry with CRUD, metadata (risk tier, adapter binding, max TVL), lifecycle states (`Active`, `FadingOut`, `Deprecated`), and event coverage.
- [x] CampaignRegistry: implement UUPS registry handling submission/approval workflows, curator assignment, payout destinations, stake escrow bookkeeping, and lifecycle events.
- [x] Bootstrap wiring: update `Bootstrap.s.sol` to deploy the role manager and new registries, assign roles, and persist deterministic identifiers.
- [x] Tests: add Foundry suites for `RoleManager`, `StrategyRegistry`, and `CampaignRegistry` covering permissioning, state transitions, stake deposits/withdrawals, and failure cases.

### Phase 12 – Vault Factory & Campaign Vaults
- [x] Vault artifacts: implement `CampaignVaultFactory` (UUPS) for deterministic clone deployments with role gating and event emission.
- [x] CampaignVault: derive from `GiveVault4626`/`VaultTokenBase` with immutable campaign metadata, lock-profile enforcement, and hooks for strategy/risk assignment.
- [x] Storage/Registry integration: persist factory-created vault metadata in `StorageLib`; auto-register vaults with `CampaignRegistry`/`StrategyRegistry` to link campaign ↔ strategy ↔ vault.
- [x] Core wiring: extend `GiveProtocolCore`/`VaultModule` to configure campaign vaults, assign donation modules, and sync risk limits on creation.
- [x] Bootstrap + harness: update bootstrap script and Foundry harness utilities to spin up exemplar campaign + vault flows with helper getters.
- [x] Tests: add Foundry coverage for factory deployments, metadata correctness, lock enforcement, and duplicate-registration protection.

### Phase 13 – Payout Router & Yield Allocation
- [x] Router refactor: evolve `DonationRouter` into `PayoutRouter` with campaign-aware preferences (per vault/campaign splits, beneficiary overrides, protocol fee buckets).
- [x] Storage updates: reshape `GiveTypes`/`StorageLib` to expose campaign vault metadata, per-vault share tracking, and campaign payout accounting.
- [x] Vault hooks: update `GiveVault4626` and `CampaignVault4626` to report shares to the payout router and register campaign vaults automatically.
- [x] Campaign integration: wire `StrategyRegistry`/`CampaignRegistry` bootstrapping, factory deployments, and metadata events (`YieldPreferenceUpdated`, `CampaignPayoutExecuted`).
- [x] Tests: add campaign-centric unit/integration suites for payout routing, preferences, factory deployments, and vault yield distribution.
- [x] Docs & SDK touchpoints: refresh README/plan to describe the campaign-first payout model and future work.

### Phase 14 – Checkpoint Voting & Stake Withdrawal
- [x] Checkpoint design: extend `CampaignRegistry` with milestone schedules, quorum settings, supporter snapshots, and checkpoint state structs.
- [x] Voting mechanics: implement `scheduleCheckpoint`, `voteOnCheckpoint`, and `finalizeCheckpoint` with ACL gating, events, and quorum checks.
- [x] Stake escrow: track supporter share stakes, emit vote-weight snapshots, and flag campaigns for supporter exits when checkpoints fail.
- [x] Router integration: `PayoutRouter` reverts distributions when campaigns are halted after failed checkpoints (vault unlocking documented).
- [x] Tests: Foundry coverage for checkpoint success/failure, payout halting, and stake exits (vault unlock behaviour documented).

### Phase 15 – Strategy Manager & Adapter Alignment
- [ ] StrategyManager module: extend the core/module layer to manage strategy assignments, enforce adapter eligibility, and surface metadata to campaigns.
- [ ] Adapter hardening: align existing adapters with new strategy metadata (allowance hygiene, health checks, emergency exits) and event coverage.
- [ ] Keeper flows: add simulated keeper tests for rebalances, health monitoring, and emergency exits across multiple campaigns/strategies.
- [ ] Core/API updates: expose strategy queries/setters via `GiveProtocolCore` and ensure registries/factory respect new constraints.
- [ ] Tests: cross-module integration verifying deposits → adapter yield → campaign payouts under multiple strategies.

### Phase 16 – Documentation, Observability & Cleanup
- [ ] Architecture docs: refresh `/docs/` diagrams, mermaid flows, and role matrices for the campaign-centric layout, registries, and role manager.
- [ ] Runbooks: document stake escrow lifecycle, checkpoint voting, allocation management, vault factory operations, and emergency procedures.
- [ ] Event schemas: define canonical events for indexers (campaign lifecycle, checkpoints, payouts, strategy assignments) and update observability tooling.
- [ ] Cleanup: remove NGO-specific artifacts, scripts, and docs; update migration notes and changelog for the campaign-first design.
- [ ] Quality gates: execute full Foundry suite with gas + coverage reporting, enforce ≥80% coverage on new modules, and wire into CI.

---

**Guidance:**  
- Update the checkboxes in this document as milestones complete.  
- Any deviation from this plan must be documented here to maintain a single authoritative roadmap.  
- Keep commit history aligned with phases for review clarity.  
