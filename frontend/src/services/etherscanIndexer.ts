/**
 * Etherscan API v2 Event Indexer Service
 * 
 * Fetches CampaignSubmitted events using the unified Etherscan API v2.
 * One API key works across all 60+ supported chains (Ethereum, Base, BSC, Polygon, etc.)
 * 
 * Migration from legacy BaseScan API v1 → Etherscan API v2 (Aug 2025)
 * @see https://docs.etherscan.io/v/etherscan-v2/getting-started/migration-guide
 */

// ============================================================================
// Configuration
// ============================================================================

/** Etherscan API v2 unified endpoint (works for all chains) */
const ETHERSCAN_V2_API_URL = 'https://api.etherscan.io/v2/api';

/** Your Etherscan API key (get from https://etherscan.io/myapikey) */
const ETHERSCAN_API_KEY = import.meta.env.VITE_ETHERSCAN_API_KEY || 'YourApiKeyToken';

/** Base Sepolia testnet chain ID */
const BASE_SEPOLIA_CHAIN_ID = '84532';

/** CampaignRegistry contract address on Base Sepolia */
const CAMPAIGN_REGISTRY_ADDRESS = '0x51929ec1C089463fBeF6148B86F34117D9CCF816';

/** Contract deployment block (start indexing from here) */
const DEPLOYMENT_BLOCK = 32800000; // Adjusted to capture all campaigns

/**
 * CampaignSubmitted event signature (with depositAmount)
 * event CampaignSubmitted(bytes32 indexed id, address indexed proposer, bytes32 metadataHash, string metadataCID, uint256 depositAmount)
 * Topic0 hash: keccak256("CampaignSubmitted(bytes32,address,bytes32,string,uint256)")
 */
const CAMPAIGN_SUBMITTED_TOPIC = '0xec35897c23ef8a8c61114241544e78c2124dfda3a294e6c94088a2b69b3267b4';

// ============================================================================
// Type Definitions
// ============================================================================

interface EtherscanLog {
  address: string;
  topics: string[];
  data: string;
  blockNumber: string;
  timeStamp: string;
  gasPrice: string;
  gasUsed: string;
  logIndex: string;
  transactionHash: string;
  transactionIndex: string;
}

interface CampaignEvent {
  campaignId: string;
  proposer: string;
  metadataHash: string;
  metadataCID: string;
  blockNumber: number;
  timestamp: number;
  txHash: string;
}

// ============================================================================
// Event Parsing
// ============================================================================

/**
 * Decode hex string to UTF-8 (for extracting IPFS CID from event data)
 * Input: hex string WITHOUT 0x prefix
 */
function decodeHexString(hex: string): string {
  const hexWithoutPrefix = hex.startsWith('0x') ? hex.slice(2) : hex;
  const bytes = hexWithoutPrefix.match(/.{1,2}/g) || [];
  return bytes.map(byte => String.fromCharCode(parseInt(byte, 16))).join('');
}

/**
 * Parse CampaignSubmitted event log
 * 
 * Event: CampaignSubmitted(bytes32 indexed id, address indexed proposer, bytes32 metadataHash, string metadataCID, uint256 depositAmount)
 * Topics: [event signature, campaignId (indexed), proposer (indexed)]
 * Data: [metadataHash (32 bytes), string offset (32 bytes), string length (32 bytes), string data (variable), depositAmount (32 bytes)]
 */
function parseCampaignSubmittedLog(log: EtherscanLog): CampaignEvent | null {
  try {
    if (log.topics.length < 3) {
      console.warn('Invalid log format:', log);
      return null;
    }

    const campaignId = log.topics[1];
    const proposer = '0x' + log.topics[2].slice(26); // Remove padding, keep last 20 bytes

    // Data layout for dynamic string with trailing uint256:
    // [0-64]: metadataHash (32 bytes)
    // [64-128]: offset to string (32 bytes) - always 0x40 (64 in decimal)
    // [128-192]: string length (32 bytes)
    // [192+]: string data (variable)
    // [end-64 to end]: depositAmount (32 bytes) - but we don't need to parse it for indexing
    const data = log.data.slice(2); // Remove 0x prefix
    const metadataHashHex = '0x' + data.slice(0, 64);
    
    // Get string length (in bytes, not hex chars)
    const stringLengthBytes = parseInt(data.slice(128, 192), 16);
    const stringLengthHex = stringLengthBytes * 2; // Convert to hex character count
    
    // Extract the string data
    const stringData = data.slice(192, 192 + stringLengthHex);
    
    // Decode hex to UTF-8
    const metadataCID = decodeHexString(stringData);

    console.log('📋 Parsed event:', { 
      campaignId: campaignId.slice(0, 10) + '...', 
      stringLengthBytes,
      stringLengthHex,
      metadataCID 
    });

    return {
      campaignId,
      proposer,
      metadataHash: metadataHashHex,
      metadataCID,
      blockNumber: parseInt(log.blockNumber, 16),
      timestamp: parseInt(log.timeStamp, 16),
      txHash: log.transactionHash,
    };
  } catch (error) {
    console.error('Error parsing log:', error, log);
    return null;
  }
}

// ============================================================================
// Blockchain Queries
// ============================================================================

/**
 * Get latest block number from Etherscan API v2
 */
async function getLatestBlockNumber(): Promise<number> {
  try {
    const url = new URL(ETHERSCAN_V2_API_URL);
    url.searchParams.append('chainid', BASE_SEPOLIA_CHAIN_ID);
    url.searchParams.append('module', 'proxy');
    url.searchParams.append('action', 'eth_blockNumber');
    url.searchParams.append('apikey', ETHERSCAN_API_KEY);

    const response = await fetch(url.toString());
    const data = await response.json();

    if (data.status === '1' && data.result) {
      return parseInt(data.result, 16);
    }

    console.warn('Failed to get latest block, using fallback');
    return DEPLOYMENT_BLOCK + 1000000; // Fallback estimate
  } catch (error) {
    console.error('Error fetching latest block:', error);
    return DEPLOYMENT_BLOCK + 1000000;
  }
}

/**
 * Fetch campaign events from Etherscan API v2
 * 
 * Uses chunked block ranges to avoid timeout issues with large queries.
 * Etherscan v2 supports up to 1000 records per query with pagination.
 * 
 * Rate limits (free tier): 5 calls/second, 100,000 calls/day
 * 
 * @param startBlock Starting block number (default: contract deployment)
 * @param chunkSize Block range per request (default: 10,000 blocks)
 * @returns Array of parsed campaign events
 */
export async function fetchCampaignEvents(
  startBlock: number = DEPLOYMENT_BLOCK,
  chunkSize: number = 10000
): Promise<CampaignEvent[]> {
  const latestBlock = await getLatestBlockNumber();
  const allEvents: CampaignEvent[] = [];
  
  let currentStart = startBlock;
  
  while (currentStart <= latestBlock) {
    const currentEnd = Math.min(currentStart + chunkSize - 1, latestBlock);
    
    try {
      const url = new URL(ETHERSCAN_V2_API_URL);
      url.searchParams.append('chainid', BASE_SEPOLIA_CHAIN_ID);
      url.searchParams.append('module', 'logs');
      url.searchParams.append('action', 'getLogs');
      url.searchParams.append('address', CAMPAIGN_REGISTRY_ADDRESS);
      url.searchParams.append('topic0', CAMPAIGN_SUBMITTED_TOPIC);
      url.searchParams.append('fromBlock', currentStart.toString());
      url.searchParams.append('toBlock', currentEnd.toString());
      url.searchParams.append('page', '1');
      url.searchParams.append('offset', '1000');
      url.searchParams.append('apikey', ETHERSCAN_API_KEY);

      const response = await fetch(url.toString());
      const data = await response.json();

      if (data.status === '1' && Array.isArray(data.result)) {
        const events = data.result
          .map(parseCampaignSubmittedLog)
          .filter((e: CampaignEvent | null): e is CampaignEvent => e !== null);
        
        allEvents.push(...events);
      } else if (data.message?.includes('deprecated V1 endpoint')) {
        console.error('❌ API v1 is deprecated! Please update to v2.');
        throw new Error('Etherscan API v1 deprecated - update required');
      }

      // Rate limiting: 5 calls/sec (free tier) = 200ms between calls
      await new Promise(resolve => setTimeout(resolve, 250));
    } catch (error) {
      console.error(`Error fetching blocks ${currentStart}-${currentEnd}:`, error);
    }

    currentStart = currentEnd + 1;
  }

  return allEvents;
}

// ============================================================================
// Campaign Mapping
// ============================================================================

/**
 * Build complete campaignId → IPFS CID mapping from Etherscan events
 * 
 * @returns Record of campaignId (lowercase) to metadataCID
 */
export async function buildCampaignCIDMapping(): Promise<Record<string, string>> {
  const events = await fetchCampaignEvents();
  
  const mapping: Record<string, string> = {};
  for (const event of events) {
    if (event.metadataCID && event.metadataCID.trim()) {
      mapping[event.campaignId.toLowerCase()] = event.metadataCID;
    }
  }

  return mapping;
}

/**
 * Get IPFS CID for a specific campaign from Etherscan
 * 
 * More efficient than building full mapping - queries only for this campaign's events
 * 
 * @param campaignId Campaign ID (bytes32 hex string)
 * @returns IPFS CID or null if not found
 */
export async function getCampaignCID(campaignId: string): Promise<string | null> {
  try {
    const url = new URL(ETHERSCAN_V2_API_URL);
    url.searchParams.append('chainid', BASE_SEPOLIA_CHAIN_ID);
    url.searchParams.append('module', 'logs');
    url.searchParams.append('action', 'getLogs');
    url.searchParams.append('address', CAMPAIGN_REGISTRY_ADDRESS);
    url.searchParams.append('topic0', CAMPAIGN_SUBMITTED_TOPIC);
    url.searchParams.append('topic1', campaignId); // Filter by specific campaign
    url.searchParams.append('fromBlock', DEPLOYMENT_BLOCK.toString());
    url.searchParams.append('toBlock', 'latest');
    url.searchParams.append('apikey', ETHERSCAN_API_KEY);

    const response = await fetch(url.toString());
    const data = await response.json();

    if (data.status === '1' && Array.isArray(data.result) && data.result.length > 0) {
      const event = parseCampaignSubmittedLog(data.result[0]);
      if (event?.metadataCID) {
        return event.metadataCID;
      }
    }

    return null;
  } catch (error) {
    console.error('❌ Error fetching campaign CID from Etherscan:', error);
    return null;
  }
}

// ============================================================================
// Caching Layer (localStorage)
// ============================================================================

const CACHE_KEY = 'etherscan_campaign_mapping_v2';
const CACHE_DURATION = 60 * 60 * 1000; // 1 hour

/**
 * Get cached campaign mapping from localStorage
 */
export function getCachedCampaignMapping(): Record<string, string> | null {
  try {
    const cached = localStorage.getItem(CACHE_KEY);
    if (!cached) return null;

    const { data, timestamp } = JSON.parse(cached);
    const age = Date.now() - timestamp;

    if (age > CACHE_DURATION) {
      localStorage.removeItem(CACHE_KEY);
      return null;
    }

    return data;
  } catch {
    return null;
  }
}

/**
 * Save campaign mapping to localStorage cache
 */
export function setCachedCampaignMapping(mapping: Record<string, string>): void {
  try {
    localStorage.setItem(CACHE_KEY, JSON.stringify({
      data: mapping,
      timestamp: Date.now(),
    }));
  } catch (error) {
    console.warn('Failed to cache campaign mapping:', error);
  }
}
