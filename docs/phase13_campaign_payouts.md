# Phase 13 – Campaign Payouts & Router Architecture

## Overview
- `PayoutRouter` replaces `DonationRouter` and operates on campaign IDs rather than NGOs.
- Vaults register against the router via `setDonationRouter` and report user share balances with `updateUserShares`.
- Supporters set per-vault preferences (`campaignId`, `beneficiary`, allocation %) via `setVaultPreference`.
- Campaign metadata (recipient wallets, vault lock profiles) lives in `CampaignRegistry`; strategy constraints live in `StrategyRegistry`.
- Protocol fees are tracked per campaign (`campaignProtocolFees`) and exposed via `getCampaignTotals`.

## Flow Summary
1. **Deployment**
   - Bootstrap deploys ACL, registries, payout router, vault factory, core vault.
   - Factory auto-registers campaign vaults with registry + router.
2. **Deposits**
   - Vaults call `updateUserShares` on the router after deposits/withdrawals to maintain live share totals.
3. **Preference Updates**
   - Supporters pick a beneficiary + allocation; defaults to 100% campaign if unset.
4. **Harvest**
   - Vault harvests yield, transfers profits to router, and calls `distributeToAllUsers`.
   - Router calculates per-user allocations → campaign recipient + optional beneficiary + protocol fee.
5. **Accounting**
   - Totals stored per campaign, enabling reporting and future fee sweeps.

## Next Steps (Phase 14+)
- Implement checkpoint voting (router should halt payouts when campaigns fail checkpoints).
- Stake escrow refunds on failed checkpoints.
- Keeper hooks for automated campaign status checks.
- SDK & UI updates for supporter preference management.

