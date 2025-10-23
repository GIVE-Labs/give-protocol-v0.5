# Architecture Checklist — GIVE Protocol

This file maps the guidance bullets to the repository files and a short status (Done / Needs work / Planned).

Notes: "Done" means the contract or pattern is implemented and covered by tests; "Needs work" indicates integration, wiring, or hardening is still required; "Planned" means only documented.

## Core Vault System
- GiveVault4626 (ERC-4626)
  - Path: `backend/src/vault/GiveVault4626.sol`
  - Status: Needs work — implemented, but docs and V2 status mark "Needs integration" to fully wire some flows into the protocol core (harvest wiring is present but end-to-end integration tests recommended).

- StrategyManager
  - Path: `backend/src/manager/StrategyManager.sol`
  - Status: Done — implemented and used by tests; sets active adapters and vault parameters.

## Yield Generation
- IYieldAdapter (interface)
  - Path: `backend/src/interfaces/IYieldAdapter.sol`
  - Status: Done

- AaveAdapter
  - Path: `backend/src/adapters/AaveAdapter.sol`
  - Status: Done (production hardening recommended — see OVERHAUL_PLAN for allowance/emergency improvements)

- MockYieldAdapter
  - Path: `backend/src/adapters/MockYieldAdapter.sol`
  - Status: Done (testing adapter)

## Donation / Payout System
  - Path: `backend/src/payout/PayoutRouter.sol`
  - Status: Done — implemented, used by many tests (distribution, epochs, claims).
  - Compatibility shim: `backend/src/donation/DonationRouter.sol` (inherits `PayoutRouter`).

  - Path: `backend/src/donation/NGORegistry.sol`
  - Status: Done — implemented with attestation metadata and tests.
  - Note: `NGORegistry.sol` is a thin wrapper over `CampaignRegistry.sol` for tutorial/tooling compatibility.

## Access Control & Governance
- RoleManager / RoleAware
  - Path: `backend/src/access/RoleManager.sol`, `backend/src/access/RoleAware.sol`
  - Status: Done — centralized ACL used across contracts and in tests.

- TimelockController (governance timelock)
  - Path: Documented in `GUIDANCE/` and referenced in docs
  - Status: Planned — referenced in architecture docs; not deployed as a project-owned wrapper in scripts (recommended to wire in prod bootstrap if timelocked upgrades are required).

## Upgradeability
- UUPS proxy pattern
  - Path: Deploy/upgrade scripts: `backend/script/DeployGiveProtocolV2.s.sol`, `backend/script/UpgradeGiveProtocolV2.s.sol` and UUPS-ready implementation contracts
  - Status: Done (codebase and scripts use UUPS / ERC1967 pattern). See notes: docs mention ProxyAdmin in places (this is an alternate upgrade flow).

## Deployment, Bootstrap & Tests
- Deployment & upgrade scripts
  - Path: `backend/script/*.s.sol` (see `DeployGiveProtocolV2.s.sol`, `UpgradeGiveProtocolV2.s.sol`)
  - Status: Done

- Bootstrap & wiring scripts
  - Path: `script/HelperConfig.s.sol`, `script/DeployLocal.s.sol`, other `script/*.s.sol`
  - Status: Done (example bootstrapping present; review for production timelock wiring)

- Tests
  - Path: `backend/test/*.t.sol`
  - Status: Done — many unit and integration tests exist and were reported passing in the V2 run.

## Diagrams & Docs
- ARCHITECTURE diagrams
  - Path: `docs/ARCHITECTURE_DIAGRAM.md`, `docs/MASTER_ARCHITECTURE_DIAGRAM.md`, `GUIDANCE/02-ARCHITECTURE.md`
  - Status: Done — diagrams updated; note: some mermaid tokens were fixed recently (e.g., array bracket tokens).

## Summary — immediate recommended actions
1. Add/verify one small integration test that asserts the full deposit → invest → harvest → distribute path (GiveVault4626 ↔ adapters ↔ PayoutRouter).
2. Wire a TimelockController in the bootstrap scripts or provide a cooked example for onchain timelocking of UPGRADER_ROLE.
3. Run a targeted audit/hardening pass for adapters (allowance hygiene, emergency thresholds, transfer edge-cases).

If you want, I can add the simple end-to-end integration test and wire a timelock example in scripts next.
