# GIVE Protocol — SystemRequirements.md (v0.1 → v1)

**Owner:** Product/Protocol Lead
**Audience:** Solidity engineers, DevOps, QA, auditors, ops
**Status:** Draft v0.1 → v1 implementation plan

---

## 0) Purpose & Goals

GIVE Protocol enables no‑loss giving: users deposit an ERC‑20 asset into an ERC‑4626 vault; principal remains redeemable, while yield (profits) is routed to approved NGOs based on user-configurable allocation preferences (50%, 75%, 100%). The system must be safe‑by‑default, modular (adapters per yield source), and easy to audit.

### Goals

* Keep user principal safe and continuously redeemable (subject to available liquidity/adapter unwind).
* Standardize user UX via ERC‑4626 interface (deposits, share math, previews).
* Support multiple yield adapters (Aave/Euler, Pendle PT → optional LP/gauge).
* Route realized profits to a Donation Router for approved NGOs (via NGO Registry).
* **Enable user-configurable yield allocation (50%, 75%, 100% to NGO, remainder to protocol treasury)**.
* **Track user shares and preferences for proportional yield distribution**.
* Ship a production‑minded MVP (v0.1) and evolve to v1 with governance, risk controls, and monitoring.

### Non‑Goals (v0.1)

* Complex cross‑vault orchestration; multi‑NGO split per user; on‑chain Merkle claim receipts; cross‑chain messaging. These are v1+ items.

### Definitions

* Asset: The underlying ERC‑20 token accepted by the vault (e.g., USDC, wstETH).
* Shares: ERC‑20 vault shares representing claim on `totalAssets`.
* Profit: Adapter‑realized increase in `totalAssets` beyond principal baseline; withdrawable only via NGO path.
* Adapter: Contract that invests the vault’s asset into an external yield source (Aave/Euler, Pendle).
* Cash buffer: Portion of asset kept in vault to satisfy redemptions without forced divest.

---

## 1) High‑Level Architecture

```
Users <-> ERC-4626 Vault (GiveVault4626) <-> StrategyManager
                                     |-> Adapter (Aave/Euler)
                                     |-> Adapter (Pendle PT) [v0.3+]

harvest() -> DonationRouter -> User Preferences (50%/75%/100%) -> NGO + Protocol Treasury
                            -> NGO Registry (approval) -> NGO address
                            -> Protocol Treasury (1% fee + remainder)

User Preferences: setUserPreference(ngo, allocation%) -> stored per user
Distribution: calculateUserDistribution() -> proportional to user shares

Admin: Multisig (DEFAULT_ADMIN) + (VAULT_MANAGER, NGO_MANAGER, PAUSER)
Upgrade (optional v1): UUPS proxy with UPGRADER_ROLE + Timelock
```

**Key properties**

* Vault‑centric accounting: `totalAssets = cash + Σ adapter.totalAssets()`.
* Plug‑in adapters: StrategyManager selects active adapter(s); params via governance.
* Donation flow: `vault.harvest()` pulls profit from adapters and sends to `DonationRouter`, which pays the current NGO (one per vault in v0).
* Safety rails: Pausing, cash buffer, slippage bounds, `maxLossBps` on exits, emergency unwind.

---

## 2) Components & Responsibilities

### 2.1 GiveVault4626 (ERC‑4626)

* Inherits OZ ERC‑4626 + ERC‑20 shares.
* State: `activeAdapter`, `cashBufferBps`.
* Core:
  * `totalAssets()` returns cash + adapter assets.
  * Hooks: `afterDeposit` pushes excess cash to adapter; `beforeWithdraw` pulls when needed.
  * `harvest()` calls adapter(s).harvest() and forwards profit to DonationRouter (subject to split/fee).
* Events: `AdapterUpdated`, `CashBufferUpdated`, `Harvest(profit,loss)`.
* Security: `nonReentrant` on entrypoints, SafeERC20.

### 2.2 StrategyManager

* Parameter/admin surface for the vault under AccessControl/Ownable/timelock.
* Functions: `setActiveAdapter`, `setCashBufferBps`, and adapter param setters via adapter governance functions.

### 2.3 Adapters (IYieldAdapter)

* Interface: `asset()`, `totalAssets()`, `invest(assets)`, `divest(assets) -> returned`, `harvest() -> (profit,loss)`.
* Aave/Euler Adapter (v0.1): supply‑only; `totalAssets()` via aToken/balanceOfUnderlying.
* Pendle PT Adapter (v0.3): asset↔SY↔PT via Router; `totalAssets()` via RouterStatic/oracle; no gauge.
* Pendle LP+Gauge Adapter (v0.4 optional): LP entry/exit, stake in gauge, claim rewards, swap to asset.

### 2.4 DonationRouter

* Receives `profit` from vault harvests, pays current NGO.
* Anyone can call `claim(ngo)`; funds always go to NGO.
* Optional protocol fee (e.g., 1%) to Treasury.
* Emits `DonationPaid(ngo, amount, fee)`.

### 2.5 NGO Registry

* `addNGO(address ngo)`, `removeNGO(address)`, `isApproved(address)`.
* Vault references this for `currentNGO` validity.
* (v0.2+) `setCurrentNGO(address)` with delay (e.g., 48h) to rotate beneficiary.

### 2.6 Governance & Roles

* DEFAULT_ADMIN: Multisig.
* VAULT_MANAGER: Can set adapter, cash buffer, slippage, `maxLossBps`.
* NGO_MANAGER: Approve NGOs; rotate current NGO (with delay).
* PAUSER: `pauseInvest`, `pauseHarvest`.
* UPGRADER_ROLE (v1): Timelocked upgrades if UUPS proxy enabled.

### 2.7 Emergency Controller (v1)

* One‑shot `emergencyUnwindAll()` on adapters (best‑effort).
* Pause switches to stop invest/harvest.

---

## 3) Detailed Requirements

### 3.1 Functional

* Users can `deposit/mint` and `withdraw/redeem` per ERC‑4626 semantics with correct previews.
* Vault pushes excess cash to adapter post‑deposit and pulls pre‑withdrawal if cash is low.
* Adapter `invest/divest` succeeds within slippage and `maxLossBps` constraints.
* `harvest()` realizes P/L; profit is sent to DonationRouter; loss is bounded and surfaced.
* DonationRouter transfers to current NGO; optional fee to Treasury.
* NGO Registry authorizes NGOs; vault refuses to set non‑approved NGO.
* Admin can pause invest/harvest without blocking user redemptions (unless adapter illiquidity prevents it).

### 3.2 Non‑Functional

* Safety: Principal never leaves system control; minimize trust in third‑party adapters.
* Gas: Typical deposit/withdraw < 130k with no adapter moves; `invest/divest` cost depends on protocol calls.
* Upgradability: v0 without proxies; v1 optional UUPS with timelock.
* Observability: Rich events for deposits, redemptions, invest/divest, harvest, donations.
* Testability: Unit, fork, fuzz, invariants; >90% critical path coverage.

### 3.3 Slippage & Risk Controls

* Global `slippageBps` per adapter; `maxLossBps` on `divest/harvest`.
* Cash buffer sized (e.g., 1%) to satisfy routine redemptions.
* Oracle/TWAP checks for AMM valuation (Pendle).
* Block invest if market paused/illiquid.

### 3.4 Invariants

* `totalAssets >= cash in vault` at all times.
* Post‑harvest: `donation + fee <= profit`.
* On withdraw: user receives assets consistent with previews (within rounding in user’s favor).
* Adapter can only be called by vault.

---

## 4) Interfaces (high‑level)

### 4.1 Vault (selected)

* `function setActiveAdapter(IYieldAdapter adapter) external onlyOwner/manager`
* `function setCashBufferBps(uint256 bps) external`
* `function harvest() external returns (uint256 profit, uint256 loss)`

### 4.2 Adapter (IYieldAdapter)

* `function invest(uint256 assets) external` onlyVault
* `function divest(uint256 assets) external returns (uint256 returned)` onlyVault
* `function totalAssets() external view returns (uint256)`
* `function harvest() external returns (uint256 profit, uint256 loss)` onlyVault

### 4.3 DonationRouter

* `function distribute(address asset, uint256 amount) external` (authorized caller: vault/keeper). Routes funds to the current NGO after fees.
* `function distributeToMultiple(address asset, uint256 amount, address[] calldata ngos) external` (authorized caller) for equal-split distributions when needed.
* `function distributeToAllUsers(address asset, uint256 amount) external` (authorized caller) distributes yield based on user preferences and shares.
* `function updateFeeConfig(address recipient, uint16 bps) external onlyAdmin`
* **User Preference Functions:**
  * `function setUserPreference(address ngo, uint8 allocationPercentage) external` - Set user's NGO and allocation (50%, 75%, 100%)
  * `function getUserPreference(address user) external view returns (UserPreference memory)` - Get user's current preference
  * `function updateUserShares(address user, address asset, uint256 balance) external` - Update user's share balance (called by vault)
  * `function calculateUserDistribution(address user, uint256 totalYield) external view returns (uint256, uint256, uint256)` - Calculate NGO, treasury, protocol amounts
  * `function getUserAssetShares(address user, address asset) external view returns (uint256)` - Get user's shares for specific asset
  * `function getTotalAssetShares(address asset) external view returns (uint256)` - Get total shares for asset
  * `function getValidAllocations() external pure returns (uint8[] memory)` - Returns [50, 75, 100]

### 4.4 NGO Registry

* `function addNGO(address ngo) external onlyNGOManager`
* `function removeNGO(address ngo) external onlyNGOManager`
* `function isApproved(address ngo) external view returns (bool)`
* `function setCurrentNGO(address ngo) external onlyNGOManager` (v0.2+, with delay)

---

## 5) State Machines & Flows

### 5.1 Deposit

1. User `deposit(assets, receiver)`
2. Mint shares with ERC‑4626 conversion.
3. `afterDeposit`: compute target cash buffer; `invest(excess)` via adapter if any.

### 5.2 Withdraw

1. User `withdraw(assets, receiver, owner)`
2. `beforeWithdraw`: if cash < needed, call `divest(shortfall)` with `maxLossBps`; revert if exceeded.
3. Burn shares; transfer assets to receiver.

### 5.3 Harvest

1. Vault calls `adapter.harvest()`; adapter realizes P/L.
2. If `profit > 0`: Vault transfers profit to DonationRouter and immediately calls `router.distributeToAllUsers(asset, profit)`.
3. DonationRouter calculates each user's yield share based on their vault balance and preference:
   - For each user: `userYield = (userShares / totalShares) * totalProfit`
   - Distribution per user preference: `(ngoAmount, treasuryAmount, protocolAmount) = calculateUserDistribution(user, userYield)`
   - Aggregate all amounts and transfer to respective recipients
4. Protocol fee (1%) is deducted from all distributions and sent to protocol treasury.
3. Router computes `fee = amount * feeBps` and transfers net donation to the current NGO; registry records donation.

### 5.4 Emergency

* `pauseInvest`, `pauseHarvest`.
* `emergencyUnwindAll()` (best‑effort) to pull funds back.

---

## 6) Security Requirements

* Reentrancy guards on vault external methods; adapters keep minimal external calls.
* AccessControl: only vault can call adapter mutating methods.
* Allowance hygiene: set once, reset to zero before change.
* Rounding: favor user on withdraw; avoid share price underflow.
* Slippage: all swaps join/exit bounded by `slippageBps`.
* Oracles: refuse to invest/exit if price deviates beyond tolerance / oracle stale.
* Audit checklist before v1: authorization, invariant proofs, oracle use, paused behavior, griefing vectors.

---

## 7) Testing Strategy

### Unit (no fork)

* ERC‑4626 conversions for 6/8/18‑dec assets; `preview*` ≈ state‑changing outputs.
* Cash buffer logic; invest on deposit; divest on withdraw.
* Donation math for 0/tiny/large profit; fee path; events emitted.

### Fork

* Aave/Euler: invest/divest round trip; simulate low liquidity (partial divest best‑effort).
* Pendle PT: asset↔PT swaps with slippage guards; `totalAssets` tracks oracle quotes.
* (Optional) Pendle LP: enter/exit LP + gauge; claim/swap rewards.

### Fuzz & Invariants

* Random deposit/withdraw sequences; ensure totalAssets monotonicity except for accounted losses.
* Reentrancy attempts against harvest/donation.
* Parameter fuzz for slippage and cash buffer.

### Acceptance (per milestone)

* See Milestones section: specific, measurable conditions to pass.

---

## 8) DevOps, Deployment & Config

* Envs: RPC URLs per chain; protocol addresses (Aave pool, Pendle router/static/markets).
* Accounts: Deployer EOA (testnets), Multisig for admin on prod.
* Timelock (v1): 24–72h on sensitive actions.
* Monitoring:
  * Alerts on `loss > threshold`, `harvest profit == 0 for N periods`, adapter liquidity < X, oracle stale.
  * Dashboards: TVL, total donated, share price, cash buffer, pending withdrawals.
* Indexing: optional Subgraph for events (Deposits, Withdrawals, Invest, Divest, Harvest, DonationPaid).

---

## 9) Roadmap & Step‑by‑Step Implementation

### v0.1 — MVP (Aave/Euler only, single NGO)

Scope

* GiveVault4626 with cash buffer + single `activeAdapter`.
* Aave/Euler Adapter (supply‑only).
* NGO Registry (approve/remove) + DonationRouter with flat split + optional fee.
* Roles: DEFAULT_ADMIN, VAULT_MANAGER, NGO_MANAGER, PAUSER.
* No proxy upgrades yet.

Steps

1. Implement Vault (OZ ERC‑4626 base) + StrategyManager.
2. Implement AaveAdapter (invest/divest/totalAssets).
3. Implement NGORegistry + DonationRouter; wire `harvest()`.
4. Unit + fork tests; deploy to testnet; smoke deposit/withdraw/harvest/donate.
5. Parameterize cash buffer (1%), slippage default (0.5%), `maxLossBps` (25–50 bps).

Acceptance

* Deposit/withdraw round‑trip on fork; donation emitted and received by NGO; no reentrancy issues; events indexed.

---

### v0.2 — NGO rotation delay & ops polish

Scope

* `setCurrentNGO` with 48h timelocked rotation per vault.
* Granular pause: `pauseInvest`, `pauseHarvest`.
* Gas/UX polish; richer events.

Steps

1. Add delayed NGO rotation (queue/execute).
2. Expand events (AdapterUpdated, DonationPaid with tx refs).
3. Add emergency `unwindAll()` (best‑effort) to adapter interface; vault routes call.

Acceptance

* NGO rotation requires delay; pausing halts invest/harvest but withdrawals continue when cash available.

---

### v0.3 — Pendle PT adapter

Scope

* Pendle PT “buy & hold” adapter using Router + RouterStatic; maturity selected per market.
* Oracle/TWAP bounds.
* NAV valuation uses PT→asset quotes.

Steps

1. Implement PT adapter: asset→SY→PT (invest); PT→SY→asset (divest).
2. `totalAssets()` via RouterStatic + safety margin; add `slippageBps` param.
3. Fork tests across small sizes; illiquidity scenarios; loss bounds.
4. StrategyManager can switch adapters (Aave ↔ Pendle) safely.

Acceptance

* Stable NAV tracking; divest slippage respects bounds; switch adapters without share math drift.

---

### v0.4 (optional) — Pendle LP + Gauge

Scope

* Enter/exit LP single‑sided; stake LP in gauge; claim PENDLE; swap rewards to asset in `harvest`.
* Additional risk controls for IL and liquidity.

Steps

1. Implement LP flow and staking; rewards claim + swap.
2. Add price/IL checks; min liquidity guard.
3. Fork tests for rewards accrual and exits under stress.

Acceptance

* Rewards show up in harvest; exits within slippage; safety checks pass.

---

### v0.5 — Hardening & monitoring

Scope

* Add `maxLossBps` globally; oracle freshness checks; structured error reasons.
* Monitoring dashboards + alert rules.

Acceptance

* Alerts fire on configured thresholds; invariant tests run in CI.

---

### v1.0 — Governance & upgrades

Scope

* UUPS proxies for Vault/Manager/Router with Timelock + Multisig control.
* External audit; fix findings; final mainnet deployment.
* (Optional) Merkle claim receipts and per‑user donation accounting.

Acceptance

* Timelocked upgrades only; audit Low/Informational remaining; mainnet smoke passes.

---

## 10) Risk Register (selected)

* Adapter liquidity risk: divest may return less than requested (bounded by `maxLossBps`).
* Oracle manipulation: mitigated via TWAP/Chainlink or dual‑source checks.
* Paused markets: adapters must support best‑effort unwind and pausing.
* Reward token toxicity: fee‑on‑transfer or blacklist tokens; add sweep rules.
* Governance capture: multisig + timelock; least‑privilege roles.

---

## 11) Implementation Notes

* Normalize math to 18‑dec internally; respect external decimals on I/O.
* Support `type(uint256).max` as “all” in user‑facing burn/withdraw flows to avoid dust issues.
* Emit granular events for analytics and audits.
* Keep adapter storage minimal; vault retains authority; adapters approve once and avoid custody when possible.

---

## 12) Open Questions (track)

* Exact donation split policy (fixed vs per‑vault).
* Treasury fee schedule (0–1%).
* Target chains and canonical address sources per chain.
* Which Pendle maturities to support and rotation policy.

---

## 13) Definition of Done (v1)

* Contracts deployed behind timelock + multisig.
* Unit/fork/fuzz/invariant suites green in CI.
* Monitoring live; first donations executed on testnet/mainnet canary vault.
* External audit complete; criticals/mediums resolved.
* Public docs: architecture overview, risk disclosures, how‑to‑use.
