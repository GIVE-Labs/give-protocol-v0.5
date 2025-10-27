import { useEffect, useState } from 'react';
import {
  buildCampaignCIDMapping,
  getCachedCampaignMapping,
  setCachedCampaignMapping,
} from '../services/etherscanIndexer';

/**
 * Pre-load all campaign CIDs on app mount using Etherscan API v2
 * 
 * This hook builds a complete index of campaignId → IPFS CID mappings
 * by fetching CampaignSubmitted events from the blockchain.
 * 
 * Flow:
 * 1. Check localStorage cache (1-hour TTL)
 * 2. If cache miss, fetch from Etherscan API v2
 * 3. Cache result in localStorage
 * 
 * @returns Campaign indexing state
 */
export function useCampaignIndex() {
  const [isIndexing, setIsIndexing] = useState(false);
  const [campaignCount, setCampaignCount] = useState(0);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    async function indexCampaigns() {
      setIsIndexing(true);
      setError(null);

      try {
        // Try cache first
        const cached = getCachedCampaignMapping();
        if (cached) {
          setCampaignCount(Object.keys(cached).length);
          console.log(`✓ Loaded ${Object.keys(cached).length} campaigns from cache`);
          setIsIndexing(false);
          return;
        }

        // Cache miss - fetch from Etherscan
        console.log('Cache miss - indexing campaigns from Etherscan API v2...');
        const mapping = await buildCampaignCIDMapping();
        setCampaignCount(Object.keys(mapping).length);
        setCachedCampaignMapping(mapping);
        
        console.log(`✓ Indexed ${Object.keys(mapping).length} campaigns and cached result`);
      } catch (err) {
        const message = err instanceof Error ? err.message : 'Failed to index campaigns';
        setError(message);
        console.error('Campaign indexing error:', err);
      } finally {
        setIsIndexing(false);
      }
    }

    indexCampaigns();
  }, []);

  return { isIndexing, campaignCount, error };
}
