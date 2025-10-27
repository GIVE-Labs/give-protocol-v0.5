/**
 * Campaign ID to IPFS CID Mapping
 * 
 * ALL campaigns now automatically fetch from Etherscan API v2! 🎉
 * This file only exists for the featured campaign constant.
 */

// Featured campaign ID (displayed on homepage)
export const FEATURED_CAMPAIGN_ID = '0xa6d48542a36e6c6cad1fe58d597d7d98914ef1a2d8f2bb352d69adbd4fcda9b2';

// Empty mapping - Etherscan API v2 handles everything automatically
export const CAMPAIGN_CID_MAPPING: Record<string, string> = {};

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
