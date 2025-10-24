/**
 * Hook for interacting with the Campaign Registry
 * Manages campaign lifecycle: submission, approval, voting, checkpoints
 */

import { useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { BASE_SEPOLIA_ADDRESSES } from '../../config/baseSepolia';
import CampaignRegistryABI from '../../abis/CampaignRegistry.json';

export function useCampaignRegistry() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  // ===== Read Functions =====

  // Get total number of campaigns
  const { data: campaignCount, refetch: refetchCampaignCount } = useReadContract({
    address: BASE_SEPOLIA_ADDRESSES.CAMPAIGN_REGISTRY as `0x${string}`,
    abi: CampaignRegistryABI,
    functionName: 'getCampaignCount',
  });

  // Get campaign details by ID
  const getCampaign = (campaignId: bigint) => {
    return useReadContract({
      address: BASE_SEPOLIA_ADDRESSES.CAMPAIGN_REGISTRY as `0x${string}`,
      abi: CampaignRegistryABI,
      functionName: 'campaigns',
      args: [campaignId],
    });
  };

  // Get all active campaigns
  const { data: activeCampaigns, refetch: refetchActiveCampaigns } = useReadContract({
    address: BASE_SEPOLIA_ADDRESSES.CAMPAIGN_REGISTRY as `0x${string}`,
    abi: CampaignRegistryABI,
    functionName: 'getActiveCampaigns',
  });

  // Get pending campaigns (awaiting approval)
  const { data: pendingCampaigns } = useReadContract({
    address: BASE_SEPOLIA_ADDRESSES.CAMPAIGN_REGISTRY as `0x${string}`,
    abi: CampaignRegistryABI,
    functionName: 'getPendingCampaigns',
  });

  // Get campaign status
  const getCampaignStatus = (campaignId: bigint) => {
    return useReadContract({
      address: BASE_SEPOLIA_ADDRESSES.CAMPAIGN_REGISTRY as `0x${string}`,
      abi: CampaignRegistryABI,
      functionName: 'getCampaignStatus',
      args: [campaignId],
    });
  };

  // Get checkpoint details
  const getCheckpoint = (campaignId: bigint, checkpointId: bigint) => {
    return useReadContract({
      address: BASE_SEPOLIA_ADDRESSES.CAMPAIGN_REGISTRY as `0x${string}`,
      abi: CampaignRegistryABI,
      functionName: 'checkpoints',
      args: [campaignId, checkpointId],
    });
  };

  // Check if user has voted on checkpoint
  const hasVoted = (campaignId: bigint, checkpointId: bigint, voter: `0x${string}`) => {
    return useReadContract({
      address: BASE_SEPOLIA_ADDRESSES.CAMPAIGN_REGISTRY as `0x${string}`,
      abi: CampaignRegistryABI,
      functionName: 'hasVoted',
      args: [campaignId, checkpointId, voter],
    });
  };

  // ===== Write Functions =====

  /**
   * Submit a new campaign for approval
   * @param name Campaign name
   * @param metadataCid IPFS CID for campaign metadata
   * @param recipient Address to receive campaign funds
   * @param strategyId Strategy ID from StrategyRegistry
   */
  const submitCampaign = async (
    name: string,
    metadataCid: string,
    recipient: `0x${string}`,
    strategyId: bigint
  ) => {
    return writeContract({
      address: BASE_SEPOLIA_ADDRESSES.CAMPAIGN_REGISTRY as `0x${string}`,
      abi: CampaignRegistryABI,
      functionName: 'submitCampaign',
      args: [name, metadataCid, recipient, strategyId],
    });
  };

  /**
   * Approve a pending campaign (admin only)
   * @param campaignId Campaign ID to approve
   */
  const approveCampaign = async (campaignId: bigint) => {
    return writeContract({
      address: BASE_SEPOLIA_ADDRESSES.CAMPAIGN_REGISTRY as `0x${string}`,
      abi: CampaignRegistryABI,
      functionName: 'approveCampaign',
      args: [campaignId],
    });
  };

  /**
   * Schedule a checkpoint for voting
   * @param campaignId Campaign ID
   * @param metadataCid IPFS CID for checkpoint details
   * @param votingPeriod Duration of voting period (seconds)
   */
  const scheduleCheckpoint = async (
    campaignId: bigint,
    metadataCid: string,
    votingPeriod: bigint
  ) => {
    return writeContract({
      address: BASE_SEPOLIA_ADDRESSES.CAMPAIGN_REGISTRY as `0x${string}`,
      abi: CampaignRegistryABI,
      functionName: 'scheduleCheckpoint',
      args: [campaignId, metadataCid, votingPeriod],
    });
  };

  /**
   * Vote on a checkpoint
   * @param campaignId Campaign ID
   * @param checkpointId Checkpoint ID
   * @param support true = approve, false = reject
   */
  const voteOnCheckpoint = async (
    campaignId: bigint,
    checkpointId: bigint,
    support: boolean
  ) => {
    return writeContract({
      address: BASE_SEPOLIA_ADDRESSES.CAMPAIGN_REGISTRY as `0x${string}`,
      abi: CampaignRegistryABI,
      functionName: 'voteOnCheckpoint',
      args: [campaignId, checkpointId, support],
    });
  };

  /**
   * Finalize checkpoint after voting period ends
   * @param campaignId Campaign ID
   * @param checkpointId Checkpoint ID
   */
  const finalizeCheckpoint = async (campaignId: bigint, checkpointId: bigint) => {
    return writeContract({
      address: BASE_SEPOLIA_ADDRESSES.CAMPAIGN_REGISTRY as `0x${string}`,
      abi: CampaignRegistryABI,
      functionName: 'finalizeCheckpoint',
      args: [campaignId, checkpointId],
    });
  };

  /**
   * Pause a campaign (admin only)
   * @param campaignId Campaign ID
   */
  const pauseCampaign = async (campaignId: bigint) => {
    return writeContract({
      address: BASE_SEPOLIA_ADDRESSES.CAMPAIGN_REGISTRY as `0x${string}`,
      abi: CampaignRegistryABI,
      functionName: 'pauseCampaign',
      args: [campaignId],
    });
  };

  /**
   * Resume a paused campaign (admin only)
   * @param campaignId Campaign ID
   */
  const resumeCampaign = async (campaignId: bigint) => {
    return writeContract({
      address: BASE_SEPOLIA_ADDRESSES.CAMPAIGN_REGISTRY as `0x${string}`,
      abi: CampaignRegistryABI,
      functionName: 'resumeCampaign',
      args: [campaignId],
    });
  };

  return {
    // Read data
    campaignCount: campaignCount ? Number(campaignCount) : 0,
    activeCampaigns: activeCampaigns as bigint[] | undefined,
    pendingCampaigns: pendingCampaigns as bigint[] | undefined,
    
    // Read functions (parameterized)
    getCampaign,
    getCampaignStatus,
    getCheckpoint,
    hasVoted,
    
    // Write functions
    submitCampaign,
    approveCampaign,
    scheduleCheckpoint,
    voteOnCheckpoint,
    finalizeCheckpoint,
    pauseCampaign,
    resumeCampaign,
    
    // Transaction state
    isPending,
    isConfirming,
    isSuccess,
    error,
    hash,
    
    // Refetch utilities
    refetchCampaignCount,
    refetchActiveCampaigns,
  };
}
