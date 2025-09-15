import { useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { parseUnits, formatUnits } from 'viem';
import { CONTRACT_ADDRESSES } from '../config/contracts';
import { GiveVault4626ABI } from '../abis/GiveVault4626';
import { DonationRouterABI } from '../abis/DonationRouter';
import { StrategyManagerABI } from '../abis/StrategyManager';
import { NGO_REGISTRY_ABI } from '../abis/NGORegistry';
import { erc20Abi } from '../abis/erc20';

// Hook for Vault operations
export function useVault() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess: isConfirmed } = useWaitForTransactionReceipt({ hash });

  // Read functions
  const { data: totalAssets } = useReadContract({
    address: CONTRACT_ADDRESSES.VAULT as `0x${string}`,
    abi: GiveVault4626ABI,
    functionName: 'totalAssets',
  });

  const { data: cashBalance } = useReadContract({
    address: CONTRACT_ADDRESSES.VAULT as `0x${string}`,
    abi: GiveVault4626ABI,
    functionName: 'getCashBalance',
  });

  const { data: adapterAssets } = useReadContract({
    address: CONTRACT_ADDRESSES.VAULT as `0x${string}`,
    abi: GiveVault4626ABI,
    functionName: 'getAdapterAssets',
  });

  const { data: harvestStats } = useReadContract({
    address: CONTRACT_ADDRESSES.VAULT as `0x${string}`,
    abi: GiveVault4626ABI,
    functionName: 'getHarvestStats',
  });

  const { data: activeAdapter } = useReadContract({
    address: CONTRACT_ADDRESSES.VAULT as `0x${string}`,
    abi: GiveVault4626ABI,
    functionName: 'activeAdapter',
  });

  const { data: configuration } = useReadContract({
    address: CONTRACT_ADDRESSES.VAULT as `0x${string}`,
    abi: GiveVault4626ABI,
    functionName: 'getConfiguration',
  });

  // Write functions
  const deposit = (assets: string, receiver: `0x${string}`) => {
    const amount = parseUnits(assets, 6); // Assuming USDC (6 decimals)
    writeContract({
      address: CONTRACT_ADDRESSES.VAULT as `0x${string}`,
      abi: GiveVault4626ABI,
      functionName: 'deposit',
      args: [amount, receiver],
    });
  };

  const withdraw = (assets: string, receiver: `0x${string}`, owner: `0x${string}`) => {
    const amount = parseUnits(assets, 6);
    writeContract({
      address: CONTRACT_ADDRESSES.VAULT as `0x${string}`,
      abi: GiveVault4626ABI,
      functionName: 'withdraw',
      args: [amount, receiver, owner],
    });
  };

  const harvest = () => {
    writeContract({
      address: CONTRACT_ADDRESSES.VAULT as `0x${string}`,
      abi: GiveVault4626ABI,
      functionName: 'harvest',
    });
  };

  return {
    // Read data
    totalAssets: totalAssets ? formatUnits(totalAssets, 6) : '0',
    cashBalance: cashBalance ? formatUnits(cashBalance, 6) : '0',
    adapterAssets: adapterAssets ? formatUnits(adapterAssets, 6) : '0',
    harvestStats,
    configuration,
    activeAdapter,
    // Write functions
    deposit,
    withdraw,
    harvest,
    // Transaction state
    isPending,
    isConfirming,
    isConfirmed,
    error,
    hash,
  };
}

// Hook for Donation Router operations
export function useDonationRouter() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess: isConfirmed } = useWaitForTransactionReceipt({ hash });

  // Read functions
  const { data: feeBps } = useReadContract({
    address: CONTRACT_ADDRESSES.DONATION_ROUTER as `0x${string}`,
    abi: DonationRouterABI,
    functionName: 'feeBps',
  });

  const { data: feeRecipient } = useReadContract({
    address: CONTRACT_ADDRESSES.DONATION_ROUTER as `0x${string}`,
    abi: DonationRouterABI,
    functionName: 'feeRecipient',
  });

  const { data: donationStats } = useReadContract({
    address: CONTRACT_ADDRESSES.DONATION_ROUTER as `0x${string}`,
    abi: DonationRouterABI,
    functionName: 'getDonationStats',
  });

  // Write functions
  const donate = (ngoId: number, token: string, amount: string) => {
    writeContract({
      address: CONTRACT_ADDRESSES.DONATION_ROUTER as `0x${string}`,
      abi: DonationRouterABI,
      functionName: 'donate',
      args: [BigInt(ngoId), token as `0x${string}`, parseUnits(amount, 6)],
    });
  };

  return {
    // Read data
    feeBps,
    feeRecipient,
    donationStats,
    // Write functions
    donate,
    // Transaction state
    isPending,
    isConfirming,
    isConfirmed,
    error,
    hash,
  };
}

// Hook for Strategy Manager operations
export function useStrategyManager() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess: isConfirmed } = useWaitForTransactionReceipt({ hash });

  // Read functions
  const { data: allStrategies } = useReadContract({
    address: CONTRACT_ADDRESSES.STRATEGY_MANAGER as `0x${string}`,
    abi: StrategyManagerABI,
    functionName: 'getAllStrategies',
  });

  const { data: strategyInfo } = useReadContract({
    address: CONTRACT_ADDRESSES.STRATEGY_MANAGER as `0x${string}`,
    abi: StrategyManagerABI,
    functionName: 'getStrategyInfo',
    args: [CONTRACT_ADDRESSES.STRATEGY_MANAGER as `0x${string}`],
  });

  // Write functions
  const harvestAll = () => {
    writeContract({
      address: CONTRACT_ADDRESSES.STRATEGY_MANAGER as `0x${string}`,
      abi: StrategyManagerABI,
      functionName: 'harvestAll',
    });
  };

  return {
    // Read data
    allStrategies,
    strategyInfo,
    // Write functions
    harvestAll,
    // Transaction state
    isPending,
    isConfirming,
    isConfirmed,
    error,
    hash,
  };
}

// Hook for NGO Registry operations
export function useNGORegistry() {
  const { data: allNGOs } = useReadContract({
    address: CONTRACT_ADDRESSES.NGO_REGISTRY as `0x${string}`,
    abi: NGO_REGISTRY_ABI,
    functionName: 'getApprovedNGOs',
  });

  const { data: verifiedNGOs } = useReadContract({
    address: CONTRACT_ADDRESSES.NGO_REGISTRY as `0x${string}`,
    abi: NGO_REGISTRY_ABI,
    functionName: 'getApprovedNGOs',
  });

  return {
    allNGOs,
    verifiedNGOs,
  };
}

// Hook for ERC20 token operations (USDC)
export function useUSDC() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess: isConfirmed } = useWaitForTransactionReceipt({ hash });

  const { data: balance } = useReadContract({
    address: CONTRACT_ADDRESSES.TOKENS.USDC as `0x${string}`,
    abi: erc20Abi,
    functionName: 'balanceOf',
    args: ['0x0000000000000000000000000000000000000000'], // Will be replaced with actual user address
  });

  const { data: allowance } = useReadContract({
    address: CONTRACT_ADDRESSES.TOKENS.USDC as `0x${string}`,
    abi: erc20Abi,
    functionName: 'allowance',
    args: [
      '0x0000000000000000000000000000000000000000', // owner - will be replaced with actual user address
      CONTRACT_ADDRESSES.VAULT as `0x${string}`, // spender
    ],
  });

  const approve = (amount: string) => {
    const amountBigInt = parseUnits(amount, 6);
    writeContract({
      address: CONTRACT_ADDRESSES.TOKENS.USDC as `0x${string}`,
      abi: erc20Abi,
      functionName: 'approve',
      args: [CONTRACT_ADDRESSES.VAULT as `0x${string}`, amountBigInt],
    });
  };

  return {
    balance: balance ? formatUnits(balance, 6) : '0',
    allowance: allowance ? formatUnits(allowance, 6) : '0',
    approve,
    isPending,
    isConfirming,
    isConfirmed,
    error,
    hash,
  };
}
