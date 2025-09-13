# Session Context — GIVE Protocol (v0.1)

Date: 2025-09-13 (UTC)

## Summary

- Synchronized backend to the v0.1 MVP scope (single NGO, Aave adapter, atomic donation on harvest).
- Vault `harvest()` now transfers profit to `DonationRouter` and immediately calls `distribute(asset, amount)`.
- `NGORegistry.recordDonation` restricted by `DONATION_RECORDER_ROLE` (router holds it in tests).
- Replaced legacy tests with a minimal, v0.1‑aligned suite:
  - `VaultRouter.t.sol` — deposit → cash buffer → harvest → router donation → withdraw.
  - `Router.t.sol` — fee config, authorized caller, distribute and distributeToMultiple.
  - `AaveAdapterBasic.t.sol` — invest/divest/harvest happy path with mocks.
  - `StrategyManagerBasic.t.sol` — adapter approval/activation and vault parameter updates.
- Removed outdated tests referencing multi‑mode router, allocation/rebalance APIs, and Morph prototype.
- `forge build` is green. Test execution should be run locally (sandbox restriction here).
- CHANGELOG updated under [0.1.0] “Changed (2025‑09‑13)”.

## Open TODOs / Next Steps

- Backend
  - Align `backend/script/Deploy.s.sol` to current constructors and wiring:
    - `GiveVault4626(IERC20 asset, string name, string symbol, address admin)`
    - `StrategyManager(address vault, address admin)`
    - `AaveAdapter(address asset, address vault, address aavePool, address admin)`
    - `DonationRouter(address admin, address ngoRegistry, address feeRecipient, uint256 feeBps)`
  - After deploy: `router.setAuthorizedCaller(vault, true)` and grant `DONATION_RECORDER_ROLE` to router in registry.
  - Add unit tests for pause and emergency paths (invest/harvest pause, `emergencyWithdrawFromAdapter`).
  - Optional: add invariant/fuzz tests (deposits/withdrawals monotonicity, reentrancy attempts).

- CI
  - Add GitHub Actions to run `forge build` and `forge test` on PRs.

- Frontend
  - Update README/docs to reflect Vite + React + wagmi (remove Next.js and thirdweb references unless you intend to use them).
  - Update `frontend/src/config/contracts.ts` with current contract addresses once deployed.
  - Ensure UX matches v0.1 (single NGO selection; deposit/withdraw; view donations/harvests).

- Docs
  - Keep CHANGELOG current for every change.
  - Maintain this `llm/SESSION_CONTEXT.md` as the handoff document between sessions.

## Run Locally

```bash
cd backend
forge build
forge test -vv
```

## Quick Links

- Backend tests: `backend/test/*.t.sol`
- Contracts: `backend/src/**`
- Deployment (to be aligned): `backend/script/Deploy.s.sol`

