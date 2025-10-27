/**
 * Campaign ID to IPFS CID Mapping
 * 
 * This is a temporary workaround for Alchemy free tier limitations.
 * The proper solution is to use The Graph subgraph to index CampaignSubmitted events.
 * 
 * To add a new campaign:
 * 1. Find the CampaignSubmitted event transaction on BaseScan
 * 2. Look for the metadataCID parameter in the event logs
 * 3. Add the campaignId → CID mapping below
 */

export const CAMPAIGN_CID_MAPPING: Record<string, string> = {
  // Featured Campaign - Water Wells for Rural Communities
  '0xc747890dcb3918a38b49bb0121ebabc8e7697b365c098bbb3d2f5ca279a247c6': 
    'bafkreidpamji5xyy35kd7nfvqovhf2u2pxvpmyigahw4hfznkd2xgn46ve',
  
  // Add more campaigns as they are created
  // Format: 'campaignId': 'ipfsCID',
};

/**
 * Get IPFS CID for a campaign
 * @param campaignId - The campaign ID (bytes32)
 * @returns The IPFS CID string, or null if not found
 */
export function getCampaignCID(campaignId: string): string | null {
  return CAMPAIGN_CID_MAPPING[campaignId.toLowerCase()] || null;
}

/**
 * Check if a campaign has a known CID
 */
export function hasCampaignCID(campaignId: string): boolean {
  return campaignId.toLowerCase() in CAMPAIGN_CID_MAPPING;
}

/**
 * Add a new campaign CID (useful for dynamic updates)
 */
export function addCampaignCID(campaignId: string, cid: string): void {
  CAMPAIGN_CID_MAPPING[campaignId.toLowerCase()] = cid;
  console.log(`Added CID mapping: ${campaignId} → ${cid}`);
}
