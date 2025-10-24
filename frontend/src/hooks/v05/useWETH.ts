/**
 * Hook for interacting with WETH (Wrapped ETH)
 * Handles wrapping, unwrapping, approvals, and balance queries
 */

import { useReadContract, useWriteContract, useWaitForTransactionReceipt, useAccount, useBalance } from 'wagmi';
import { formatUnits } from 'viem';
import { BASE_SEPOLIA_ADDRESSES } from '../../config/baseSepolia';
import { erc20Abi } from '../../abis/erc20';

// WETH ABI (minimal interface for deposit/withdraw)
const WETH_ABI = [
  {
    "constant": false,
    "inputs": [],
    "name": "deposit",
    "outputs": [],
    "payable": true,
    "stateMutability": "payable",
    "type": "function"
  },
  {
    "constant": false,
    "inputs": [{ "name": "wad", "type": "uint256" }],
    "name": "withdraw",
    "outputs": [],
    "payable": false,
    "stateMutability": "nonpayable",
    "type": "function"
  },
  ...erc20Abi
] as const;

export function useWETH() {
  const { address: userAddress } = useAccount();
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const WETH_ADDRESS = BASE_SEPOLIA_ADDRESSES.WETH as `0x${string}`;

  // ===== Read Functions =====

  // User's ETH balance (native)
  const { data: ethBalance } = useBalance({
    address: userAddress,
  });

  // User's WETH balance
  const { data: wethBalance, refetch: refetchWethBalance } = useReadContract({
    address: WETH_ADDRESS,
    abi: WETH_ABI,
    functionName: 'balanceOf',
    args: userAddress ? [userAddress] : undefined,
    query: {
      enabled: !!userAddress,
    },
  });

  // WETH allowance for vault
  const getAllowance = (spender: `0x${string}`) => {
    return useReadContract({
      address: WETH_ADDRESS,
      abi: WETH_ABI,
      functionName: 'allowance',
      args: userAddress ? [userAddress, spender] : undefined,
      query: {
        enabled: !!userAddress,
      },
    });
  };

  // Vault allowance specifically
  const { data: vaultAllowance, refetch: refetchVaultAllowance } = useReadContract({
    address: WETH_ADDRESS,
    abi: WETH_ABI,
    functionName: 'allowance',
    args: userAddress ? [userAddress, BASE_SEPOLIA_ADDRESSES.GIVE_WETH_VAULT as `0x${string}`] : undefined,
    query: {
      enabled: !!userAddress,
    },
  });

  // ===== Write Functions =====

  /**
   * Wrap ETH to WETH
   * @param amount Amount of ETH to wrap (in wei)
   */
  const wrap = async (amount: bigint) => {
    return writeContract({
      address: WETH_ADDRESS,
      abi: WETH_ABI,
      functionName: 'deposit',
      value: amount,
    });
  };

  /**
   * Unwrap WETH to ETH
   * @param amount Amount of WETH to unwrap (in wei)
   */
  const unwrap = async (amount: bigint) => {
    return writeContract({
      address: WETH_ADDRESS,
      abi: WETH_ABI,
      functionName: 'withdraw',
      args: [amount],
    });
  };

  /**
   * Approve WETH spending
   * @param spender Address allowed to spend WETH
   * @param amount Amount to approve (in wei)
   */
  const approve = async (spender: `0x${string}`, amount: bigint) => {
    return writeContract({
      address: WETH_ADDRESS,
      abi: WETH_ABI,
      functionName: 'approve',
      args: [spender, amount],
    });
  };

  /**
   * Approve maximum WETH for vault
   */
  const approveVault = async () => {
    const maxAmount = BigInt('0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff');
    return approve(BASE_SEPOLIA_ADDRESSES.GIVE_WETH_VAULT as `0x${string}`, maxAmount);
  };

  /**
   * Check if user has sufficient allowance
   * @param spender Spender address
   * @param amount Required amount
   */
  const hasSufficientAllowance = (spender: `0x${string}`, amount: bigint): boolean => {
    const allowanceData = getAllowance(spender).data;
    if (!allowanceData) return false;
    return (allowanceData as bigint) >= amount;
  };

  return {
    // Contract address
    wethAddress: WETH_ADDRESS,
    
    // Read data (formatted)
    ethBalance: ethBalance ? formatUnits(ethBalance.value, 18) : '0',
    ethBalanceRaw: ethBalance?.value,
    wethBalance: wethBalance ? formatUnits(wethBalance as bigint, 18) : '0',
    wethBalanceRaw: wethBalance as bigint | undefined,
    vaultAllowance: vaultAllowance ? formatUnits(vaultAllowance as bigint, 18) : '0',
    vaultAllowanceRaw: vaultAllowance as bigint | undefined,
    
    // Read functions
    getAllowance,
    hasSufficientAllowance,
    
    // Write functions
    wrap,
    unwrap,
    approve,
    approveVault,
    
    // Transaction state
    isPending,
    isConfirming,
    isSuccess,
    error,
    hash,
    
    // Refetch utilities
    refetchWethBalance,
    refetchVaultAllowance,
  };
}
