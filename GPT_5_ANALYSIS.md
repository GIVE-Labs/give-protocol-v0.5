# GPT-5 Analysis: GIVE Protocol Repository

## Repository Overview
- Top-level documentation maps architecture, onboarding, and deployment processes.
- Backend smart contracts live under `backend/` (Foundry workspace).
- Frontend application lives under `frontend/` (React + Vite + wagmi).
- Additional resources include `docs/`, `llm/`, `references/`, and helper scripts in `bin/`.

## Backend (Foundry)
- `src/vault/GiveVault4626.sol`: ERC-4626 vault with cash buffer management, donation router integration, and wrapped-native helpers.
- `src/manager/StrategyManager.sol`: Adapter approval/activation, vault parameter updates, auto-rebalancing heuristics, and emergency controls.
- `src/adapters/AaveAdapter.sol`: Aave V3 yield sourcing with access control, slippage bounds, and emergency withdrawal path.
- `src/donation/DonationRouter.sol` & `src/donation/NGORegistry.sol`: User preference-driven donation routing, protocol fee handling, NGO approval/rotation, and donation accounting.
- `src/interfaces/` & `src/utils/Errors.sol`: Adapter interface, IWETH helper, and shared custom errors.
- Scripts (`script/Deploy.s.sol`, `DeployLocal`, etc.) wrap deployments with network-aware configs from `HelperConfig.s.sol`.
- Tests cover vault flows, adapter mechanics, donation math, ETH wrapping, and Sepolia fork smoke checks.
- Makefile exposes build/test/deploy/format routines with NETWORK-aware defaults.

## Frontend (React + wagmi)
- Bootstrapped via `src/main.tsx` and routed in `src/App.tsx`.
- Chain configuration and contract addresses resolved through `src/config/` (`contracts.ts`, `local.ts`, `sepolia.ts`, `web3.ts`).
- Contract ABIs synced from backend via `pnpm sync-abis` producing JSON under `src/abis/`.
- Hooks in `src/hooks/useContracts.ts` abstract vault/router/strategy interactions; `useNGORegistryWagmi.ts` currently backfills placeholder NGO metadata.
- `src/services/ipfs.ts` wraps Pinata uploads/fetches, warns when gateway/JWT env vars missing, and returns mock data on failure.
- UI composed from pages (`src/pages/`) and components (`src/components/`), with staking form still stubbed pending contract wiring.
- Mock NGO data in `src/data/mockData.ts` supports display when chain data absent.

## Data & Control Flow
1. User deposits into GiveVault4626, which updates DonationRouter share balances (for proportional yield accounting) and invests excess into the active adapter.
2. Adapter accrues yield (e.g., via Aave). `vault.harvest()` collects profit, transfers assets to DonationRouter, and triggers `distributeToAllUsers`.
3. DonationRouter splits each user’s yield according to preferences (50/75/100% to NGO) after protocol fee, paying NGOs/treasury/fee recipients and recording totals in the registry.
4. If no share data exists, router falls back to legacy single-NGO distribution using current registry selection.

## Key Documentation & Guides
- `README.md`: project overview, setup, and deployment commands.
- `docs/SystemRequirements.md`: architecture spec, milestone roadmap, and security/testing requirements.
- `docs/BACKEND_DEVELOPMENT.md`: implementation plan, testing expectations, and security checklist.
- `DEPLOYMENT_ADDRESS_GUIDE.md`: mapping backend deployment outputs into frontend configs.

## Suggested Next Steps
1. Install dependencies and ensure the contract/test suites pass (`forge test`, `pnpm lint`, etc.).
2. Sync ABIs and update contract addresses after any redeployments before running `pnpm dev`.
3. Replace placeholder NGO metadata/IPFS fallbacks with live data once Pinata credentials and registry entries are available.

## AaveAdapter Review & Production Readiness Notes

### Conformance with Aave V3 Expectations
- Implements the minimum interaction surface ( `IPool.supply` / `withdraw` ) and pulls reserve data in the constructor to discover the `aToken` address, aligning with standard adapter patterns.
- Tracks vault-owned position via the adapter’s own `aToken.balanceOf` (aToken is 1:1 with underlying principal+yield in Aave V3). For more exact valuation, production adapters typically query `scaledBalanceOf` with the current liquidity index; here, the straight `balanceOf` works but bakes in any reserve-factor drift.
- Uses `forceApprove` to set an infinite allowance for the pool. While common, Aave’s guidelines now recommend resetting allowances to zero before re-approval to mitigate ERC20 quirks; consider switching to OZ’s `safeIncreaseAllowance` or at least emitting an event after allowance refresh.
- Referral code is hard-coded to 0. If you partner with integrators or need attribution, expose a setter (guarded by admin) that accepts Aave-approved referral codes.
- Harvest logic mirrors Aave’s supply-only yield model: calculates profit as `aTokenBalance − totalInvested`, withdraws that profit, and updates the `totalInvested` baseline. This is consistent with Aave’s expectations provided the adapter never leaves residual debts.

### Roles & Permissions
- `DEFAULT_ADMIN_ROLE`: full admin; can grant/revoke other roles, adjust slippage params, deactivate emergency mode, unpause, etc.
- `VAULT_ROLE`: bound to the vault; only this role may call `invest`, `divest`, and `harvest`.
- `EMERGENCY_ROLE`: granted to the admin in the constructor; can trigger `emergencyWithdraw`, `pause`, and toggle invest/harvest pausing.

### Gaps & Production Hardening Suggestions
1. **Allowance Hygiene** – Replace `forceApprove` infinite approvals with a safer pattern (`safeIncreaseAllowance` or setting back to zero before re-approval) to accommodate non-standard ERC20 tokens and minimize allowance-based attack surface.
2. **Protocol Health Checks** – Add periodic assertions that Aave reserve is active and not frozen (e.g., using `IPool.getReserveData` flags) before investing/harvesting, and surface those checks externally for monitoring.
3. **Normalized Accounting** – Consider using `scaledBalanceOf` with liquidity index reads to decouple accounting from the adapter’s mutable `totalInvested` state; this avoids edge cases where partial divests/interest accrual drift from the baseline.
4. **Slippage & Loss Handling** – `maxSlippageBps` is enforced on normal divests, but emergency exits ignore the configured `emergencyExitBps`. Wire `emergencyExitBps` into the emergency withdrawal path so you can cap worst-case losses during stress events.
5. **Dust & Residuals** – After divest or emergency withdraw, ensure any residual `asset` balance is forwarded back to the vault (currently handled, but add tests covering rounding dust to avoid stranded funds).
6. **Rate Limiting / Harvest Guards** – Introduce guardrails on harvest cadence (e.g., min interval, keeper address list) to prevent griefing via repeated harvest calls that waste gas or manipulate donation timing.
7. **Event Coverage** – Emit explicit events for parameter changes (`maxSlippageBps`, `emergencyExitBps`) and emergency toggles already exist; add events when allowances change or referral code (if added) updates.
8. **Upgradeable Hooks** – If the protocol will live behind a proxy, ensure constructor logic migrates into an initializer and that `forceApprove` is re-run post-upgrade.
9. **Gas Optimizations** – Cache `address(asset)` in local storage reads (multiple SLOADs per call) and short-circuit `divest` early when `assets == 0` _before_ hitting the `onlyVault` check to shave a bit of gas.
10. **Protocol Fee Awareness** – Monitor Aave’s reserve factor and possible liquidity mining incentives. If you want to harvest liquidity mining rewards (stkAAVE), additional contracts/tasks will be required; today’s adapter ignores those.

### Flow & Architectural Considerations
- `emergencyWithdraw` flips `emergencyMode` but leaves it to admin to call `deactivateEmergencyMode`. Ensure downstream vault logic treats `emergencyMode` as read-only so funds cannot be re-invested without explicit admin action.
- `divest` currently requests `type(uint256).max` when asked to withdraw more than balance, which is Aave-safe, but ensure vault-side callers understand they might receive less than requested and handle the residual shortfall promptly.
- `totalInvested` bookkeeping assumes the adapter only ever receives assets from the vault. Add a sanity check in `invest` to revert if `asset.balanceOf(this)` materially exceeds the requested amount (protecting against accidental direct transfers).
- Consider exposing a public view that returns `aToken.balanceOf` alongside `totalInvested`, `cumulativeYield`, and `emergencyMode` so off-chain monitoring can reconcile adapter health without parsing events.

Overall, the adapter follows the core Aave V3 supply-only playbook, but tightening allowance management, enhancing health checks, and threading emergency thresholds through the withdrawal paths would make it more production-ready.

## Contract Roles Summary

### GiveVault4626 (`backend/src/vault/GiveVault4626.sol`)
- `DEFAULT_ADMIN_ROLE`: Full control; initially granted to the admin passed to the constructor. Can grant/revoke other roles and call emergency withdrawals.
- `VAULT_MANAGER_ROLE`: Configures cash buffer, slippage, max loss, donation router, wrapped native token, and adapter assignments.
- `PAUSER_ROLE`: Can pause investing/harvesting and trigger full emergency pause.

### StrategyManager (`backend/src/manager/StrategyManager.sol`)
- `DEFAULT_ADMIN_ROLE`: Oversees role management, emergency mode toggling, and unpausing.
- `STRATEGY_MANAGER_ROLE`: Approves adapters, activates adapters, updates vault parameters, sets donation router, tunes rebalance interval, and enables/disables auto-rebalance.
- `EMERGENCY_ROLE`: Activates emergency mode, triggers vault emergency withdrawals, and pauses investing/harvesting.

### AaveAdapter (`backend/src/adapters/AaveAdapter.sol`)
- `DEFAULT_ADMIN_ROLE`: Adjusts slippage parameters, emergency exit thresholds, manages allowances, unpauses adapter, and deactivates emergency mode.
- `VAULT_ROLE`: Assigned to the vault; only this role may call `invest`, `divest`, and `harvest`.
- `EMERGENCY_ROLE`: Triggers adapter `pause`, toggles emergency mode (via `emergencyWithdraw`), and coordinates emergency actions.

### MockYieldAdapter (`backend/src/adapters/MockYieldAdapter.sol`)
- Mirrors `VAULT_ROLE` and `DEFAULT_ADMIN_ROLE` semantics for local testing (invest/harvest restricted to vault; admin can update parameters). [Confirm by reviewing file if needed]

### DonationRouter (`backend/src/donation/DonationRouter.sol`)
- `DEFAULT_ADMIN_ROLE`: Manages pausing/unpausing, protocol treasury, and withdraws accumulated protocol fees; can also set authorized callers indirectly via other roles if desired.
- `VAULT_MANAGER_ROLE`: Authorizes or deauthorizes callers (e.g., vault) that can trigger distributions or update shares.
- `FEE_MANAGER_ROLE`: Updates fee recipient and fee basis points.

### NGORegistry (`backend/src/donation/NGORegistry.sol`)
- `DEFAULT_ADMIN_ROLE`: Grants/revokes roles, sets current NGO in emergencies, and controls pause state.
- `NGO_MANAGER_ROLE`: Approves/removes NGOs, updates metadata, proposes current NGO changes, and executes timelocked rotations.
- `DONATION_RECORDER_ROLE`: Records donation totals per NGO (typically granted to DonationRouter).
- `GUARDIAN_ROLE`: Can pause the registry (one-way) as an additional safety lever.

## Notes on Role Interactions
- The vault, strategy manager, adapter, donation router, and registry coordinate via explicit role assignments during deployment scripts (e.g., `Deploy.s.sol` grants router authorization and registers the donation recorder role).
- For production hardening, consider separating deployer/admin duties (multisig), introducing timelocks around sensitive role-granted actions, and verifying that emergency roles are held by dedicated guardian addresses.

## Contract Responsibilities Overview
- **GiveVault4626**: ERC-4626 compliant vault that accepts deposits of the underlying asset, maintains a configurable cash buffer, routes excess liquidity to the active yield adapter, and on harvest sends realized profits to the DonationRouter while keeping user principal redeemable. It also updates DonationRouter with user share balances and exposes wrapped-native convenience methods for ETH flows.
- **StrategyManager**: Governance layer for the vault that whitelists adapters, switches the active adapter, adjusts vault risk parameters (cash buffer, slippage, max loss), manages donation router assignments, coordinates rebalancing cadence, and orchestrates emergency responses (pausing, emergency withdrawals).
- **AaveAdapter**: Yield adapter that supplies vault assets to Aave V3, tracks invested principal vs accrued yield, enforces slippage and emergency guardrails during divestments, and funnels harvested profits back to the vault for donation distribution.
- **MockYieldAdapter**: Lightweight adapter used in local deployments/tests to emulate invest/divest/harvest flows without external dependencies, ensuring the vault and router logic can be exercised off-chain.
- **DonationRouter**: Receives harvested yield, aggregates per-user preferences (NGO selection and donation percentage), and distributes funds among NGOs, protocol treasury, and fee recipient. It also maintains user share tracking for proportional splits, authorizes callers, and falls back to legacy single-NGO routing when no user data exists.
- **NGORegistry**: Manages the lifecycle of approved NGOs, storing metadata and KYC attestations, exposing timelocked rotation of the “current NGO,” recording donations (via DonationRouter), and providing access-control-gated approval/removal pathways along with pause/guardian mechanisms.
- **Errors Library**: Consolidates custom error selectors used across contracts for gas-efficient reverts and consistent messaging around invalid states.
- **Aave Fork / Mock Interfaces (IPool, IAToken, IWETH)**: Interface definitions that allow adapters and vault to interact with external protocols (Aave pool, WETH contracts) in a type-safe manner.
- **Deployment Scripts (`Deploy`, `DeployLocal`, `DeployETHVault`)**: Automate end-to-end setup by deploying registry, router, vault, manager, and adapters; wiring role assignments; configuring defaults; and switching between mock and production adapters depending on the target chain.

## End-to-End Flow Summary
1. **NGO Onboarding**
   - Admin (holding `NGO_MANAGER_ROLE`) calls `NGORegistry.addNGO`, providing the NGO’s address, metadata CID, KYC hash, and attestor. Registry marks the NGO as approved, stores metadata, and, if none exists, sets it as the current NGO.
   - For governance-driven rotations, admin can `proposeCurrentNGO` (timelocked) or emergency-set a new current NGO. DonationRouter is granted `DONATION_RECORDER_ROLE` so it can log donations via `recordDonation`.

2. **User Configuration**
   - Donors optionally call `DonationRouter.setUserPreference` to choose an approved NGO and a donation percentage (50/75/100%). Router validates the NGO against the registry and records preference metadata.

3. **Deposit & Share Tracking**
   - A donor approves the vault to spend the underlying asset (e.g., USDC) and calls `GiveVault4626.deposit` (or the ETH convenience methods if using wrapped native). Vault mints ERC-4626 shares.
   - Inside `_deposit`, the vault notifies DonationRouter via `updateUserShares`, passing the user address, asset, and new share balance. This updates per-asset totals so yield can be distributed proportionally.
   - Vault maintains a cash buffer and pushes any excess liquidity into the active adapter (`_investExcessCash`). StrategyManager controls buffer/slippage/max-loss parameters and adapter selection.

4. **Yield Accrual & Harvest**
   - Adapter (e.g., AaveAdapter) supplies assets to the yield source, accruing value over time. When an authorized actor (vault manager/keeper) calls `GiveVault4626.harvest`:
     1. Vault invokes `activeAdapter.harvest()`, realizing profit/loss and receiving profit back into the vault.
     2. Vault updates cumulative profit/loss stats and transfers the realized profit to DonationRouter.
     3. Vault calls `DonationRouter.distributeToAllUsers(asset, profit)` so the router can split funds per preference and share weight.

5. **Donation Router Distribution**
   - Router locates all users with non-zero shares for the asset and computes each user’s share of total profit (`userShares / totalAssetShares * profit`).
   - For each user, router applies `calculateUserDistribution`, which:
     - Deducts the protocol fee (2.5% constant), sending it to `protocolTreasury`.
     - Splits the net yield per user preference (e.g., 75% to selected NGO, remainder to fee recipient/treasury).
   - Router transfers aggregated NGO allocations to the respective NGO addresses and records the donation in the registry. Treasury (fee recipient) receives the non-donated portion. If no user shares exist, router falls back to the current registry NGO and applies a flat fee.

6. **Withdrawals & Updates**
   - When a donor withdraws or redeems shares, the vault calls `updateUserShares` again to reflect the reduced balance. If divestments are needed, adapter returns funds subject to slippage/max-loss bounds.
   - Emergency or pauser roles can halt investing/harvesting, trigger adapter emergency withdrawals, or pause the registry/router if anomalous behavior occurs.

This flow keeps principal in the vault, routes realized yield to approved NGOs according to user-selected allocations, and maintains on-chain auditability across registry, vault, adapter, and router components.

### StrategyManager’s Role in the Ecosystem
- **Adapter Governance:** Holds the authority to approve adapters, mark them active on the vault, and maintain the curated list of acceptable strategies. This determines where user principal is deployed (Aave adapter today, other yield sources in future revs).
- **Parameter Stewardship:** Writes the vault’s risk knobs (`cashBufferBps`, `slippageBps`, `maxLossBps`) and points the vault at the correct DonationRouter instance. These settings directly affect how much liquidity stays on hand, acceptable divest slippage, and loss tolerances during withdrawals.
- **Rebalancing Coordination:** Tracks a configurable rebalance interval and, when triggered (manually or via keepers), evaluates approved adapters to switch to the “best” one (currently by assets under management). This is the mechanism by which funds can be migrated between strategies without user interaction.
- **Emergency Response:** Through its `EMERGENCY_ROLE`, it can pause investing/harvesting, activate emergency mode, and call the vault’s `emergencyWithdrawFromAdapter`, pulling funds back from the yield venue if risk conditions degrade.
- **Bridging Governance & Vault:** Acts as the operational bridge between higher-level governance and the technical vault by encapsulating adapter selection logic and parameter updates in one contract, so the vault’s own interface stays minimal and tightly controlled.

## Revised Architecture Concepts (Campaign-Centric Model)

### Terminology Shift
- Replace "NGO" with **Campaign** (or similar: Cause, Project). Each campaign represents a fundraising effort with its own curator PIC and payout address.

### Central Governance — `RoleManager`
- Standalone upgradeable contract owning all role assignments (campaign admin, strategy admin, vault ops, curators, keepers).
- Contracts accept `roleManager` address in constructor; modifiers query `RoleManager` for permissions (`modifier onlyRole(bytes32 role)` calling `roleManager.hasRole(role, msg.sender)`).
- Emits standardized events for role changes; can be swapped/upgraded via registry if ever compromised.

### Strategy Lifecycle
- **StrategyRegistry** (global): stores strategy definitions `{id, asset, adapter, metadataURI, status}` plus risk caps. Managed by strategy admins; keepers/curators read from it.
- **StrategyManager** (per asset or per controller):
  - References `StrategyRegistry` entries.
  - Allows campaign curators and strategy admins to attach strategies to campaigns (with optional weights or min/max caps).
  - Manages rebalancing within a vault if multiple strategies are active (future extension).
  - Handles emergency exits, slippage settings, cash buffers for associated vaults.

### Campaign Lifecycle — `CampaignRegistry`
- `submitCampaign(metadataCID, curator, payoutAddress)`: permissionless; status = Pending.
- `approveCampaign(campaignId)` / `rejectCampaign(campaignId)`: callable by campaign admins (was `NGO_MANAGER_ROLE`).
- `updateCurator` and `updatePayout`: callable by curator or admin with safeguards.
- `attachStrategy(campaignId, strategyId)`: curator or admin can link one or more strategies from `StrategyRegistry`; only approved strategies allowed.
- Keeps campaign state machine (`Pending`, `Approved`, `Inactive`, `Blacklisted`).

### Vault Per Campaign-Strategy Pair
- Introduce `VaultFactory` that deploys minimal proxy instances of `CampaignVault` (ERC-4626) initialized with `(asset, strategyController, campaignId, strategyId)`.
- Naming pattern: `CampaignVault(campaignId, strategyId)` e.g., `NANYANG_FOUNDATION-USDC-AAVE`.
- Benefits: isolates accounting, simplifies reporting, allows distinct risk params per campaign-strategy.
- Trade-off: proliferation of vaults → need indexing layer and good UX to surface them. Mitigate by limiting strategies per campaign and having factory emit discovery events.
- Each vault wires into its own StrategyController which points to the selected adapter and shares harvest results with the campaign’s payout router.

### Deposits & User Entry
- Users interact with vaults (`CampaignVault.deposit`) for chosen campaign-strategy pair.
- `DonationRouter` (renamed to **PayoutRouter**) can expose convenience entry points: `depositAndSupport(campaignId, strategyId, amount, preferenceData)` bundling preference registration + deposit.
- Preference storage can remain in router or move to a dedicated `PreferenceRegistry`.

### Harvest & Distribution Flow
1. Vault harvests adapter profit → transfers to PayoutRouter dedicated to that campaign vault.
2. PayoutRouter applies user preferences (if any) or defaults to campaign payout address.
3. Protocol/tresury fees deducted per vault configuration.
4. Payout events recorded back in `CampaignRegistry` (`recordPayout`) for analytics.

### Additional Considerations
- **Scaling**: Implement batching/claim flows if user counts grow (e.g., Merkle distribution per harvest) to avoid O(n) loops.
- **Monitoring**: Factory + registries emit events to help indexers build catalog of campaigns, strategies, and vaults.
- **Composability**: Separate payout router per campaign vault keeps downstream integrations simple (each vault knows its payout target set).
- **Security**: Campaign approvals remain permissioned; however, strategy attachment by curator should optionally require admin confirmation to avoid negligent assignments.
- **UX**: Frontend aggregates campaigns, shows supported strategies, and guides users to the vault contract that matches the selected combination.

Overall: adopt a campaign-centric architecture where every campaign-strategy pair maps to its own ERC-4626 vault instantiated via factory, curated strategies come from a global registry, and role management is centralized. This keeps principal isolated per effort, supports varied yield sources, and mirrors the Kickstarter-like experience while staying on familiar ERC-4626 rails.
