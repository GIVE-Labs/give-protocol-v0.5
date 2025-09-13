# GIVE Protocol Frontend Interaction Guide

## Overview
This guide shows how to interact with GIVE Protocol contracts (ERC-4626 vault, DonationRouter, NGORegistry) from the frontend using thirdweb/viem.

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

### 1. Setup thirdweb Client
```typescript
import { createThirdwebClient } from "thirdweb";

const client = createThirdwebClient({
  clientId: "YOUR_THIRDWEB_CLIENT_ID",
});
```

### 2. Connect Wallet
```typescript
import { ConnectButton } from "thirdweb/react";

<ConnectButton
  client={client}
  appMetadata={{
    name: "GIVE Protocol",
    url: "https://giveprotocol.org",
  }}
/>
```

## Contract Interactions

### Vault (ERC-4626)

#### Deposit
```typescript
import { prepareContractCall, sendTransaction } from "thirdweb";

const deposit = async (amountWei: string, receiver: string) => {
  // Approve USDC to vault first
  await sendTransaction({
    transaction: prepareContractCall({
      contract: USDC,
      method: "approve",
      params: [GiveVault4626.address, amountWei]
    }),
    account: activeAccount,
  });

  // Deposit to ERC-4626 vault
  const { transactionHash } = await sendTransaction({
    transaction: prepareContractCall({
      contract: GiveVault4626,
      method: "deposit",
      params: [amountWei, receiver]
    }),
    account: activeAccount,
  });

  return transactionHash;
};
```

#### Withdraw
```typescript
const withdraw = async (assetsWei: string, receiver: string, owner: string) => {
  const { transactionHash } = await sendTransaction({
    transaction: prepareContractCall({
      contract: GiveVault4626,
      method: "withdraw",
      params: [assetsWei, receiver, owner]
    }),
    account: activeAccount,
  });
  return transactionHash;
};
```

#### Previews
```typescript
import { readContract } from "thirdweb";

const previews = async (assetsWei: string, sharesWei: string) => {
  const shares = await readContract({
    contract: GiveVault4626,
    method: "previewDeposit",
    params: [assetsWei]
  });
  const assets = await readContract({
    contract: GiveVault4626,
    method: "previewRedeem",
    params: [sharesWei]
  });
  return { shares, assets };
};
```

### Harvest and Donations

#### Harvest (anyone / keeper / manager)
```typescript
const harvest = async () => {
  const { transactionHash } = await sendTransaction({
    transaction: prepareContractCall({
      contract: GiveVault4626,
      method: "harvest",
      params: []
    }),
    account: activeAccount,
  });
  return transactionHash;
};
```

#### Claim to Current NGO
```typescript
const claimDonation = async (ngoAddress: string) => {
  const { transactionHash } = await sendTransaction({
    transaction: prepareContractCall({
      contract: DonationRouter,
      method: "claim",
      params: [ngoAddress]
    }),
    account: activeAccount,
  });
  return transactionHash;
};
```

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
const getNGODetails = async (ngoAddress: string) => {
  const ngo = await readContract({
    contract: NGORegistry,
    method: "getNGO",
    params: [ngoAddress]
  });
  
  return {
    name: ngo.name,
    description: ngo.description,
    website: ngo.website,
    logoURI: ngo.logoURI,
    walletAddress: ngo.walletAddress,
    causes: ngo.causes,
    metadataURI: ngo.metadataURI,
    isVerified: ngo.isVerified,
  };
};
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
