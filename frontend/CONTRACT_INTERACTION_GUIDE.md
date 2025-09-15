# GIVE Protocol Frontend Interaction Guide

## Overview
This guide shows how to interact with GIVE Protocol contracts (ERC-4626 vault, DonationRouter, NGORegistry) from the frontend using wagmi/viem. The system now supports user-configurable yield allocation (50%, 75%, 100%) with a 1% protocol fee.

## Contract Addresses (Scroll Sepolia)
After deployment, update these addresses:
```
GiveVault4626 (USDC): 0x...
StrategyManager: 0x...
NGORegistry: 0x...
DonationRouter: 0x...
Adapter (Aave): 0x...
```

## Supported Assets
- USDC (for v0.1 example vault)

## Frontend Integration

### 1. Setup wagmi + viem
```typescript
import { createConfig, http } from 'wagmi'
import { injected } from 'wagmi/connectors'
import { SCROLL_SEPOLIA } from '@/src/config/contracts'

export const config = createConfig({
  chains: [SCROLL_SEPOLIA],
  connectors: [injected()],
  transports: { [SCROLL_SEPOLIA.id]: http(SCROLL_SEPOLIA.rpcUrls.default.http[0]) },
})
```

## Contract Interactions

### Vault (ERC-4626)

#### Deposit
```typescript
import { parseUnits } from 'viem'
import { useWriteContract } from 'wagmi'

const { writeContractAsync } = useWriteContract()

async function deposit(amount: string, receiver: `0x${string}`) {
  const amountWei = parseUnits(amount, 6) // USDC
  // 1) Approve USDC to vault
  await writeContractAsync({
    abi: erc20ABI,
    address: USDC_ADDRESS,
    functionName: 'approve',
    args: [VAULT_ADDRESS, amountWei],
  })
  // 2) Deposit
  return writeContractAsync({
    abi: vaultAbi,
    address: VAULT_ADDRESS,
    functionName: 'deposit',
    args: [amountWei, receiver],
  })
}
```

#### Withdraw
```typescript
async function withdraw(assets: string, receiver: `0x${string}`, owner: `0x${string}`) {
  const assetsWei = parseUnits(assets, 6)
  return writeContractAsync({
    abi: vaultAbi,
    address: VAULT_ADDRESS,
    functionName: 'withdraw',
    args: [assetsWei, receiver, owner],
  })
}
```

#### Previews
```typescript
import { useReadContract } from 'wagmi'

function usePreviews(assets: string, shares: string) {
  const assetsWei = parseUnits(assets || '0', 6)
  const sharesWei = parseUnits(shares || '0', 6)
  const previewDeposit = useReadContract({
    abi: vaultAbi,
    address: VAULT_ADDRESS,
    functionName: 'previewDeposit',
    args: [assetsWei],
  })
  const previewRedeem = useReadContract({
    abi: vaultAbi,
    address: VAULT_ADDRESS,
    functionName: 'previewRedeem',
    args: [sharesWei],
  })
  return { previewDeposit, previewRedeem }
}
```

### Harvest and Donations

#### Harvest (permissionless)
```typescript
async function harvest() {
  return writeContractAsync({
    abi: vaultAbi,
    address: VAULT_ADDRESS,
    functionName: 'harvest',
    args: [],
  })
}
```

Note: In v0.1, donations are sent atomically during `harvest()` via the router’s `distribute`. No manual claim is needed.

### NGO Management

#### Register New NGO
```typescript
import { prepareContractCall, sendTransaction } from "thirdweb";

const registerNGO = async (
  name: string,
  description: string,
  website: string,
  logoURI: string,
  walletAddress: string,
  causes: string[],
  metadataURI: string
) => {
  const transaction = prepareContractCall({
    contract: NGORegistry,
    method: "registerNGO",
    params: [
      name,
      description,
      website,
      logoURI,
      walletAddress,
      causes,
      metadataURI
    ]
  });

  const { transactionHash } = await sendTransaction({
    transaction,
    account: activeAccount,
  });
  
  return transactionHash;
};
```

#### Get NGO Details
```typescript
// Example reads
// Current NGO
const { data: currentNGO } = useReadContract({
  abi: registryAbi,
  address: NGO_REGISTRY_ADDRESS,
  functionName: 'getCurrentNGO',
})

// Router fee config & totals
const { data: feeConfig } = useReadContract({
  abi: routerAbi,
  address: DONATION_ROUTER_ADDRESS,
  functionName: 'getFeeConfig',
})
const { data: stats } = useReadContract({
  abi: routerAbi,
  address: DONATION_ROUTER_ADDRESS,
  functionName: 'getDistributionStats',
  args: [USDC_ADDRESS],
})
```

#### List All NGOs
```typescript
const getAllNGOs = async () => {
  const ngos = await readContract({
    contract: NGORegistry,
    method: "getAllNGOs",
    params: []
  });
  
  return ngos.map(ngo => ({
    address: ngo.ngoAddress,
    name: ngo.name,
    description: ngo.description,
    causes: ngo.causes,
    isVerified: ngo.isVerified,
  }));
};
```

### User Preference Management

#### Set User Preference
```typescript
const setUserPreference = async (ngoAddress: string, allocationPercentage: number) => {
  // allocationPercentage must be 50, 75, or 100
  const { hash } = await writeContract({
    abi: donationRouterAbi,
    address: DONATION_ROUTER_ADDRESS,
    functionName: 'setUserPreference',
    args: [ngoAddress, allocationPercentage],
  });
  
  await waitForTransactionReceipt({ hash });
};
```

#### Get User Preference
```typescript
const { data: userPreference } = useReadContract({
  abi: donationRouterAbi,
  address: DONATION_ROUTER_ADDRESS,
  functionName: 'getUserPreference',
  args: [userAddress],
});

// Returns: { selectedNGO: address, allocationPercentage: uint8, lastUpdated: uint256 }
```

#### Calculate Distribution Preview
```typescript
const { data: distribution } = useReadContract({
  abi: donationRouterAbi,
  address: DONATION_ROUTER_ADDRESS,
  functionName: 'calculateUserDistribution',
  args: [userAddress, parseUnits('100', 6)], // Example: 100 USDC yield
});

// Returns: [ngoAmount, treasuryAmount, protocolAmount]
```

#### Get Valid Allocation Options
```typescript
const { data: validAllocations } = useReadContract({
  abi: donationRouterAbi,
  address: DONATION_ROUTER_ADDRESS,
  functionName: 'getValidAllocations',
});

// Returns: [50, 75, 100]
```

### Utility Functions

#### Get Vault Asset
```typescript
const getVaultAsset = async () => {
  const asset = await readContract({
    contract: GiveVault4626,
    method: "asset",
    params: []
  });
  return asset;
};
```

#### User Shares Balance
```typescript
const userShares = async (user: string) => {
  return await readContract({
    contract: GiveVault4626,
    method: "balanceOf",
    params: [user]
  });
};
```

### Frontend Components Structure

#### 1. NGO Discovery Component
```typescript
// components/NGODiscovery.tsx
import { useReadContract } from "thirdweb/react";

const NGODiscovery: React.FC = () => {
  const { data: ngos, isLoading } = useReadContract({
    contract: NGORegistry,
    method: "getAllNGOs",
    params: []
  });

  return (
    <div className="ngo-grid">
      {ngos?.map(ngo => (
        <NGOCard key={ngo.ngoAddress} ngo={ngo} />
      ))}
    </div>
  );
};
```

#### 2. Deposit Modal Component
```typescript
// components/DepositModal.tsx
import { useState } from "react";
import { useSendTransaction } from "thirdweb/react";

interface DepositModalProps {
  ngo: NGO;
}

const DepositModal: React.FC<DepositModalProps> = ({ ngo }) => {
  const [amount, setAmount] = useState("");
  const { mutate: sendTransaction } = useSendTransaction();

  const handleDeposit = async () => {
    await sendTransaction({
      transaction: prepareContractCall({
        contract: GiveVault4626,
        method: "deposit",
        params: [parseUnits(amount, 6), activeAccount?.address]
      })
    });
  };

  return (
    <div className="deposit-modal">
      <h2>Deposit to support {ngo.name}</h2>
      <input
        type="number"
        placeholder="Amount"
        value={amount}
        onChange={(e) => setAmount(e.target.value)}
      />
      <button onClick={handleDeposit}>Deposit</button>
    </div>
  );
};
```

#### 3. User Dashboard Component
```typescript
// components/UserDashboard.tsx
const UserDashboard: React.FC = () => {
  const { data: shares } = useReadContract({
    contract: GiveVault4626,
    method: "balanceOf",
    params: [activeAccount?.address]
  });
  
  return (
    <div className="user-dashboard">
      <h2>Your Vault Position</h2>
      <div>Shares: {shares?.toString()}</div>
    </div>
  );
};
```

## Error Handling

### Common Errors and Solutions
```typescript
const handleContractError = (error: any) => {
  if (error.message.includes("MaxLossExceeded")) {
    toast.error("Exit would exceed max loss");
  } else if (error.message.includes("InvalidNGO")) {
    toast.error("NGO is not verified or inactive");
  } else if (error.message.includes("Paused")) {
    toast.error("Invest/harvest is currently paused");
  } else {
    toast.error("Transaction failed");
  }
};
```
