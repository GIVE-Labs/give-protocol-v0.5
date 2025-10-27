/**
 * Hook for protocol-wide metrics
 * Calculates TVL, active campaigns, and total supporters
 */

import { useState, useEffect } from 'react'
import { useReadContract, useBlockNumber, useReadContracts } from 'wagmi'
import { formatUnits } from 'viem'
import { BASE_SEPOLIA_ADDRESSES } from '../config/baseSepolia'
import { getEthereumPrice, formatUSDValue } from '../services/coingecko'
import GiveVault4626ABIJson from '../abis/GiveVault4626.json'
import CampaignRegistryABI from '../abis/CampaignRegistry.json'

const GiveVault4626ABI = (GiveVault4626ABIJson as any).abi || GiveVault4626ABIJson

// Campaign Status Enum (from GiveTypes.sol)
const CAMPAIGN_STATUS_APPROVED = 2
const CAMPAIGN_STATUS_ACTIVE = 3

export function useProtocolMetrics() {
  const [tvlUSD, setTvlUSD] = useState<string>('Loading...')
  const [activeCampaignsCount, setActiveCampaignsCount] = useState<number>(0)
  const [totalSupporters, setTotalSupporters] = useState<number>(0)
  const [isLoading, setIsLoading] = useState(true)

  // Get current block number to trigger refresh
  const { data: blockNumber } = useBlockNumber({ watch: true })

  // Fetch vault total assets (WETH)
  const { data: vaultAssets, refetch: refetchVaultAssets } = useReadContract({
    address: BASE_SEPOLIA_ADDRESSES.GIVE_WETH_VAULT as `0x${string}`,
    abi: GiveVault4626ABI,
    functionName: 'totalAssets',
  })

  // Fetch campaign IDs from registry
  const { data: campaignIds, refetch: refetchCampaigns } = useReadContract({
    address: BASE_SEPOLIA_ADDRESSES.CAMPAIGN_REGISTRY as `0x${string}`,
    abi: CampaignRegistryABI,
    functionName: 'listCampaignIds',
  })

  // Prepare contracts for batch status checking
  const campaignIdsArray = (campaignIds as `0x${string}`[] | undefined) || []
  
  // Batch fetch all campaign data using useReadContracts
  const { data: campaignResults } = useReadContracts({
    contracts: campaignIdsArray.map((id) => ({
      address: BASE_SEPOLIA_ADDRESSES.CAMPAIGN_REGISTRY as `0x${string}`,
      abi: CampaignRegistryABI as any,
      functionName: 'getCampaign',
      args: [id],
    })) as any,
  })

  // Calculate TVL in USD
  useEffect(() => {
    const calculateTVL = async () => {
      setIsLoading(true)
      
      try {
        const ethPrice = await getEthereumPrice()
        
        if (!ethPrice) {
          setTvlUSD('$0')
          return
        }

        let totalValueUSD = 0
        
        if (vaultAssets) {
          const wethAmount = parseFloat(formatUnits(vaultAssets as bigint, 18))
          totalValueUSD += wethAmount * ethPrice
        }

        setTvlUSD(formatUSDValue(totalValueUSD))
      } catch (error) {
        console.error('Error calculating TVL:', error)
        setTvlUSD('Error')
      } finally {
        setIsLoading(false)
      }
    }

    calculateTVL()
  }, [vaultAssets, blockNumber])

  // Count active campaigns (Approved or Active status)
  useEffect(() => {
    if (!campaignResults || campaignResults.length === 0) {
      setActiveCampaignsCount(0)
      return
    }

    const activeCount = campaignResults.filter((result) => {
      if (result.status === 'success' && result.result !== undefined) {
        const campaign = result.result as any
        const status = Number(campaign.status)
        return status === CAMPAIGN_STATUS_APPROVED || status === CAMPAIGN_STATUS_ACTIVE
      }
      return false
    }).length

    setActiveCampaignsCount(activeCount)
  }, [campaignResults])

  // Supporter counting disabled due to Alchemy free tier limitations
  // eth_getLogs with large block ranges (even 10 blocks) exceeds free tier limits
  // For production: use subgraph indexer or upgrade to Alchemy Growth plan
  useEffect(() => {
    setTotalSupporters(0) // Disabled - would need paid RPC or indexer
  }, [])

  // Refetch data periodically
  useEffect(() => {
    const interval = setInterval(() => {
      refetchVaultAssets()
      refetchCampaigns()
    }, 30000) // Refresh every 30 seconds

    return () => clearInterval(interval)
  }, [refetchVaultAssets, refetchCampaigns])

  return {
    tvlUSD,
    activeCampaignsCount,
    totalSupporters,
    isLoading,
  }
}
