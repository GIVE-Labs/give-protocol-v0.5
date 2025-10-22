# Backend Notes (Revamp In Progress)

The Solidity contracts in this folder are part of the legacy MVP. They remain only as references while we implement the architecture defined in `OVERHAUL_PLAN.md`.

During the migration:

- New contracts must live under `src/` using the shared storage/types libraries introduced in Phase 1.
- Legacy files should be deleted once their replacements are merged.
- Foundry scripts will be consolidated into a single deterministic bootstrap (`Bootstrap.s.sol`) per Phase 9.

Use `forge build` / `forge test` only to inspect existing behaviour; expect these commands to fail while the overhaul is underway.*** End Patch
