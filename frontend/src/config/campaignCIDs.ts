/**
 * Campaign ID to IPFS CID Mapping
 * 
 * This is a temporary workaround for Alchemy free tier limitations.
 * The proper long-term solution is to use The Graph subgraph to index CampaignSubmitted events.
 * 
 * To add a new campaign:
 * 1. Find the CampaignSubmitted event transaction on BaseScan
 * 2. Decode the event data to extract the metadataCID string parameter
 * 3. Add the campaignId → CID mapping below
 */

export const CAMPAIGN_CID_MAPPING: Record<string, string> = {
  // Campaign 0xc747... - Climate Action Initiative
  '0xc747890dcb3918a38b49bb0121ebabc8e7697b365c098bbb3d2f5ca279a247c6': 
    'bafkreicgigl3bn22abvbz3byc2o4vwnrdinzvnwsekqsxs6ttyobzjdghm',
  
  // Add more campaigns here as they are created
  // Format: 'campaignId': 'ipfsCID',
};

/**
 * Get IPFS CID for a campaign
 */
export function getCampaignCID(campaignId: string): string | null {
  return CAMPAIGN_CID_MAPPING[campaignId.toLowerCase()] || null
}

/**
 * Check if a campaign has a known CID
 */
export function hasCampaignCID(campaignId: string): boolean {
  return campaignId.toLowerCase() in CAMPAIGN_CID_MAPPING
}

/**
 * Add a new campaign CID dynamically
 */
export function addCampaignCID(campaignId: string, cid: string): void {
  CAMPAIGN_CID_MAPPING[campaignId.toLowerCase()] = cid
}
