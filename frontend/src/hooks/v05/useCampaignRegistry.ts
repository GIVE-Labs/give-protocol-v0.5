/**
 * Hook for interacting with the Campaign Registry
 * Manages campaign lifecycle: submission, approval, voting, checkpoints
 */

import { useReadContract, useWriteContract, useWaitForTransactionReceipt, useAccount } from 'wagmi';
import { BASE_SEPOLIA_ADDRESSES } from '../../config/baseSepolia';
import CampaignRegistryABI from '../../abis/CampaignRegistry.json';

export function useCampaignRegistry() {
  const { address: connectedAddress } = useAccount();
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  // ===== Read Functions =====

  // Get all campaign IDs
  const { data: campaignIds, refetch: refetchCampaignIds } = useReadContract({
    address: BASE_SEPOLIA_ADDRESSES.CAMPAIGN_REGISTRY as `0x${string}`,
    abi: CampaignRegistryABI,
    functionName: 'listCampaignIds',
  });

  // Get campaign details by ID
  const getCampaign = (campaignId: `0x${string}`) => {
    return useReadContract({
      address: BASE_SEPOLIA_ADDRESSES.CAMPAIGN_REGISTRY as `0x${string}`,
      abi: CampaignRegistryABI,
      functionName: 'getCampaign',
      args: [campaignId],
    });
  };

  // Get all active campaigns (filter by status client-side for now)
  // TODO: Add contract function to filter by status
  const activeCampaigns = campaignIds as `0x${string}`[] | undefined;

  // Get campaign status
  const getCampaignStatus = (campaignId: `0x${string}`) => {
    return useReadContract({
      address: BASE_SEPOLIA_ADDRESSES.CAMPAIGN_REGISTRY as `0x${string}`,
      abi: CampaignRegistryABI,
      functionName: 'getCampaignStatus',
      args: [campaignId],
    });
  };

  // Get checkpoint details
  const getCheckpoint = (campaignId: `0x${string}`, checkpointId: bigint) => {
    return useReadContract({
      address: BASE_SEPOLIA_ADDRESSES.CAMPAIGN_REGISTRY as `0x${string}`,
      abi: CampaignRegistryABI,
      functionName: 'getCheckpoint',
      args: [campaignId, checkpointId],
    });
  };

  // Check if user has voted on checkpoint
  const hasVoted = (campaignId: `0x${string}`, checkpointId: bigint, voter: `0x${string}`) => {
    return useReadContract({
      address: BASE_SEPOLIA_ADDRESSES.CAMPAIGN_REGISTRY as `0x${string}`,
      abi: CampaignRegistryABI,
      functionName: 'hasVoted',
      args: [campaignId, checkpointId, voter],
    });
  };

  // ===== Write Functions =====

  /**
   * Submit a new campaign for approval (v0.5)
   * @param input CampaignInput struct matching contract definition
   */
  const submitCampaign = async (input: {
    id: `0x${string}`;
    payoutRecipient: `0x${string}`;
    strategyId: `0x${string}`;
    metadataHash: `0x${string}`;
    targetStake: bigint;
    minStake: bigint;
    fundraisingStart: bigint;
    fundraisingEnd: bigint;
  }) => {
    if (!connectedAddress) {
      throw new Error('No wallet connected');
    }
    return writeContract({
      address: BASE_SEPOLIA_ADDRESSES.CAMPAIGN_REGISTRY as `0x${string}`,
      abi: CampaignRegistryABI,
      functionName: 'submitCampaign',
      args: [input],
      account: connectedAddress,
    });
  };

  /**
   * Approve a pending campaign (admin only)
   * @param campaignId Campaign ID (bytes32)
   * @param curator Address to set as campaign curator
   */
  const approveCampaign = async (campaignId: `0x${string}`, curator: `0x${string}`) => {
    return writeContract({
      address: BASE_SEPOLIA_ADDRESSES.CAMPAIGN_REGISTRY as `0x${string}`,
      abi: CampaignRegistryABI,
      functionName: 'approveCampaign',
      args: [campaignId, curator],
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

  /**
   * Set campaign status (admin only)
   * @param campaignId Campaign ID
   * @param newStatus Status enum value (0=Unknown, 1=Submitted, 2=Approved, 3=Active, 4=Paused, 5=Completed, 6=Cancelled)
   */
  const setCampaignStatus = async (campaignId: `0x${string}`, newStatus: number) => {
    return writeContract({
      address: BASE_SEPOLIA_ADDRESSES.CAMPAIGN_REGISTRY as `0x${string}`,
      abi: CampaignRegistryABI,
      functionName: 'setCampaignStatus',
      args: [campaignId, newStatus],
    });
  };

  return {
    // Read data
    campaignCount: activeCampaigns ? activeCampaigns.length : 0,
    activeCampaigns,
    campaignIds,
    
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
    setCampaignStatus,
    
    // Transaction state
    isPending,
    isConfirming,
    isSuccess,
    error,
    hash,
    
    // Refetch utilities
    refetchCampaignIds,
  };
}
