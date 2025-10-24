# GIVE Protocol – No Loss Giving, Modular v0.5

The GIVE Protocol redirects on-chain yield to social impact campaigns without touching a donor's principal. Depositors receive ERC-4626 vault shares, their assets flow through yield adapters, and harvested profits are streamed to vetted NGOs. The v0.5 overhaul keeps this no-loss promise while reorganising the stack around UUPS proxies, shared storage, and ACL-managed governance.

**📋 Important Documents:**
- `OVERHAUL_PLAN.md` - Phase-by-phase development checklist (authoritative roadmap) - **Phases 0-16 COMPLETE ✅**
- `audits/CODE_REVIEW_COMPLETE.md` - **Comprehensive security audit results**
- `audits/SECURITY_REMEDIATION_ROADMAP.md` - Security fix timeline and implementation
- `FRONTEND_INTEGRATION.md` - **Frontend developer guide** (Wagmi v2 + Viem + RainbowKit)
- `docs/ARCHITECTURE.md` - **System architecture with diagrams**
- `docs/EMERGENCY_PROCEDURES.md` - **Incident response runbook**
- `docs/EVENT_SCHEMAS.md` - **Event definitions for indexers**

---

## ✅ v0.5 Status

**Development Status:** ✅ **Phase 0-16 COMPLETE** (All core features + documentation)  
**Security Status:** ✅ **Security Audit PASSED** (all critical/high issues fixed)  
**Testnet Readiness:** 🟡 **READY FOR DEPLOYMENT** (monitoring + operations setup pending)  
**Test Coverage:** ✅ **116/116 tests passing (100%)**

### Completed Milestones:
- ✅ **Core Architecture** - UUPS proxies, shared storage, module libraries (Phases 0-3)
- ✅ **Vault System** - ERC4626 vaults with auto-investment + emergency controls (Phase 4)
- ✅ **Campaign System** - Registry, factory, checkpoint voting (Phases 11-14)
- ✅ **Payout System** - Campaign-aware yield distribution (Phase 13)
- ✅ **Strategy Manager** - Adapter validation and configuration (Phase 15)
- ✅ **Security Audit** - All critical/high issues fixed, attack simulations passing
- ✅ **Documentation** - Architecture diagrams, emergency procedures, event schemas (Phase 16)

### Security Achievements:
- ✅ **Storage Gap Protection** - All 13 structs with 50-slot gaps
- ✅ **Flash Loan Voting Protection** - Snapshot-based with 7-day minimum stake
- ✅ **Emergency Withdrawal System** - 24hr grace + auto-divestment
- ✅ **Fee Timelock** - 7-day delay with 2.5% max increase per change
- ✅ **Attack Resistance** - Flash loans, front-running, griefing, reentrancy tests passing

See `audits/` folder for complete security documentation and `docs/` for system architecture.

---

## Architecture at a Glance
- **Governance:** Timelock → Multisig → `ACLManager`. The ACL issues functional roles (vault manager, adapter manager, risk manager, etc.) plus a single Upgrader role controlling every UUPS proxy.
- **Core Orchestrator:** `GiveProtocolCore` is a minimal proxy that delegates lifecycle actions to module libraries (`VaultModule`, `AdapterModule`, `DonationModule`, `SyntheticModule`, `RiskModule`, `EmergencyModule`). Modules operate on one shared storage struct.
- **Shared State:** `GiveTypes`, `GiveStorage`, and `StorageLib` define canonical structs and enforce a dedicated storage slot so all contracts read from the same state.
- **Yield Surface:** `GiveVault4626` manages cash buffers, harvest cadence, and payout hooks. Specialised adapters (compounding, claimable, growth index, PT rollover) conform to `IYieldAdapter` and are registered through `AdapterModule`.
- **Payout Pipeline:** `PayoutRouter` tracks campaign vault share balances, supporter preferences (beneficiaries + campaign splits), and routes harvested yield between campaign recipients, supporter beneficiaries, and protocol fees. `CampaignRegistry`/`StrategyRegistry` provide metadata + role gating.
- **Synthetic Layer:** `SyntheticLogic` maintains balances for synthetic representations (e.g., donated yield claims) via storage-only proxies.
- **Checkpoint Voting:** Phase 14+ includes campaign checkpoint voting with stake-based governance for milestone validation.

---

## Repository Layout
```
backend/                          Foundry workspace for Solidity contracts and tests
  src/                            Modular architecture (types, storage, modules, adapters, vault, governance)
  test/                           Foundry test suites (ACL, adapters, vault flows, donation router, synthetic assets)
frontend/                         Legacy UI (kept for reference during migration)
OVERHAUL_PLAN.md                  Phase-by-phase development checklist
SECURITY_REMEDIATION_ROADMAP.md   Security audit fixes and implementation guide
```

Legacy contracts that still live in `backend/src` will be removed once their replacements graduate through the plan.

**Note:** The `docs/` directory has been cleaned up. Phase-specific documentation has been integrated into code comments and the main planning documents.

---

## Development Workflow
1. **Align with the Plan**
   - Confirm the next unchecked item in `OVERHAUL_PLAN.md`.
   - Document deviations directly in the plan before implementing them.
2. **Build & Test**
   ```bash
   cd backend
   forge build
   forge test
   ```
   Tests are being ported phase-by-phase; expect incomplete coverage until later phases.
3. **Validate Roles & Access**
   - Route all state through `StorageLib`.
   - Gate mutations with ACL-managed roles; avoid bespoke ownership checks.
4. **Document as You Go**
   - Prefer concise in-code comments for non-obvious logic.
   - Update this README and the plan whenever architecture-level assumptions shift.

---

## Contribution Principles
- **Preserve Principal:** Never draft changes that move depositor principal. Yield distributions must originate from adapter profit.
- **Proxy Safety:** Every upgradeable contract must implement `_authorizeUpgrade` tied to the ACL Upgrader role.
- **Deterministic Deployments:** Scripts and tests should keep deployment order and addresses reproducible.
- **Modularity First:** New features belong in modules, adapters, or libraries rather than monolithic contracts.

---

## Legacy Surface (Reference Only)
The original MVP commands exist purely for comparison and are not maintained:
```bash
# Contracts (legacy surface)
cd backend
forge build
forge test

# Frontend prototype
cd frontend
pnpm install
pnpm dev
```

Use these only when auditing regressions against historical behaviour.

---

## Getting Started Checklist
1. Read `OVERHAUL_PLAN.md` through Phase 12.
2. Explore `backend/src/types` and `backend/src/storage` to understand the shared memory model.
3. Deploy `GiveProtocolCore` and `ACLManager` in a local Foundry test to experiment with role gating.
4. Coordinate with the team before modifying governance, storage slots, or payout math.

The goal of this rebuild is a transparent, upgrade-safe protocol that donors, NGOs, and auditors can trust. Keep the codebase and documentation razor sharp.
