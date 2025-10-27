/**
 * Campaign Event Log Service
 * 
 * ⚠️ DISABLED FOR ALCHEMY FREE TIER
 * 
 * Alchemy free tier has a strict 10-block maximum for eth_getLogs requests.
 * This makes event log queries impractical for production use.
 * 
 * Recommended solutions:
 * 1. Use The Graph subgraph indexer for historical events
 * 2. Upgrade to Alchemy Growth plan (unlimited eth_getLogs)
 * 3. Store campaign CIDs directly in localStorage when campaigns are created
 * 4. Use on-chain mapping of campaignId → CID instead of events
 */

/**
 * Fetch IPFS CID for a campaign from event logs
 * 
 * ⚠️ DISABLED: Alchemy free tier has 10 block maximum for eth_getLogs
 * 
 * @param campaignId - The campaign ID (bytes32)
 * @returns Always returns null (disabled)
 */
export async function getCampaignCIDFromLogs(
  _campaignId: `0x${string}`
): Promise<string | null> {
  return null;
}

/**
 * Build a mapping of all campaign IDs to their CIDs from event logs
 * 
 * ⚠️ DISABLED: Alchemy free tier restrictions
 * 
 * @returns Always returns empty object (disabled)
 */
export async function buildCampaignCIDMapping(): Promise<Record<string, string>> {
  return {};
}

/**
 * Cache the CID mapping in localStorage for faster subsequent loads
 * 
 * ⚠️ DISABLED: Event log fetching is disabled
 */
export async function cacheCampaignCIDs(): Promise<void> {
  return;
}
