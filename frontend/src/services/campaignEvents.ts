/**
 * Campaign Event Log Service
 * Fetches IPFS CIDs from CampaignSubmitted event logs
 */

import { createPublicClient, http, parseAbiItem } from 'viem';
import { baseSepolia } from 'viem/chains';

const CAMPAIGN_REGISTRY_ADDRESS = '0x51929ec1C089463fBeF6148B86F34117D9CCF816' as const;

// Create a public client for reading logs
const publicClient = createPublicClient({
  chain: baseSepolia,
  transport: http(import.meta.env.VITE_BASE_SEPOLIA_RPC_URL),
});

/**
 * Fetch IPFS CID for a campaign from event logs
 * @param campaignId - The campaign ID (bytes32)
 * @returns The IPFS CID string from the event, or null if not found
 */
export async function getCampaignCIDFromLogs(
  campaignId: `0x${string}`
): Promise<string | null> {
  try {
    console.log('Fetching CID from event logs for campaign:', campaignId);

    // Get current block first
    const currentBlock = await publicClient.getBlockNumber();
    
    // Alchemy free tier: limit to last 10,000 blocks to avoid RPC errors
    // For production, use a subgraph indexer or upgrade to paid RPC plan
    const fromBlock = currentBlock > 10000n ? currentBlock - 10000n : 0n;

    // Query CampaignSubmitted events
    const logs = await publicClient.getLogs({
      address: CAMPAIGN_REGISTRY_ADDRESS,
      event: parseAbiItem('event CampaignSubmitted(bytes32 indexed id, address indexed proposer, bytes32 metadataHash, string metadataCID)'),
      args: {
        id: campaignId,
      },
      fromBlock,
      toBlock: 'latest',
    });

    if (logs.length === 0) {
      console.warn('No CampaignSubmitted event found for campaign:', campaignId, '(searched last 10K blocks)');
      return null;
    }

    // Get the most recent event (in case of duplicates)
    const latestLog = logs[logs.length - 1];
    const cid = latestLog.args.metadataCID;

    if (!cid) {
      console.error('Event found but metadataCID is empty');
      return null;
    }

    console.log('Found CID from event logs:', cid);
    return cid;
  } catch (error) {
    console.error('Error fetching CID from event logs:', error);
    return null;
  }
}

/**
 * Build a mapping of all campaign IDs to their CIDs from event logs
 * Useful for indexing/caching all campaigns at once
 */
export async function buildCampaignCIDMapping(): Promise<Record<string, string>> {
  try {
    console.log('Building campaign CID mapping from event logs...');

    // Get current block first
    const currentBlock = await publicClient.getBlockNumber();
    
    // Alchemy free tier: limit to last 10,000 blocks
    const fromBlock = currentBlock > 10000n ? currentBlock - 10000n : 0n;

    const logs = await publicClient.getLogs({
      address: CAMPAIGN_REGISTRY_ADDRESS,
      event: parseAbiItem('event CampaignSubmitted(bytes32 indexed id, address indexed proposer, bytes32 metadataHash, string metadataCID)'),
      fromBlock,
      toBlock: 'latest',
    });

    const mapping: Record<string, string> = {};
    
    for (const log of logs) {
      if (log.args.id && log.args.metadataCID) {
        mapping[log.args.id] = log.args.metadataCID;
      }
    }

    console.log(`Built mapping for ${Object.keys(mapping).length} campaigns (last 10K blocks)`);
    return mapping;
  } catch (error) {
    console.error('Error building campaign CID mapping:', error);
    return {};
  }
}

/**
 * Cache the CID mapping in localStorage for faster subsequent loads
 */
export async function cacheCampaignCIDs(): Promise<void> {
  const mapping = await buildCampaignCIDMapping();
  localStorage.setItem('give_campaign_cids', JSON.stringify(mapping));
  console.log('Campaign CID mapping cached to localStorage');
}
