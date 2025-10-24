# GIVE Protocol v0.5 - Frontend Integration Guide

**Version:** 0.5.0  
**Date:** October 24, 2025  
**Stack:** Wagmi v2 + Viem + RainbowKit + Next.js 14  
**Status:** Phase 16 Complete - Ready for Testnet Integration ✅

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Architecture Overview](#architecture-overview)
3. [Contract Addresses](#contract-addresses)
4. [Core Integrations](#core-integrations)
5. [Campaign Management](#campaign-management)
6. [User Flows](#user-flows)
7. [Event Listening](#event-listening)
8. [Error Handling](#error-handling)
9. [Best Practices](#best-practices)
10. [Example Code](#example-code)

---

## Quick Start

### Installation

```bash
npm install wagmi viem @rainbow-me/rainbowkit
# or
pnpm add wagmi viem @rainbow-me/rainbowkit
# or
yarn add wagmi viem @rainbow-me/rainbowkit
```

### Basic Setup

```typescript
// app/providers.tsx
'use client'

import '@rainbow-me/rainbowkit/styles.css'
import { RainbowKitProvider, getDefaultConfig } from '@rainbow-me/rainbowkit'
import { WagmiProvider } from 'wagmi'
import { sepolia, baseSepolia, scrollSepolia } from 'wagmi/chains'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'

const config = getDefaultConfig({
  appName: 'GIVE Protocol',
  projectId: 'YOUR_WALLETCONNECT_PROJECT_ID',
  chains: [sepolia, baseSepolia, scrollSepolia],
})

const queryClient = new QueryClient()

export function Providers({ children }: { children: React.Node }) {
  return (
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>
        <RainbowKitProvider>
          {children}
        </RainbowKitProvider>
      </QueryClientProvider>
    </WagmiProvider>
  )
}
```

---

## Architecture Overview

### Contract Structure

```
GiveProtocolCore (Orchestrator)
├── ACLManager (Access Control)
├── CampaignRegistry (Campaign Lifecycle)
├── StrategyRegistry (Strategy Metadata)
├── PayoutRouter (Yield Distribution)
├── CampaignVaultFactory (Vault Deployment)
└── Adapters (Yield Generation)
    ├── MockYieldAdapter (Testing)
    ├── AaveAdapter (Real yield)
    └── CompoundAdapter (Future)
```

### Key Concepts

1. **Vaults** - ERC4626 vaults that hold user deposits
2. **Campaigns** - Social impact initiatives receiving yield
3. **Strategies** - Risk/reward profiles with adapter bindings
4. **Adapters** - Yield generation protocols (Aave, Compound, etc.)
5. **Payouts** - Automated yield distribution to campaigns

---

## Contract Addresses

### Testnet (Sepolia)

```typescript
// src/config/addresses.ts
export const CONTRACTS = {
  // Core Protocol
  core: '0x...',
  aclManager: '0x...',
  
  // Registries
  campaignRegistry: '0x...',
  strategyRegistry: '0x...',
  
  // Payout & Factory
  payoutRouter: '0x...',
  vaultFactory: '0x...',
  
  // Assets
  usdc: '0x...',
  dai: '0x...',
} as const

export type ContractAddresses = typeof CONTRACTS
```

**Note:** Update these with actual deployed addresses from `script/Bootstrap.s.sol` output.

---

## Core Integrations

### 1. Reading Vault Data

```typescript
// hooks/useVaultData.ts
import { useReadContract } from 'wagmi'
import { formatUnits } from 'viem'
import { VAULT_ABI } from '@/abis/GiveVault4626'

export function useVaultData(vaultAddress: `0x${string}`) {
  // Total assets in vault
  const { data: totalAssets } = useReadContract({
    address: vaultAddress,
    abi: VAULT_ABI,
    functionName: 'totalAssets',
  })

  // User's share balance
  const { data: userShares } = useReadContract({
    address: vaultAddress,
    abi: VAULT_ABI,
    functionName: 'balanceOf',
    args: [userAddress],
  })

  // Convert shares to assets
  const { data: userAssets } = useReadContract({
    address: vaultAddress,
    abi: VAULT_ABI,
    functionName: 'convertToAssets',
    args: [userShares || 0n],
  })

  // Active adapter
  const { data: adapter } = useReadContract({
    address: vaultAddress,
    abi: VAULT_ABI,
    functionName: 'activeAdapter',
  })

  // Emergency status
  const { data: isEmergency } = useReadContract({
    address: vaultAddress,
    abi: VAULT_ABI,
    functionName: 'emergencyShutdown',
  })

  return {
    totalAssets: totalAssets ? formatUnits(totalAssets, 6) : '0', // USDC has 6 decimals
    userShares: userShares || 0n,
    userAssets: userAssets ? formatUnits(userAssets, 6) : '0',
    adapter,
    isEmergency,
  }
}
```

### 2. Depositing to Vault

```typescript
// hooks/useVaultDeposit.ts
import { useWriteContract, useWaitForTransactionReceipt } from 'wagmi'
import { parseUnits } from 'viem'
import { VAULT_ABI } from '@/abis/GiveVault4626'
import { ERC20_ABI } from '@/abis/ERC20'

export function useVaultDeposit(vaultAddress: `0x${string}`, assetAddress: `0x${string}`) {
  const { writeContract: approve, data: approveHash } = useWriteContract()
  const { writeContract: deposit, data: depositHash } = useWriteContract()

  const { isLoading: isApproving } = useWaitForTransactionReceipt({
    hash: approveHash,
  })

  const { isLoading: isDepositing } = useWaitForTransactionReceipt({
    hash: depositHash,
  })

  const depositToVault = async (amount: string, decimals: number = 6) => {
    const amountWei = parseUnits(amount, decimals)

    // Step 1: Approve vault to spend tokens
    await approve({
      address: assetAddress,
      abi: ERC20_ABI,
      functionName: 'approve',
      args: [vaultAddress, amountWei],
    })

    // Wait for approval (in real app, use useWaitForTransactionReceipt)
    await new Promise(resolve => setTimeout(resolve, 2000))

    // Step 2: Deposit to vault
    await deposit({
      address: vaultAddress,
      abi: VAULT_ABI,
      functionName: 'deposit',
      args: [amountWei, userAddress], // receiver address
    })
  }

  return {
    depositToVault,
    isLoading: isApproving || isDepositing,
  }
}
```

### 3. Withdrawing from Vault

```typescript
// hooks/useVaultWithdraw.ts
import { useWriteContract, useWaitForTransactionReceipt } from 'wagmi'
import { parseUnits } from 'viem'
import { VAULT_ABI } from '@/abis/GiveVault4626'

export function useVaultWithdraw(vaultAddress: `0x${string}`) {
  const { writeContract, data: hash } = useWriteContract()
  const { isLoading, isSuccess } = useWaitForTransactionReceipt({ hash })

  const withdrawFromVault = async (amount: string, decimals: number = 6) => {
    const amountWei = parseUnits(amount, decimals)

    await writeContract({
      address: vaultAddress,
      abi: VAULT_ABI,
      functionName: 'withdraw',
      args: [
        amountWei,       // assets to withdraw
        userAddress,     // receiver
        userAddress,     // owner
      ],
    })
  }

  const redeemShares = async (shares: bigint) => {
    await writeContract({
      address: vaultAddress,
      abi: VAULT_ABI,
      functionName: 'redeem',
      args: [
        shares,          // shares to burn
        userAddress,     // receiver
        userAddress,     // owner
      ],
    })
  }

  return {
    withdrawFromVault,
    redeemShares,
    isLoading,
    isSuccess,
  }
}
```

---

## Campaign Management

### 1. Reading Campaign Data

```typescript
// hooks/useCampaignData.ts
import { useReadContract } from 'wagmi'
import { CAMPAIGN_REGISTRY_ABI } from '@/abis/CampaignRegistry'
import { CONTRACTS } from '@/config/addresses'

export function useCampaignData(campaignId: `0x${string}`) {
  const { data: campaign } = useReadContract({
    address: CONTRACTS.campaignRegistry,
    abi: CAMPAIGN_REGISTRY_ABI,
    functionName: 'getCampaign',
    args: [campaignId],
  })

  if (!campaign) return null

  return {
    id: campaign.id,
    proposer: campaign.proposer,
    curator: campaign.curator,
    payoutRecipient: campaign.payoutRecipient,
    vault: campaign.vault,
    strategyId: campaign.strategyId,
    metadataHash: campaign.metadataHash,
    targetStake: campaign.targetStake,
    minStake: campaign.minStake,
    totalStaked: campaign.totalStaked,
    fundraisingStart: campaign.fundraisingStart,
    fundraisingEnd: campaign.fundraisingEnd,
    status: campaign.status, // 0=Unknown, 1=Submitted, 2=Approved, 3=Active, 4=Paused, 5=Completed, 6=Cancelled
    payoutsHalted: campaign.payoutsHalted,
  }
}
```

### 2. Listing All Campaigns

```typescript
// hooks/useAllCampaigns.ts
import { useReadContract } from 'wagmi'
import { CAMPAIGN_REGISTRY_ABI } from '@/abis/CampaignRegistry'
import { CONTRACTS } from '@/config/addresses'

export function useAllCampaigns() {
  const { data: campaignIds } = useReadContract({
    address: CONTRACTS.campaignRegistry,
    abi: CAMPAIGN_REGISTRY_ABI,
    functionName: 'getAllCampaignIds',
  })

  // For each campaign, fetch details
  const campaigns = useCampaigns(campaignIds || [])

  return {
    campaigns,
    isLoading: !campaignIds,
  }
}

function useCampaigns(ids: `0x${string}`[]) {
  return ids.map(id => {
    const { data } = useReadContract({
      address: CONTRACTS.campaignRegistry,
      abi: CAMPAIGN_REGISTRY_ABI,
      functionName: 'getCampaign',
      args: [id],
    })
    return data
  }).filter(Boolean)
}
```

### 3. Setting Payout Preferences

```typescript
// hooks/usePayoutPreferences.ts
import { useWriteContract } from 'wagmi'
import { PAYOUT_ROUTER_ABI } from '@/abis/PayoutRouter'
import { CONTRACTS } from '@/config/addresses'

export function usePayoutPreferences() {
  const { writeContract, data: hash } = useWriteContract()

  const setPreferences = async (
    vaultAddress: `0x${string}`,
    campaignId: `0x${string}`,
    beneficiary: `0x${string}`,
    campaignBps: number // 0-10000 (basis points)
  ) => {
    await writeContract({
      address: CONTRACTS.payoutRouter,
      abi: PAYOUT_ROUTER_ABI,
      functionName: 'setYieldPreference',
      args: [
        vaultAddress,
        campaignId,
        beneficiary,
        campaignBps, // e.g., 8000 = 80% to campaign, 20% to beneficiary
      ],
    })
  }

  return { setPreferences, hash }
}
```

---

## User Flows

### Complete Deposit Flow

```typescript
// components/DepositFlow.tsx
'use client'

import { useState } from 'react'
import { useAccount } from 'wagmi'
import { useVaultData } from '@/hooks/useVaultData'
import { useVaultDeposit } from '@/hooks/useVaultDeposit'
import { usePayoutPreferences } from '@/hooks/usePayoutPreferences'

export function DepositFlow({ vaultAddress, campaignId }: Props) {
  const { address } = useAccount()
  const [amount, setAmount] = useState('')
  const [campaignAllocation, setCampaignAllocation] = useState(80) // 80% to campaign

  const { totalAssets } = useVaultData(vaultAddress)
  const { depositToVault, isLoading: isDepositing } = useVaultDeposit(vaultAddress, USDC_ADDRESS)
  const { setPreferences, isLoading: isSettingPrefs } = usePayoutPreferences()

  const handleDeposit = async () => {
    if (!address) return

    // Step 1: Deposit to vault
    await depositToVault(amount)

    // Step 2: Set payout preferences
    await setPreferences(
      vaultAddress,
      campaignId,
      address, // beneficiary (myself)
      campaignAllocation * 100 // Convert to basis points
    )
  }

  return (
    <div className="space-y-4">
      <div>
        <label>Amount to Deposit (USDC)</label>
        <input
          type="number"
          value={amount}
          onChange={(e) => setAmount(e.target.value)}
          placeholder="100.00"
        />
      </div>

      <div>
        <label>Campaign Allocation: {campaignAllocation}%</label>
        <input
          type="range"
          min="0"
          max="100"
          value={campaignAllocation}
          onChange={(e) => setCampaignAllocation(Number(e.target.value))}
        />
        <p className="text-sm text-gray-600">
          {campaignAllocation}% to campaign, {100 - campaignAllocation}% to you
        </p>
      </div>

      <div>
        <p className="text-sm">Vault TVL: ${totalAssets}</p>
      </div>

      <button
        onClick={handleDeposit}
        disabled={isDepositing || isSettingPrefs || !amount}
        className="w-full bg-blue-600 text-white py-2 rounded-lg"
      >
        {isDepositing ? 'Depositing...' : isSettingPrefs ? 'Setting Preferences...' : 'Deposit'}
      </button>
    </div>
  )
}
```

### Complete Withdrawal Flow

```typescript
// components/WithdrawFlow.tsx
'use client'

import { useState } from 'react'
import { useAccount } from 'wagmi'
import { useVaultData } from '@/hooks/useVaultData'
import { useVaultWithdraw } from '@/hooks/useVaultWithdraw'

export function WithdrawFlow({ vaultAddress }: Props) {
  const { address } = useAccount()
  const [amount, setAmount] = useState('')

  const { userAssets, isEmergency } = useVaultData(vaultAddress)
  const { withdrawFromVault, emergencyWithdraw, isLoading } = useVaultWithdraw(vaultAddress)

  const handleWithdraw = async () => {
    if (!address) return

    if (isEmergency) {
      // Use emergency withdrawal after grace period
      await emergencyWithdraw(amount)
    } else {
      // Normal withdrawal
      await withdrawFromVault(amount)
    }
  }

  return (
    <div className="space-y-4">
      {isEmergency && (
        <div className="bg-red-50 border border-red-200 p-4 rounded-lg">
          <p className="text-red-800 font-semibold">⚠️ Emergency Mode Active</p>
          <p className="text-red-600 text-sm">
            Vault is in emergency shutdown. You can still withdraw during the 24-hour grace period.
          </p>
        </div>
      )}

      <div>
        <label>Available Balance: {userAssets} USDC</label>
        <input
          type="number"
          value={amount}
          onChange={(e) => setAmount(e.target.value)}
          max={userAssets}
          placeholder="100.00"
        />
      </div>

      <button
        onClick={handleWithdraw}
        disabled={isLoading || !amount}
        className="w-full bg-blue-600 text-white py-2 rounded-lg"
      >
        {isLoading ? 'Processing...' : 'Withdraw'}
      </button>

      <button
        onClick={() => setAmount(userAssets)}
        className="w-full bg-gray-200 text-gray-800 py-2 rounded-lg"
      >
        Withdraw All
      </button>
    </div>
  )
}
```

---

## Event Listening

### Listening for Deposits

```typescript
// hooks/useDepositEvents.ts
import { useWatchContractEvent } from 'wagmi'
import { VAULT_ABI } from '@/abis/GiveVault4626'

export function useDepositEvents(vaultAddress: `0x${string}`) {
  const [deposits, setDeposits] = useState<DepositEvent[]>([])

  useWatchContractEvent({
    address: vaultAddress,
    abi: VAULT_ABI,
    eventName: 'Deposit',
    onLogs(logs) {
      const newDeposits = logs.map(log => ({
        sender: log.args.sender,
        owner: log.args.owner,
        assets: log.args.assets,
        shares: log.args.shares,
        blockNumber: log.blockNumber,
        transactionHash: log.transactionHash,
      }))
      setDeposits(prev => [...prev, ...newDeposits])
    },
  })

  return deposits
}
```

### Listening for Campaign Events

```typescript
// hooks/useCampaignEvents.ts
import { useWatchContractEvent } from 'wagmi'
import { CAMPAIGN_REGISTRY_ABI } from '@/abis/CampaignRegistry'
import { CONTRACTS } from '@/config/addresses'

export function useCampaignEvents() {
  useWatchContractEvent({
    address: CONTRACTS.campaignRegistry,
    abi: CAMPAIGN_REGISTRY_ABI,
    eventName: 'CampaignApproved',
    onLogs(logs) {
      console.log('New campaign approved:', logs)
      // Update UI, send notification, etc.
    },
  })

  useWatchContractEvent({
    address: CONTRACTS.campaignRegistry,
    abi: CAMPAIGN_REGISTRY_ABI,
    eventName: 'CheckpointScheduled',
    onLogs(logs) {
      console.log('Checkpoint scheduled:', logs)
      // Show voting UI
    },
  })
}
```

---

## Error Handling

### Common Errors and Solutions

```typescript
// utils/errorHandler.ts
export function handleContractError(error: Error): string {
  const errorString = error.message.toLowerCase()

  // Access control errors
  if (errorString.includes('unauthorized')) {
    return 'You do not have permission to perform this action.'
  }

  // Vault errors
  if (errorString.includes('insufficientcash')) {
    return 'Vault does not have enough liquidity. Try again later.'
  }

  if (errorString.includes('excessiveloss')) {
    return 'Withdrawal would cause excessive loss. Please contact support.'
  }

  // Emergency errors
  if (errorString.includes('graceperiodexpired')) {
    return 'Grace period expired. Use emergency withdrawal function.'
  }

  if (errorString.includes('graceperiodactive')) {
    return 'Emergency mode is active but grace period not expired yet.'
  }

  // Fee errors
  if (errorString.includes('timelocknotexpired')) {
    return 'Fee change is still in timelock period. Please wait.'
  }

  // Campaign errors
  if (errorString.includes('invalidcampaignstatus')) {
    return 'Campaign is not in the correct status for this action.'
  }

  if (errorString.includes('novotingpower')) {
    return 'You do not have voting power for this checkpoint.'
  }

  // Generic errors
  if (errorString.includes('user rejected')) {
    return 'Transaction was rejected.'
  }

  return 'An unexpected error occurred. Please try again.'
}
```

### Error Boundary Component

```typescript
// components/ErrorBoundary.tsx
'use client'

import { useEffect } from 'react'
import { handleContractError } from '@/utils/errorHandler'

export function ErrorBoundary({ error, reset }: Props) {
  useEffect(() => {
    console.error('Contract error:', error)
  }, [error])

  const userMessage = handleContractError(error)

  return (
    <div className="bg-red-50 border border-red-200 p-6 rounded-lg">
      <h2 className="text-red-800 text-xl font-semibold mb-2">
        Transaction Failed
      </h2>
      <p className="text-red-600 mb-4">{userMessage}</p>
      <button
        onClick={reset}
        className="bg-red-600 text-white px-4 py-2 rounded-lg"
      >
        Try Again
      </button>
    </div>
  )
}
```

---

## Best Practices

### 1. Gas Optimization

```typescript
// Always estimate gas before transactions
const { data: gasEstimate } = useEstimateGas({
  to: vaultAddress,
  data: encodeFunctionData({
    abi: VAULT_ABI,
    functionName: 'deposit',
    args: [amount, receiver],
  }),
})

// Add 20% buffer to gas estimate
const gasLimit = gasEstimate ? (gasEstimate * 120n) / 100n : undefined
```

### 2. Transaction Monitoring

```typescript
// hooks/useTransactionToast.ts
import { useWaitForTransactionReceipt } from 'wagmi'
import { toast } from 'sonner'

export function useTransactionToast(hash: `0x${string}` | undefined) {
  const { isLoading, isSuccess, isError } = useWaitForTransactionReceipt({ hash })

  useEffect(() => {
    if (isLoading) {
      toast.loading('Transaction pending...', { id: hash })
    }
    if (isSuccess) {
      toast.success('Transaction confirmed!', { id: hash })
    }
    if (isError) {
      toast.error('Transaction failed', { id: hash })
    }
  }, [isLoading, isSuccess, isError, hash])
}
```

### 3. Data Caching

```typescript
// Use React Query for caching
const { data, isLoading, refetch } = useReadContract({
  address: vaultAddress,
  abi: VAULT_ABI,
  functionName: 'totalAssets',
  query: {
    staleTime: 60_000, // Consider data fresh for 60 seconds
    cacheTime: 300_000, // Keep in cache for 5 minutes
  },
})
```

### 4. Network Detection

```typescript
// hooks/useNetworkCheck.ts
import { useAccount, useChainId } from 'wagmi'
import { sepolia } from 'wagmi/chains'

export function useNetworkCheck() {
  const chainId = useChainId()
  const expectedChainId = sepolia.id

  const isWrongNetwork = chainId !== expectedChainId

  return {
    isWrongNetwork,
    currentNetwork: chainId,
    expectedNetwork: expectedChainId,
  }
}
```

---

## Example Code

### Complete Campaign Dashboard

```typescript
// app/campaigns/[id]/page.tsx
'use client'

import { useAccount } from 'wagmi'
import { useCampaignData } from '@/hooks/useCampaignData'
import { useVaultData } from '@/hooks/useVaultData'
import { DepositFlow } from '@/components/DepositFlow'
import { WithdrawFlow } from '@/components/WithdrawFlow'

export default function CampaignPage({ params }: { params: { id: string } }) {
  const { address, isConnected } = useAccount()
  const campaign = useCampaignData(params.id as `0x${string}`)
  const vault = useVaultData(campaign?.vault)

  if (!campaign) {
    return <div>Loading campaign...</div>
  }

  const statusLabels = {
    0: 'Unknown',
    1: 'Submitted',
    2: 'Approved',
    3: 'Active',
    4: 'Paused',
    5: 'Completed',
    6: 'Cancelled',
  }

  return (
    <div className="max-w-4xl mx-auto p-6 space-y-8">
      {/* Campaign Header */}
      <div className="bg-white rounded-lg shadow p-6">
        <h1 className="text-3xl font-bold mb-2">{campaign.metadataHash}</h1>
        <div className="flex items-center gap-2">
          <span className={`px-3 py-1 rounded-full text-sm ${
            campaign.status === 3 ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-800'
          }`}>
            {statusLabels[campaign.status]}
          </span>
        </div>
      </div>

      {/* Campaign Stats */}
      <div className="grid grid-cols-3 gap-4">
        <div className="bg-white rounded-lg shadow p-6">
          <p className="text-gray-600 text-sm">Total Staked</p>
          <p className="text-2xl font-bold">
            ${(Number(campaign.totalStaked) / 1e6).toLocaleString()}
          </p>
        </div>
        <div className="bg-white rounded-lg shadow p-6">
          <p className="text-gray-600 text-sm">Vault TVL</p>
          <p className="text-2xl font-bold">${vault?.totalAssets}</p>
        </div>
        <div className="bg-white rounded-lg shadow p-6">
          <p className="text-gray-600 text-sm">Your Deposit</p>
          <p className="text-2xl font-bold">${vault?.userAssets}</p>
        </div>
      </div>

      {/* Actions */}
      {isConnected ? (
        <div className="grid grid-cols-2 gap-8">
          <div className="bg-white rounded-lg shadow p-6">
            <h2 className="text-xl font-semibold mb-4">Deposit</h2>
            <DepositFlow
              vaultAddress={campaign.vault}
              campaignId={campaign.id}
            />
          </div>

          <div className="bg-white rounded-lg shadow p-6">
            <h2 className="text-xl font-semibold mb-4">Withdraw</h2>
            <WithdrawFlow vaultAddress={campaign.vault} />
          </div>
        </div>
      ) : (
        <div className="bg-gray-50 border border-gray-200 p-8 rounded-lg text-center">
          <p className="text-gray-600 mb-4">Connect your wallet to interact with this campaign</p>
          <ConnectButton />
        </div>
      )}

      {/* Campaign Details */}
      <div className="bg-white rounded-lg shadow p-6">
        <h2 className="text-xl font-semibold mb-4">Campaign Details</h2>
        <dl className="space-y-2">
          <div className="flex justify-between">
            <dt className="text-gray-600">Payout Recipient:</dt>
            <dd className="font-mono text-sm">{campaign.payoutRecipient}</dd>
          </div>
          <div className="flex justify-between">
            <dt className="text-gray-600">Vault Address:</dt>
            <dd className="font-mono text-sm">{campaign.vault}</dd>
          </div>
          <div className="flex justify-between">
            <dt className="text-gray-600">Strategy ID:</dt>
            <dd className="font-mono text-sm">{campaign.strategyId}</dd>
          </div>
        </dl>
      </div>
    </div>
  )
}
```

---

## Additional Resources

### Contract ABIs

Place ABIs in `src/abis/` directory. Generate them from compiled contracts:

```bash
cd backend
forge inspect GiveVault4626 abi > ../apps/web/src/abis/GiveVault4626.json
forge inspect CampaignRegistry abi > ../apps/web/src/abis/CampaignRegistry.json
forge inspect PayoutRouter abi > ../apps/web/src/abis/PayoutRouter.json
```

### Testing Frontend

```typescript
// Use Wagmi's mock connector for testing
import { createConfig, http } from 'wagmi'
import { sepolia } from 'wagmi/chains'
import { mock } from 'wagmi/connectors'

export const config = createConfig({
  chains: [sepolia],
  connectors: [
    mock({
      accounts: [
        '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266', // Anvil account #0
      ],
    }),
  ],
  transports: {
    [sepolia.id]: http('http://localhost:8545'),
  },
})
```

### Useful Links

- **Wagmi Docs:** https://wagmi.sh
- **Viem Docs:** https://viem.sh
- **RainbowKit Docs:** https://www.rainbowkit.com
- **ERC4626 Standard:** https://eips.ethereum.org/EIPS/eip-4626
- **GIVE Protocol Docs:**
  - `/docs/ARCHITECTURE.md` - System architecture with mermaid diagrams
  - `/docs/EMERGENCY_PROCEDURES.md` - Incident response runbook
  - `/docs/EVENT_SCHEMAS.md` - Event definitions for indexers
  - `audits/CODE_REVIEW_COMPLETE.md` - Security audit results

---

## Troubleshooting

### Common Issues

**Issue:** "Contract not deployed on this network"
- **Solution:** Check `src/config/addresses.ts` has correct addresses for your network
- **Verify:** Run `forge script script/Bootstrap.s.sol` and copy logged addresses

**Issue:** "Transaction reverted without reason"
- **Solution:** Increase gas limit, check contract state (paused/emergency mode)
- **Debug:** Use `forge test -vvvv` to see detailed revert reasons

**Issue:** "Insufficient allowance"
- **Solution:** Ensure approval transaction completed before deposit
- **Fix:** Add proper loading states and transaction confirmation waits

**Issue:** "Wrong network"
- **Solution:** Add network switching prompt using `useSwitchChain` hook
- **Example:** RainbowKit automatically handles this in `ConnectButton`

---

## Support

For issues, questions, or contributions:
- **GitHub:** https://github.com/GIVE-Labs/give-protocol-v0
- **Discord:** [Join our community]
- **Email:** dev@giveprotocol.org

---

**Last Updated:** October 24, 2025  
**Version:** 0.5.0
