/**
 * Hook for interacting with the Payout Router
 * Manages payout preferences and yield distribution
 */

import { useReadContract, useWriteContract, useWaitForTransactionReceipt, useAccount } from 'wagmi';
import { BASE_SEPOLIA_ADDRESSES } from '../../config/baseSepolia';
import PayoutRouterABI from '../../abis/PayoutRouter.json';

export function usePayoutRouter(address?: `0x${string}`) {
  const { address: userAddress } = useAccount();
  const addr = address || userAddress;
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  // ===== Read Functions =====

  // Protocol fee in basis points (10000 = 100%)
  const { data: protocolFeeBps } = useReadContract({
    address: BASE_SEPOLIA_ADDRESSES.PAYOUT_ROUTER as `0x${string}`,
    abi: PayoutRouterABI,
    functionName: 'protocolFeeBps',
  });

  // Fee recipient address
  const { data: feeRecipient } = useReadContract({
    address: BASE_SEPOLIA_ADDRESSES.PAYOUT_ROUTER as `0x${string}`,
    abi: PayoutRouterABI,
    functionName: 'feeRecipient',
  });

  // Get user's payout preference for a specific vault
  const getPreference = (vaultId: bigint, address?: `0x${string}`) => {
    const addr = address || userAddress;
    return useReadContract({
      address: BASE_SEPOLIA_ADDRESSES.PAYOUT_ROUTER as `0x${string}`,
      abi: PayoutRouterABI,
      functionName: 'payoutPreferences',
      args: addr ? [vaultId, addr] : undefined,
      query: {
        enabled: !!addr,
      },
    });
  };

  // Get user's current payout preference (for default vault)
  const { data: userPreference, refetch: refetchUserPreference } = useReadContract({
    address: BASE_SEPOLIA_ADDRESSES.PAYOUT_ROUTER as `0x${string}`,
    abi: PayoutRouterABI,
    functionName: 'payoutPreferences',
    args: addr ? [BigInt(1), addr] : undefined, // vaultId = 1 (GIVE WETH Vault)
    query: {
      enabled: !!addr,
    },
  });

  // Get total payouts sent to a campaign
  const getCampaignPayouts = (campaignId: bigint) => {
    return useReadContract({
      address: BASE_SEPOLIA_ADDRESSES.PAYOUT_ROUTER as `0x${string}`,
      abi: PayoutRouterABI,
      functionName: 'campaignPayouts',
      args: [campaignId],
    });
  };

  // Get user's total share balance across all vaults
  const getUserShares = (address?: `0x${string}`) => {
    const addr = address || userAddress;
    return useReadContract({
      address: BASE_SEPOLIA_ADDRESSES.PAYOUT_ROUTER as `0x${string}`,
      abi: PayoutRouterABI,
      functionName: 'userShares',
      args: addr ? [addr] : undefined,
      query: {
        enabled: !!addr,
      },
    });
  };

  // ===== Write Functions =====

  /**
   * Set payout preference for a vault
   * @param vaultId Vault ID (1 = GIVE WETH Vault)
   * @param campaignId Campaign to receive yield
   * @param beneficiary Address to receive beneficiary portion
   * @param allocationBps Percentage to campaign (0-10000, where 10000 = 100%)
   */
  const setPreference = async (
    vaultId: bigint,
    campaignId: bigint,
    beneficiary: `0x${string}`,
    allocationBps: number
  ) => {
    return writeContract({
      address: BASE_SEPOLIA_ADDRESSES.PAYOUT_ROUTER as `0x${string}`,
      abi: PayoutRouterABI,
      functionName: 'setPayoutPreference',
      args: [vaultId, campaignId, beneficiary, BigInt(allocationBps)],
    });
  };

  /**
   * Set default allocation (50/75/100% to campaign)
   * @param vaultId Vault ID
   * @param campaignId Campaign ID
   * @param allocationPercent 50, 75, or 100
   */
  const setDefaultAllocation = async (
    vaultId: bigint,
    campaignId: bigint,
    allocationPercent: 50 | 75 | 100
  ) => {
    const allocationBps = allocationPercent * 100; // Convert to basis points
    const beneficiary = userAddress || '0x0000000000000000000000000000000000000000';
    
    return setPreference(vaultId, campaignId, beneficiary as `0x${string}`, allocationBps);
  };

  /**
   * Clear payout preference (stop donating to campaign)
   * @param vaultId Vault ID
   */
  const clearPreference = async (vaultId: bigint) => {
    return writeContract({
      address: BASE_SEPOLIA_ADDRESSES.PAYOUT_ROUTER as `0x${string}`,
      abi: PayoutRouterABI,
      functionName: 'setPayoutPreference',
      args: [vaultId, BigInt(0), '0x0000000000000000000000000000000000000000', BigInt(0)],
    });
  };

  /**
   * Execute payout distribution (admin/keeper only)
   * @param vaultId Vault ID
   * @param totalYield Total yield to distribute
   */
  const executePayout = async (vaultId: bigint, totalYield: bigint) => {
    return writeContract({
      address: BASE_SEPOLIA_ADDRESSES.PAYOUT_ROUTER as `0x${string}`,
      abi: PayoutRouterABI,
      functionName: 'executePayout',
      args: [vaultId, totalYield],
    });
  };

  return {
    // Read data
    protocolFeeBps: protocolFeeBps ? Number(protocolFeeBps) : 0,
    protocolFeePercent: protocolFeeBps ? Number(protocolFeeBps) / 100 : 0, // Convert to percentage
    feeRecipient: feeRecipient as `0x${string}` | undefined,
    userPreference: userPreference as { campaignId: bigint; beneficiary: `0x${string}`; allocationBps: bigint } | undefined,
    
    // Read functions (parameterized)
    getPreference,
    getCampaignPayouts,
    getUserShares,
    
    // Write functions
    setPreference,
    setDefaultAllocation,
    clearPreference,
    executePayout,
    
    // Transaction state
    isPending,
    isConfirming,
    isSuccess,
    error,
    hash,
    
    // Refetch utilities
    refetchUserPreference,
  };
}
