/**
 * Hook for interacting with the GIVE WETH Vault (GiveVault4626)
 * Supports deposit, withdrawal, and harvest operations
 */

import { useReadContract, useWriteContract, useWaitForTransactionReceipt, useAccount } from 'wagmi';
import { formatUnits, parseUnits } from 'viem';
import { BASE_SEPOLIA_ADDRESSES } from '../../config/baseSepolia';
import GiveVault4626ABI from '../../abis/GiveVault4626.json';

export function useGiveVault(vaultAddress?: `0x${string}`) {
  const { address: userAddress } = useAccount();
  const address = vaultAddress || (BASE_SEPOLIA_ADDRESSES.GIVE_WETH_VAULT as `0x${string}`);
  
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  // ===== Read Functions =====

  // Vault statistics
  const { data: totalAssets, refetch: refetchTotalAssets } = useReadContract({
    address,
    abi: GiveVault4626ABI,
    functionName: 'totalAssets',
  });

  const { data: totalSupply, refetch: refetchTotalSupply } = useReadContract({
    address,
    abi: GiveVault4626ABI,
    functionName: 'totalSupply',
  });

  // Calculate share price (assets per share)
  const { data: sharePrice } = useReadContract({
    address,
    abi: GiveVault4626ABI,
    functionName: 'convertToAssets',
    args: [parseUnits('1', 18)], // 1 share in wei
  });

  // User balance
  const { data: userBalance, refetch: refetchUserBalance } = useReadContract({
    address,
    abi: GiveVault4626ABI,
    functionName: 'balanceOf',
    args: userAddress ? [userAddress] : undefined,
    query: {
      enabled: !!userAddress,
    },
  });

  // Adapter stats
  const { data: adapterAssets } = useReadContract({
    address,
    abi: GiveVault4626ABI,
    functionName: 'getAdapterAssets',
  });

  const { data: cashBalance } = useReadContract({
    address,
    abi: GiveVault4626ABI,
    functionName: 'getCashBalance',
  });

  // Active adapter address
  const { data: activeAdapter } = useReadContract({
    address,
    abi: GiveVault4626ABI,
    functionName: 'activeAdapter',
  });

  // Harvest stats (profit/loss)
  const { data: harvestStats } = useReadContract({
    address,
    abi: GiveVault4626ABI,
    functionName: 'getHarvestStats',
  });

  // Vault configuration
  const { data: configuration } = useReadContract({
    address,
    abi: GiveVault4626ABI,
    functionName: 'getConfiguration',
  });

  // Preview deposit (how many shares will be minted)
  const previewDeposit = (assets: bigint) => {
    return useReadContract({
      address,
      abi: GiveVault4626ABI,
      functionName: 'previewDeposit',
      args: [assets],
    });
  };

  // Preview withdraw (how many assets will be received)
  const previewWithdraw = (shares: bigint) => {
    return useReadContract({
      address,
      abi: GiveVault4626ABI,
      functionName: 'previewRedeem',
      args: [shares],
    });
  };

  // ===== Write Functions =====

  /**
   * Deposit WETH into the vault
   * @param assets Amount of WETH to deposit (in wei)
   * @param receiver Address to receive vault shares
   */
  const deposit = async (assets: bigint, receiver: `0x${string}`) => {
    return writeContract({
      address,
      abi: GiveVault4626ABI,
      functionName: 'deposit',
      args: [assets, receiver],
    });
  };

  /**
   * Withdraw WETH from the vault
   * @param assets Amount of WETH to withdraw (in wei)
   * @param receiver Address to receive WETH
   * @param owner Address of share owner (typically msg.sender)
   */
  const withdraw = async (assets: bigint, receiver: `0x${string}`, owner: `0x${string}`) => {
    return writeContract({
      address,
      abi: GiveVault4626ABI,
      functionName: 'withdraw',
      args: [assets, receiver, owner],
    });
  };

  /**
   * Redeem vault shares for WETH
   * @param shares Amount of shares to burn (in wei)
   * @param receiver Address to receive WETH
   * @param owner Address of share owner
   */
  const redeem = async (shares: bigint, receiver: `0x${string}`, owner: `0x${string}`) => {
    return writeContract({
      address,
      abi: GiveVault4626ABI,
      functionName: 'redeem',
      args: [shares, receiver, owner],
    });
  };

  /**
   * Trigger harvest to collect yield from adapter
   * Only callable by users with harvest role
   */
  const harvest = async () => {
    return writeContract({
      address,
      abi: GiveVault4626ABI,
      functionName: 'harvest',
    });
  };

  // ===== Helper Functions =====

  const refetchAll = () => {
    refetchTotalAssets();
    refetchTotalSupply();
    refetchUserBalance();
  };

  return {
    // Contract address
    vaultAddress: address,
    
    // Read data (formatted for display)
    totalAssets: totalAssets ? formatUnits(totalAssets as bigint, 18) : '0',
    totalAssetsRaw: totalAssets as bigint | undefined,
    totalSupply: totalSupply ? formatUnits(totalSupply as bigint, 18) : '0',
    totalSupplyRaw: totalSupply as bigint | undefined,
    sharePrice: sharePrice ? formatUnits(sharePrice as bigint, 18) : '1.0',
    sharePriceRaw: sharePrice as bigint | undefined,
    userBalance: userBalance ? formatUnits(userBalance as bigint, 18) : '0',
    userBalanceRaw: userBalance as bigint | undefined,
    adapterAssets: adapterAssets ? formatUnits(adapterAssets as bigint, 18) : '0',
    adapterAssetsRaw: adapterAssets as bigint | undefined,
    cashBalance: cashBalance ? formatUnits(cashBalance as bigint, 18) : '0',
    cashBalanceRaw: cashBalance as bigint | undefined,
    activeAdapter: activeAdapter as `0x${string}` | undefined,
    harvestStats,
    configuration,
    
    // Preview functions
    previewDeposit,
    previewWithdraw,
    
    // Write functions
    deposit,
    withdraw,
    redeem,
    harvest,
    
    // Transaction state
    isPending,
    isConfirming,
    isSuccess,
    error,
    hash,
    
    // Utilities
    refetchAll,
  };
}
