# GIVE Protocol Architecture Overhaul Plan

## 0. Context & Discussion Summary
This document captures the design evolution from the original NGO-centric MVP toward a campaign-driven, multi-strategy GIVE Protocol reminiscent of Kickstarter/Gofundme. Key discussion points:

1. **Initial repo review** – Evaluated existing vault, adapter, donation router, and registry flows; noted strong ERC-4626 foundations and clear role-based access control (AccessControl scattered across contracts).
2. **AaveAdapter analysis** – Confirmed conformance with Aave V3 basics but flagged production gaps (allowance hygiene, emergency thresholds, health checks, etc.).
3. **Roles catalog** – Mapped AccessControl roles across all contracts for clarity.
4. **End-to-end flow** – Documented the lifecycle from NGO registration through harvest and distribution under current architecture.
5. **User & router entry points** – Identified `GiveVault4626.deposit` as the prime user entry and `DonationRouter.distributeToAllUsers` as the main distribution execution path.
6. **Strategic direction** – Shifted focus to a more modular, production-ready architecture with centralized role management, richer strategy control, and scaled distribution.
7. **Rebranding NGOs as Campaigns** – Recognized that the product mirrors crowdfunding; decided to rename NGOs → Campaigns (or similar) and map each campaign to specific strategies/adapters.
8. **One-vault-per-campaign-strategy** – Agreed to deploy distinct ERC-4626 vaults for each campaign-strategy combination, managed via a factory for operational clarity and risk isolation.
9. **Role Manager & Strategy Registry** – Consolidated on creating dedicated modules: RoleManager (central ACL) and StrategyRegistry/Manager to catalog adapters and assign them to campaigns.
10. **Permissionless campaign submission** – Open registration for campaigns, followed by admin approval. Curators and admins can attach strategies and manage payout routes.
11. **Router as UX hub** – Router (renamed PayoutRouter) becomes the user-facing hub for preference management and helper flows, but actual deposits still route through ERC-4626 vaults.
12. **Cross-agent refinements** – Follow-up discussions clarified epoch-based yield cycles, deposit lock-in options, campaign staking for anti-spam, and a 20% protocol fee applied only to generated yield.

## 1. Architectural Goals
- **Modularity & governance**: Centralize ACL in a RoleManager, split global vs per-campaign strategy management, and enable upgrade/timelock controls.
- **Campaign-centric design**: Replace “NGO” terminology with “Campaign” and treat each campaign as a crowdfunding effort with curated strategies.
- **Strategy isolation**: Deploy separate ERC-4626 vaults per campaign-strategy pair to isolate accounting, risk parameters, and reporting.
- **Permissionless onboarding**: Allow anyone to submit a campaign, with admins/DAO approving and curators managing metadata/payout addresses.
- **Scalable distribution**: Keep profit routing efficient and ready for batching or claim-based mechanisms as supporter counts grow.
- **Future-proofing**: Prepare for multi-strategy allocations, external keepers, off-chain indexing, and richer analytics.

## 2. Proposed Component Blueprint

### 2.1 RoleManager (Central ACL)
- Upgradeable contract owning all roles (`ROLE_CAMPAIGN_ADMIN`, `ROLE_STRATEGY_ADMIN`, `ROLE_KEEPER`, `ROLE_CURATOR`, `ROLE_VAULT_OPS`, etc.).
- Exposes `hasRole`, `grantRole`, `revokeRole`, and helper getters (e.g., `isCampaignAdmin(address)`).
- Emits detailed events for indexing (`RoleGranted`, `RoleRevoked`, `RoleAdminChanged`).
- Contracts store `roleManager` as immutable (upgrade by registry) and gate critical functions via shared modifiers.

### 2.2 Strategy Management Layer
- **StrategyRegistry (global)**
  - Stores strategies: `{id, asset, adapter, metadataURI, riskTier, status}`.
  - Managed by strategy admins; emits events on creation/update/deactivation.
- **StrategyManager / StrategyController (per vault or per campaign)**
  - References allowed strategy IDs, sets target weights (future extension), handles cash-buffer/slippage parameters, and orchestrates rebalancing/emergency exits.
  - Interacts with `RoleManager` for permission checking.
  - Optionally hosts multiple strategies per vault with allocation logic.

### 2.3 Campaign Lifecycle
- **CampaignRegistry**
  - `submitCampaign(metadataCID, curator, payoutAddress)` (permissionless) → status `Pending`.
  - `approveCampaign`, `rejectCampaign`, `pauseCampaign`, `activateCampaign` controlled by campaign admins.
  - `updateCurator`, `updatePayoutAddress` accessible to curator (with safeguards) or admin.
  - `attachStrategyToCampaign(campaignId, strategyId)` callable by curator or admin (subject to policy). To prevent abuse, consider admin confirmation for high-risk strategies.
  - Tracks campaign metadata, statuses, attached strategies, and payout history.
- Terminology: Campaign, Project, or Cause (decide final naming for UX consistency).

### 2.4 Vault Factory & ERC-4626 Instances
- **VaultFactory**
  - Deploys minimal proxy clones of `CampaignVault` (ERC-4626) with params `(asset, campaignId, strategyId, controller)`. Suggested naming: `CampaignVaultFactory`.
  - Emits `VaultCreated(campaignId, strategyId, vaultAddress)` for discovery.
  - Registers the new vault with CampaignRegistry and StrategyManager.

- **CampaignVault (ERC-4626)**
  - Thin wrapper around current `GiveVault4626`; removes embedded AccessControl, using RoleManager for permissions.
  - Holds only the single strategy defined at deployment (or referencing strategy controller).
  - Harvest transfers profit to PayoutRouter specific to this vault.
  - Optionally stores a pointer to `campaignId` and `strategyId` for event logging.

### 2.5 Adapter & Strategy Controllers
- Existing adapters (Aave, Pendle, etc.) remain but now register through StrategyRegistry.
- StrategyController per vault manages the adapter link, ensures health checks, and triggers emergency exit via RoleManager-authorized roles.
- Adapter improvements (from previous review) remain mandatory: safer approvals, slippage guards in emergencies, reserve health checks, event coverage.

### 2.6 Payout & Preference Layer
- **PayoutRouter** (enhanced DonationRouter)
  - Acts as user-facing hub: store preferences, provide helper `depositAndSupport` flows, manage per-vault distributions.
  - Receives harvest profits from a specific vault, applies protocol fees, uses user preferences (if any) or default payout address.
  - Records payouts via CampaignRegistry (`recordPayout(campaignId, amount, token)`), enabling analytics dashboards.
  - Keep ability to fall back to default payout if no preference data exists.
  - Prepare for claim-based payouts or batched distributions when supporter count grows (optional future module: `PayoutBatcher`).

- **PreferenceRegistry** (optional new module)
  - If preferences become complex, store them in a dedicated contract to keep PayoutRouter lean. Could allow multi-NGO splits or tiered donations later.

### 2.7 Supporting Infrastructure
- **Address/Config Registry**: Maintains references to RoleManager, StrategyRegistry, CampaignRegistry, VaultFactory, etc., enabling controlled upgrades.
- **Circuit Breaker**: Optional contract to globally pause deposit/harvest/payout operations with granular flags.
- **Monitoring interfaces**: View functions for health status, last harvest timestamp, total donated per campaign, TVL per vault, etc.
- **Event standardization**: Adopt consistent event schemas (`CampaignSubmitted`, `CampaignApproved`, `StrategyAttached`, `VaultCreated`, `Harvest`, `PayoutExecuted`, etc.) for off-chain indexers.

## 3. Execution Roadmap

### Phase 1 – Governance Foundation
1. Implement `RoleManager` with upgradeability (UUPS or transparent proxy) and seed roles via multisig/timelock.
2. Introduce `ConfigRegistry` to store key contract addresses for discoverability and future upgrades.
3. Refactor existing contracts to remove embedded AccessControl inheritance and reference RoleManager instead.

### Phase 2 – Registries & Factory
1. Build `StrategyRegistry` with CRUD operations, risk metadata, and lifecycle states (`ACTIVE`, `FADING_OUT`, `DEPRECATED`).
2. Build `CampaignRegistry` with submission → approval lifecycle, campaign staking escrow, and strategy attachment logic.
3. Implement `VaultFactory` + `CampaignVault` clone (ERC-4626) referencing new registries and lock-in profile selection.
4. Update deployment scripts to orchestrate registry setup, factory deployment, and sample vault creation including stake flow tests.

#### Phase 2 Implementation Details
- **Shared enums & structs**
  - `enum RiskTier { Conservative, Moderate, Aggressive, Experimental }`
  - `enum StrategyStatus { Inactive, Active, FadingOut, Deprecated }`
  - `enum CampaignStatus { Draft, Submitted, Active, Paused, Completed, Cancelled, Archived }`
  - `enum LockProfile { Days30, Days90, Days180, Days360 }` with helper to map to seconds.
- **StrategyRegistry**
  - `struct Strategy { uint64 id; address asset; address adapter; uint8 risk; StrategyStatus status; string metadataURI; uint256 maxTvl; uint256 createdAt; uint256 updatedAt; }`
  - Auto-increment id, emit events on create/update/status change.
  - Access: strategy admins manage lifecycle; guardians can force `FadingOut`/`Deprecated`.
  - View helpers: `listStrategies()`, `getStrategy(id)`, `strategyCount()`.
- **CampaignRegistry**
  - `struct Campaign { uint64 id; address creator; address curator; address payout; uint96 stake; LockProfile defaultLock; CampaignStatus status; string metadataURI; uint256 createdAt; uint256 updatedAt; uint64[] strategyIds; }`
  - Permissionless `submitCampaign` accepts stake (>= `MIN_STAKE_WEI` e.g. 0.0001 ETH). Funds escrowed until approve/reject.
  - Admin `approveCampaign` moves to Active and refunds stake; `rejectCampaign` slashes stake to treasury (optional) or refunds partial per policy.
  - Curator/Admin `attachStrategy` can only pick `StrategyStatus.Active`. Optional guardian check for risk gating.
  - Events: `CampaignSubmitted`, `CampaignApproved`, `CampaignRejected`, `CampaignPaused`, `StrategyAttached`, `StrategyDetached`, `CuratorUpdated`, `PayoutUpdated`.
- **Campaign↔Strategy relationship**
  - Maintain mapping `campaignStrategies[campaignId][strategyId]` and enumerable list for discovery.
  - Provide view `getActiveStrategies(campaignId)` to drive frontend and vault factory.
- **VaultFactory**
  - Constructor caches RoleManager + registries.
  - `deployVault(uint64 campaignId, uint64 strategyId, LockProfile lockProfile, string name, string symbol)` callable by strategy admin or curator (if policy allows) while campaign & strategy active.
  - Deploy minimal proxy of `CampaignVault4626` (new contract inheriting `GiveVault4626`) with immutable metadata (campaignId, strategyId, lockProfile).
  - Emits `VaultCreated(campaignId, strategyId, lockProfile, vault)` and registers vault in both registries.
- **CampaignVault4626**
  - Extends existing vault, adds immutable `campaignId`, `strategyId`, `lockProfile`, `factory`.
  - Overrides deposit/redeem to enforce lock-in schedule (store deposit timestamps per user and allow early exit penalty/deny until unlock).
  - Harvest emits event tagged with campaign & strategy ids.
- **Router/Manager integration**
  - `StrategyManager` updated to reference `StrategyRegistry` for adapter lookups instead of direct approvals.
  - `DonationRouter` (future `PayoutRouter`) receives campaign id context from vault on harvest for accounting.

The above scaffolding should be accompanied by Foundry tests covering permissioned flows, stake escrow, strategy attachment, vault deployment, lock-profile enforcement, and registry view helpers.

### Phase 3 – Router, Epochs & Distribution Enhancements
1. Refactor DonationRouter → `PayoutRouter`, integrate with CampaignRegistry, support per-vault payouts, and apply the 20% yield fee.
2. Implement the 7-day `EpochScheduler` (or router module) with keeper incentives and catch-up logic; ensure epoch processing respects vault lock-in states.
3. Add helper entrypoints (`depositAndSupport`) while ensuring base deposits still happen through ERC-4626 `deposit` and lock-in choices are captured.
4. Evaluate distribution scalability: design batching or claim-based flows if per-harvest loops become gas-costly.
5. Expand event coverage for payouts, epoch processing, fee accruals, and preference changes.

### Phase 4 – Adapter Hardening & Strategy Controls
1. Apply previously identified AaveAdapter improvements (allowance management, emergency thresholds, reserve health checks, events).
2. Extend adapter architecture to accept configuration from StrategyController (e.g., referral codes, max TVL, emergency exit parameters).
3. Add standard interface for adapters to report health and metadata (underlying protocol, risk scores) feeding into StrategyRegistry.
4. Introduce keepers (off-chain bots) for harvest, rebalance cadence, and epoch processing, with on-chain signals to detect when action is needed.
5. Define workflows for transitioning strategies into `FADING_OUT` and eventually `DEPRECATED`, notifying affected vaults.

### Phase 5 – UX & Analytics Alignment
1. Update frontend to surface campaigns, strategies, lock-in options, and matching vaults (via factory events and registry queries).
2. Integrate `PayoutRouter` helper flows and preference management, including stake refund status.
3. Provide dashboards (off-chain indexing) for campaign totals, per-strategy performance, epoch yields, and historical payouts.
4. Document operational runbooks: emergency procedures, role updates, strategy onboarding, campaign approvals, and epoch processing SOPs.

## 4. Open Questions / Design Decisions
- **Campaign naming**: settle on final term (Campaign, Project, Cause) and reflect across contracts & UI.
- **Strategy attachment scope**: curators may only attach strategies that are already approved/listed in `StrategyRegistry` by `ROLE_STRATEGY_ADMIN`. When new strategies are listed, curators can opt to link them to their campaigns without additional approval, but governance should define guardrails for automatically enabling higher-risk tiers.
- **Epoch incentives**: determine reward mechanism (fee rebate, direct payment) for keepers who trigger epoch processing and harvest batching.
- **Lock-in policy**: clarify whether early exit is ever allowed (with penalty) or strictly prohibited until 30/90/180/360-day term ends.
- **Vault indexing & UX**: consider an on-chain registry of all vault addresses (maybe from factory) to power the frontend.
- **Fallback governance**: define break-glass owner or timelock in case RoleManager is compromised or misconfigured.
- **Strategy deprecation UX**: specify how users are notified when a strategy enters `FADING_OUT` and deadlines for exiting.
- **Campaign metadata storage**: long-term plan for metadata (IPFS, Ceramic, etc.), including validation and updates by curator.

## 5. Immediate Next Steps
1. Draft interface definitions for RoleManager, StrategyRegistry, CampaignRegistry (with stake escrow), VaultFactory, CampaignVault (with lock-in tracking), EpochScheduler, PayoutRouter.
2. Prototype RoleManager and update a sample contract (e.g., adapter) to use it for access checks.
3. Design the vault factory deployment flow and event schema for discoverability, including strategy state transitions.
4. Define epoch-processing and lock-in data structures, then document campaign submission/approval UI flow and required metadata fields for curators.

---
This plan aims to transition GIVE Protocol from a single-vault, NGO-focused MVP into a scalable, campaign-driven platform with modular governance, strategy isolation, and clear user journeys. It’s intended as a blueprint so future contributors (human or AI) can align on the architecture before implementation.
