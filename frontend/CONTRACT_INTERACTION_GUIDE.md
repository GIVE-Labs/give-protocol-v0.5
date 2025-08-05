# MorphImpact Contract Interaction Guide

## Overview
This guide provides comprehensive instructions for interacting with the MorphImpact smart contracts from the NextJS frontend using the thirdweb SDK.

## Contract Addresses (Deploy to Morph Chain)
After deployment, update these addresses:
```
NGORegistry: 0x...
MockYieldVault: 0x...
MorphImpactStaking: 0x...
YieldDistributor: 0x...
```

## Supported Tokens
- **ETH**: Native token for Morph Chain
- **USDC**: 0x...
- **WETH**: 0x...

## Frontend Integration with thirdweb

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

// In your component
<ConnectButton
  client={client}
  appMetadata={{
    name: "MorphImpact",
    url: "https://morphimpact.com",
  }}
/>
```

## Contract Interactions

### NGO Management

#### Register New NGO
```typescript
import { prepareContractCall, sendTransaction } from "thirdweb";
import { MorphImpactStaking } from "./abis/MorphImpactStaking";

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
    reputationScore: ngo.reputationScore.toString(),
    totalStakers: ngo.totalStakers.toString(),
    totalYieldReceived: ngo.totalYieldReceived.toString()
  };
};

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
    reputationScore: ngo.reputationScore.toString()
  }));
};
```

### Staking Operations

#### Stake Tokens for NGO
```typescript
const stake = async (
  ngoAddress: string,
  tokenAddress: string,
  amount: string, // in wei
  lockPeriod: number, // in seconds
  yieldContributionRate: number // 5000-10000 (50-100%)
) => {
  // First approve tokens
  const approveTx = prepareContractCall({
    contract: ERC20(tokenAddress),
    method: "approve",
    params: [MorphImpactStaking.address, amount]
  });
  
  await sendTransaction({
    transaction: approveTx,
    account: activeAccount,
  });

  // Then stake
  const stakeTx = prepareContractCall({
    contract: MorphImpactStaking,
    method: "stake",
    params: [
      ngoAddress,
      tokenAddress,
      amount,
      lockPeriod,
      yieldContributionRate
    ]
  });

  const { transactionHash } = await sendTransaction({
    transaction: stakeTx,
    account: activeAccount,
  });
  
  return transactionHash;
};
```

#### Get User Stakes
```typescript
const getUserStakes = async (userAddress: string, tokenAddress: string) => {
  const ngos = await readContract({
    contract: MorphImpactStaking,
    method: "getUserStakedNGOs",
    params: [userAddress, tokenAddress]
  });

  const stakes = await Promise.all(
    ngos.map(async (ngo) => {
      const stake = await readContract({
        contract: MorphImpactStaking,
        method: "getUserStake",
        params: [userAddress, ngo, tokenAddress]
      });
      
      return {
        ngoAddress: ngo,
        amount: stake.amount.toString(),
        lockUntil: new Date(Number(stake.lockUntil) * 1000),
        yieldContributionRate: stake.yieldContributionRate,
        totalYieldGenerated: stake.totalYieldGenerated.toString(),
        totalYieldToNGO: stake.totalYieldToNGO.toString(),
        isActive: stake.isActive
      };
    })
  );
  
  return stakes;
};
```

#### Claim Yield Without Unstaking
```typescript
const claimYield = async (ngoAddress: string, tokenAddress: string) => {
  const transaction = prepareContractCall({
    contract: MorphImpactStaking,
    method: "claimYield",
    params: [ngoAddress, tokenAddress]
  });

  const { transactionHash } = await sendTransaction({
    transaction,
    account: activeAccount,
  });
  
  return transactionHash;
};
```

#### Unstake Tokens
```typescript
const unstake = async (ngoAddress: string, tokenAddress: string, amount?: string) => {
  const transaction = prepareContractCall({
    contract: MorphImpactStaking,
    method: "unstake",
    params: [
      ngoAddress,
      tokenAddress,
      amount || "0" // 0 for full unstake
    ]
  });

  const { transactionHash } = await sendTransaction({
    transaction,
    account: activeAccount,
  });
  
  return transactionHash;
};
```

#### Get Pending Yield
```typescript
const getPendingYield = async (userAddress: string, ngoAddress: string, tokenAddress: string) => {
  const [pendingYield, userYield, ngoYield] = await readContract({
    contract: MorphImpactStaking,
    method: "getPendingYield",
    params: [userAddress, ngoAddress, tokenAddress]
  });
  
  return {
    pendingYield: pendingYield.toString(),
    userYield: userYield.toString(),
    ngoYield: ngoYield.toString()
  };
};
```

### Yield Distribution

#### Initiate Distribution (Admin)
```typescript
const initiateDistribution = async () => {
  const transaction = prepareContractCall({
    contract: YieldDistributor,
    method: "initiateDistribution",
    params: []
  });

  const { transactionHash } = await sendTransaction({
    transaction,
    account: activeAccount,
  });
  
  return transactionHash;
};
```

#### Get Distribution Status
```typescript
const getDistributionStatus = async () => {
  const [canDistribute, timeUntil, totalTokens] = await readContract({
    contract: YieldDistributor,
    method: "getDistributionStatus",
    params: []
  });
  
  return {
    canDistribute,
    timeUntil: Number(timeUntil),
    totalTokens: Number(totalTokens)
  };
};

#### Get Distribution Round Details
```typescript
const getDistributionRound = async (roundNumber: number) => {
  const [round, totalYield, distributionTime, stakersCount] = await readContract({
    contract: YieldDistributor,
    method: "getDistributionRound",
    params: [roundNumber]
  });
  
  return {
    roundNumber: Number(round),
    totalYield: totalYield.toString(),
    distributionTime: new Date(Number(distributionTime) * 1000),
    stakersCount: Number(stakersCount)
  };
};
```

### Utility Functions

#### Get Supported Tokens
```typescript
const getSupportedTokens = async () => {
  const tokens = await readContract({
    contract: MorphImpactStaking,
    method: "getSupportedTokens",
    params: []
  });
  
  return tokens;
};

#### Check Active Stake
```typescript
const hasActiveStake = async (userAddress: string, ngoAddress: string, tokenAddress: string) => {
  return await readContract({
    contract: MorphImpactStaking,
    method: "hasActiveStake",
    params: [userAddress, ngoAddress, tokenAddress]
  });
};

#### Get NGO Total Staked
```typescript
const getTotalStakedForNGO = async (ngoAddress: string, tokenAddress: string) => {
  const total = await readContract({
    contract: MorphImpactStaking,
    method: "getTotalStakedForNGO",
    params: [ngoAddress, tokenAddress]
  });
  
  return total.toString();
};

### Event Handling

#### Listen for Stake Events
```typescript
import { useContractEvents } from "thirdweb/react";

const { data: stakeEvents } = useContractEvents({
  contract: MorphImpactStaking,
  eventName: "Staked",
  watch: true,
});
```

#### Listen for Yield Distribution Events
```typescript
const { data: distributionEvents } = useContractEvents({
  contract: YieldDistributor,
  eventName: "DistributionInitiated",
  watch: true,
});
```

## Frontend Components Structure

### 1. NGO Discovery Component
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

### 2. Staking Modal Component
```typescript
// components/StakingModal.tsx
import { useState } from "react";
import { useSendTransaction } from "thirdweb/react";

interface StakingModalProps {
  ngo: NGO;
  token: Token;
}

const StakingModal: React.FC<StakingModalProps> = ({ ngo, token }) => {
  const [amount, setAmount] = useState("");
  const [lockPeriod, setLockPeriod] = useState(90 * 24 * 60 * 60); // 90 days
  const [yieldContribution, setYieldContribution] = useState(7500); // 75%
  
  const { mutate: sendTransaction } = useSendTransaction();

  const handleStake = async () => {
    await sendTransaction({
      transaction: prepareContractCall({
        contract: MorphImpactStaking,
        method: "stake",
        params: [
          ngo.ngoAddress,
          token.address,
          parseEther(amount),
          lockPeriod,
          yieldContribution
        ]
      })
    });
  };

  return (
    <div className="staking-modal">
      <h2>Stake for {ngo.name}</h2>
      <input
        type="number"
        placeholder="Amount"
        value={amount}
        onChange={(e) => setAmount(e.target.value)}
      />
      <input
        type="range"
        min="30"
        max="365"
        value={lockPeriod / (24 * 60 * 60)}
        onChange={(e) => setLockPeriod(Number(e.target.value) * 24 * 60 * 60)}
      />
      <input
        type="range"
        min="5000"
        max="10000"
        value={yieldContribution}
        onChange={(e) => setYieldContribution(Number(e.target.value))}
      />
      <button onClick={handleStake}>Stake</button>
    </div>
  );
};
```

### 3. User Dashboard Component
```typescript
// components/UserDashboard.tsx
const UserDashboard: React.FC = () => {
  const { data: stakes } = useUserStakes(activeAccount?.address, tokenAddress);
  
  return (
    <div className="user-dashboard">
      <h2>Your Stakes</h2>
      {stakes?.map(stake => (
        <StakeCard key={stake.ngoAddress} stake={stake} />
      ))}
    </div>
  );
};
```

## Error Handling

### Common Errors and Solutions

```typescript
const handleContractError = (error: any) => {
  if (error.message.includes("UnsupportedToken")) {
    toast.error("This token is not supported for staking");
  } else if (error.message.includes("InvalidNGO")) {
    toast.error("NGO is not verified or inactive");
  } else if (error.message.includes("StakeStillLocked")) {
    toast.error("Stake is still locked");
  } else if (error.message.includes("DistributionTooFrequent")) {
    toast.error("Distribution interval not passed");
  } else {
    toast.error("Transaction failed");
  }
};
```

## Gas Estimation

### Estimate Gas for Transactions
```typescript
const estimateGas = async (transaction: any) => {
  const gasEstimate = await estimateGasCost({
    transaction,
    client,
  });
  
  return gasEstimate;
};
```

## Security Best Practices

1. **Input Validation**: Always validate user inputs
2. **Slippage Protection**: Use appropriate slippage tolerance for transactions
3. **Error Handling**: Implement comprehensive error handling
4. **Loading States**: Show loading indicators during transactions
5. **Confirmation Modals**: Require user confirmation for high-value transactions

## Testing Checklist

- [ ] Connect wallet successfully
- [ ] Register new NGO
- [ ] View NGO details
- [ ] Stake tokens for NGO
- [ ] View user stakes
- [ ] Claim yield without unstaking
- [ ] Unstake tokens
- [ ] Get pending yield information
- [ ] Handle all error states gracefully
- [ ] Test on Morph Chain testnet

## Resources

- [thirdweb React SDK Docs](https://portal.thirdweb.com/react)
- [Morph Chain Documentation](https://docs.morphl2.io/)
- [Contract ABIs](./abis/) - Copy ABIs here after deployment
- [Example Code Snippets](./examples/) - Ready-to-use code patterns