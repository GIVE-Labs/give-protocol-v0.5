# GIVE Protocol – Architecture Revamp

This repository is mid-flight on a complete rebuild to adopt the modular architecture captured in `OVERHAUL_PLAN.md`. The legacy MVP (single ERC-4626 vault, NGO registry, strategy manager) is being dismantled in favour of a composable system that looks like:

- **Governance:** Timelock → Multisig → ACL Manager issuing functional roles plus a single Upgrader role controlling every UUPS proxy.
- **Core Orchestrator:** `GiveProtocolCore` proxy that delegates to stateless module libraries (`VaultModule`, `AdapterModule`, `DonationModule`, `SyntheticModule`, `RiskModule`, `EmergencyModule`) all reading/writing through shared storage.
- **Shared State:** `GiveTypes`, `GiveStorage`, and `StorageLib` to consolidate protocol data and prevent slot clashes.
- **Proxied Components:** UUPS implementations for the vault, donation router, registry, synthetic storage proxy, and each adapter flavour (compounding, claimable-yield, growth, PT rollover with a yield manager).
- **Bootstrap & Tests:** Deterministic Foundry bootstrap wiring proxies, roles, configs, and approvals; a new full-stack Foundry harness for governance, onboarding, synthetic asset, and emergency scenarios.

All tasks, dependencies, and checkboxes live in `OVERHAUL_PLAN.md`. Treat that file as the source of truth when deciding what to build next.

---

## Repo Status

- ✅ `OVERHAUL_PLAN.md` is current and must be updated before code diverges.
- ❗ Contracts, frontend, and scripts still reflect the legacy MVP until their respective phases land.
- 🧹 Vague or conflicting documentation has been removed to keep the focus on the new design.

Expect breaking changes until Phase 12 of the plan completes.

---

## Working Guidelines

- **Follow the plan:** every PR should map to a checklist item. Update the checkbox when done.
- **Respect shared storage:** new contracts interact with protocol state only through `StorageLib`.
- **Guard upgrades:** only the ACL-managed Upgrader role may call `upgradeTo` on any UUPS proxy.
- **Document in code:** keep Markdown light; add concise comments where logic would otherwise be opaque.

---

## Legacy Commands (reference only)

```bash
# Contracts (legacy)
cd backend
forge build
forge test

# Frontend (legacy)
cd frontend
pnpm install
pnpm dev
```

Run these only if you need to inspect legacy behaviour prior to migration.

---

## Next Steps

1. Start with Phase 1 in `OVERHAUL_PLAN.md` (shared types + storage).
2. Record plan updates before touching code if requirements change.
3. Keep commits scoped per phase so reviewers and auditors can trace the migration path.

Let’s keep the documentation as sharp as the architecture we’re building.*** End Patch
