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

## Architecture Overview

%% Architecture Diagram

flowchart TB
    subgraph Users
        U[Supporters/Donors]
    end

    subgraph Governance
        ACL[ACLManager Role-Based Access Control]
        MS[Multisig + Timelock]
    end

    subgraph Campaign System
        CR[CampaignRegistry Lifecycle Management]
        SR[StrategyRegistry Risk Tiers & Adapters]
        VF[VaultFactory Deploy Campaign Vaults]
    end

    subgraph Core Vault Layer
        V1[CampaignVault 4626]
        V2[CampaignVault 4626]
    end

    subgraph Yield Generation
        A1[AaveAdapter]
        A2[CompoundAdapter]
        A3[MockAdapter]
    end

    subgraph Distribution
        PR[PayoutRouter Yield Distribution]
        CAMP[Campaign Recipients]
    end

    MS --> ACL
    ACL -.->|Controls| CR
    ACL -.->|Controls| VF
    ACL -.->|Controls| PR

    CR -->|Metadata| VF
    SR -->|Strategy Config| VF
    VF -->|Deploys| V1
    VF -->|Deploys| V2

    U -->|Deposit| V1
    U -->|Deposit| V2

    V1 -->|Auto-Invest 99%| A1
    V2 -->|Auto-Invest 99%| A2

    A1 -->|Harvest Yield| PR
    A2 -->|Harvest Yield| PR

    PR -->|50% Campaign| CAMP
    PR -->|5     0% Supporter| U

    CR -.->|Checkpoint Voting| CAMP
    U -.->|Vote on Milestones| CR

    style ACL fill:#e74c3c,stroke:#333,stroke-width:2px,color:#fff
    style V1 fill:#4a90e2,stroke:#333,stroke-width:2px,color:#fff
    style V2 fill:#4a90e2,stroke:#333,stroke-width:2px,color:#fff
    style PR fill:#27ae60,stroke:#333,stroke-width:2px,color:#fff
    style CAMP fill:#f39c12,stroke:#333,stroke-width:2px,color:#fff


### Core Architecture Principles

- **Governance:** Multisig + Timelock → ACLManager issues role-based permissions for all protocol operations
- **Campaign-Centric:** Each campaign gets its own ERC-4626 vault deployed by the factory with strategy-specific risk parameters
- **Auto-Investment:** 99% of deposits automatically flow to yield adapters (Aave, Compound), 1% kept as cash buffer
- **Yield Distribution:** PayoutRouter splits harvested yield between campaigns (default 80%) and supporters (default 20%)
- **Checkpoint Voting:** Supporters vote on campaign milestones; failed checkpoints halt payouts until resolved
- **Upgradeability:** All core contracts use UUPS proxies controlled by ACL's `ROLE_UPGRADER`
- **Shared Storage:** Module libraries (VaultModule, AdapterModule, etc.) operate on a single storage struct via `StorageLib`

**Principal Protection:** User deposits remain withdrawable at all times (subject to optional lock periods). Only yield flows to campaigns.

**For full technical details**, see [`docs/ARCHITECTURE.md`](/docs/ARCHITECTURE.md) - includes governance flows, emergency procedures, and security model.

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
