# Frontend Integration Guide

This guide explains how to integrate the deployed GIVE Protocol smart contracts into the frontend application.

## Deployed Contract Addresses

The following contracts have been deployed and are configured in `/src/config/contracts.ts`:

- **Vault**: `0x2b67de726Fc1Fdc1AE1d34aa89e1d1152C11fA52`
- **StrategyManager**: `0x4aE8717F12b1618Ff68c7de430E53735c4e48F1d`
- **AaveAdapter**: `0x8c6824E4d86fBF849157035407B2418F5f992dB7`
- **NGORegistry**: `0x36Fb53A3d29d1822ec0bA73ae4658185C725F5CC`
- **DonationRouter**: `0x2F86620b005b4Bc215ebeB5d8A9eDfE7eC4Ccfb7`

## Available Hooks

The `/src/hooks/useContracts.ts` file provides React hooks for interacting with each contract:

### 1. useVault()

Interacts with the main GiveVault4626 contract for deposits, withdrawals, and harvesting. The vault now automatically updates user shares for yield distribution.

```typescript
import { useVault } from '../hooks/useContracts';

function VaultComponent() {
  const {
    totalAssets,
    cashBalance,
    adapterAssets,
    harvestStats,
    configuration,
    deposit,
    withdraw,
    harvest,
    isPending,
    isConfirming,
    isConfirmed,
    error
  } = useVault();

  const handleDeposit = () => {
    deposit('100', userAddress); // Deposit 100 USDC
  };

  const handleWithdraw = () => {
    withdraw('50', userAddress, userAddress); // Withdraw 50 USDC
  };

  const handleHarvest = () => {
    harvest(); // Harvest yield and distribute to NGOs
  };

  return (
    <div>
      <p>Total Assets: {totalAssets} USDC</p>
      <p>Cash Balance: {cashBalance} USDC</p>
      <p>Adapter Assets: {adapterAssets} USDC</p>
      
      <button onClick={handleDeposit} disabled={isPending}>
        {isPending ? 'Depositing...' : 'Deposit 100 USDC'}
      </button>
      
      <button onClick={handleWithdraw} disabled={isPending}>
        {isPending ? 'Withdrawing...' : 'Withdraw 50 USDC'}
      </button>
      
      <button onClick={handleHarvest} disabled={isPending}>
        {isPending ? 'Harvesting...' : 'Harvest Yield'}
      </button>
    </div>
  );
}
```

### 2. useDonationRouter()

Interacts with the DonationRouter for yield distribution and fee management.

```typescript
import { useDonationRouter } from '../hooks/useContracts';

function DonationComponent() {
  const {
    distributionStats,
    feeConfig,
    calculateDistribution,
    distribute,
    isPending
  } = useDonationRouter();

  const handleDistribute = () => {
    distribute(CONTRACT_ADDRESSES.TOKENS.USDC, '10'); // Distribute 10 USDC
  };

  return (
    <div>
      <h3>Donation Statistics</h3>
      {distributionStats && (
        <div>
          <p>Total Donated: {formatUnits(distributionStats[0], 6)} USDC</p>
          <p>Total Fees: {formatUnits(distributionStats[1], 6)} USDC</p>
          <p>Current NGO: {distributionStats[2]}</p>
          <p>Fee Rate: {distributionStats[3] / 100}%</p>
        </div>
      )}
      
      <button onClick={handleDistribute} disabled={isPending}>
        {isPending ? 'Distributing...' : 'Distribute 10 USDC'}
      </button>
    </div>
  );
}
```

### 3. useStrategyManager()

Interacts with the StrategyManager for automated yield optimization.

```typescript
import { useStrategyManager } from '../hooks/useContracts';

function StrategyComponent() {
  const {
    canRebalance,
    canHarvest,
    activeAdapter,
    performanceMetrics,
    harvest,
    rebalance,
    isPending
  } = useStrategyManager();

  return (
    <div>
      <h3>Strategy Management</h3>
      <p>Active Adapter: {activeAdapter}</p>
      <p>Can Rebalance: {canRebalance ? 'Yes' : 'No'}</p>
      <p>Can Harvest: {canHarvest ? 'Yes' : 'No'}</p>
      
      {performanceMetrics && (
        <div>
          <p>Total Profit: {formatUnits(performanceMetrics[0], 6)} USDC</p>
          <p>Total Loss: {formatUnits(performanceMetrics[1], 6)} USDC</p>
          <p>Last Harvest: {new Date(Number(performanceMetrics[2]) * 1000).toLocaleString()}</p>
        </div>
      )}
      
      <button onClick={harvest} disabled={isPending || !canHarvest}>
        {isPending ? 'Harvesting...' : 'Harvest'}
      </button>
      
      <button onClick={rebalance} disabled={isPending || !canRebalance}>
        {isPending ? 'Rebalancing...' : 'Rebalance'}
      </button>
    </div>
  );
}
```

### 4. useDonationRouter()

Interacts with the DonationRouter for user preferences and yield allocation.

```typescript
import { useDonationRouter } from '../hooks/useContracts';

function UserPreferencesComponent() {
  const {
    userPreference,
    setUserPreference,
    getUserAssetShares,
    calculateUserDistribution,
    getValidAllocations,
    isPending
  } = useDonationRouter();

  const handleSetPreference = async (ngoAddress: string, allocationPercentage: number) => {
    await setUserPreference(ngoAddress, allocationPercentage);
  };

  return (
    <div>
      <h3>Your Donation Preferences</h3>
      {userPreference && (
        <div>
          <p>Selected NGO: {userPreference.selectedNGO}</p>
          <p>Allocation: {userPreference.allocationPercentage}%</p>
          <p>Last Updated: {new Date(Number(userPreference.lastUpdated) * 1000).toLocaleDateString()}</p>
        </div>
      )}
      
      <div>
        <h4>Choose Your Impact Level:</h4>
        <button onClick={() => handleSetPreference(selectedNGO, 50)} disabled={isPending}>
          50% to NGO, 50% to Treasury
        </button>
        <button onClick={() => handleSetPreference(selectedNGO, 75)} disabled={isPending}>
          75% to NGO, 25% to Treasury
        </button>
        <button onClick={() => handleSetPreference(selectedNGO, 100)} disabled={isPending}>
          100% to NGO
        </button>
      </div>
    </div>
  );
}
```

### 5. useNGORegistry()

Interacts with the NGORegistry to display available NGOs.

```typescript
import { useNGORegistry } from '../hooks/useContracts';

function NGOListComponent() {
  const { allNGOs, verifiedNGOs } = useNGORegistry();

  return (
    <div>
      <h3>Verified NGOs</h3>
      {verifiedNGOs?.map((ngoAddress, index) => (
        <div key={index}>
          <p>NGO Address: {ngoAddress}</p>
        </div>
      ))}
      
      <h3>All NGOs</h3>
      {allNGOs?.map((ngo, index) => (
        <div key={index}>
          <h4>{ngo.name}</h4>
          <p>{ngo.description}</p>
          <p>Website: {ngo.website}</p>
          <p>Verified: {ngo.isVerified ? 'Yes' : 'No'}</p>
          <p>Reputation Score: {ngo.reputationScore.toString()}</p>
        </div>
      ))}
    </div>
  );
}
```

### 5. useUSDC()

Interacts with the USDC token contract for approvals and balance checks.

```typescript
import { useUSDC } from '../hooks/useContracts';
import { useAccount } from 'wagmi';

function USDCComponent() {
  const { address } = useAccount();
  const {
    balance,
    allowance,
    approve,
    isPending
  } = useUSDC();

  const handleApprove = () => {
    approve('1000'); // Approve 1000 USDC for the vault
  };

  return (
    <div>
      <h3>USDC Balance</h3>
      <p>Balance: {balance} USDC</p>
      <p>Allowance: {allowance} USDC</p>
      
      <button onClick={handleApprove} disabled={isPending}>
        {isPending ? 'Approving...' : 'Approve 1000 USDC'}
      </button>
    </div>
  );
}
```

## Complete Integration Example

Here's a complete example component that combines multiple hooks:

```typescript
import React from 'react';
import { useAccount } from 'wagmi';
import { useVault, useUSDC, useNGORegistry, useDonationRouter } from '../hooks/useContracts';

export function GiveProtocolDashboard() {
  const { address, isConnected } = useAccount();
  const vault = useVault();
  const usdc = useUSDC();
  const ngoRegistry = useNGORegistry();
  const donationRouter = useDonationRouter();

  if (!isConnected) {
    return <div>Please connect your wallet</div>;
  }

  return (
    <div className="p-6 max-w-4xl mx-auto">
      <h1 className="text-3xl font-bold mb-6">GIVE Protocol Dashboard</h1>
      
      {/* Wallet Info */}
      <div className="bg-white p-4 rounded-lg shadow mb-6">
        <h2 className="text-xl font-semibold mb-2">Wallet</h2>
        <p>Address: {address}</p>
        <p>USDC Balance: {usdc.balance} USDC</p>
        <p>Vault Allowance: {usdc.allowance} USDC</p>
      </div>
      
      {/* Vault Stats */}
      <div className="bg-white p-4 rounded-lg shadow mb-6">
        <h2 className="text-xl font-semibold mb-2">Vault Statistics</h2>
        <p>Total Assets: {vault.totalAssets} USDC</p>
        <p>Cash Balance: {vault.cashBalance} USDC</p>
        <p>Adapter Assets: {vault.adapterAssets} USDC</p>
      </div>
      
      {/* Actions */}
      <div className="bg-white p-4 rounded-lg shadow mb-6">
        <h2 className="text-xl font-semibold mb-2">Actions</h2>
        <div className="space-x-2">
          <button 
            onClick={() => usdc.approve('1000')}
            disabled={usdc.isPending}
            className="bg-blue-500 text-white px-4 py-2 rounded"
          >
            {usdc.isPending ? 'Approving...' : 'Approve USDC'}
          </button>
          
          <button 
            onClick={() => vault.deposit('100', address!)}
            disabled={vault.isPending}
            className="bg-green-500 text-white px-4 py-2 rounded"
          >
            {vault.isPending ? 'Depositing...' : 'Deposit 100 USDC'}
          </button>
          
          <button 
            onClick={() => vault.harvest()}
            disabled={vault.isPending}
            className="bg-purple-500 text-white px-4 py-2 rounded"
          >
            {vault.isPending ? 'Harvesting...' : 'Harvest Yield'}
          </button>
        </div>
      </div>
      
      {/* NGO List */}
      <div className="bg-white p-4 rounded-lg shadow">
        <h2 className="text-xl font-semibold mb-2">Verified NGOs</h2>
        {ngoRegistry.verifiedNGOs?.map((ngoAddress, index) => (
          <div key={index} className="border-b py-2">
            <p className="font-mono text-sm">{ngoAddress}</p>
          </div>
        ))}
      </div>
    </div>
  );
}
```

## Demo Component

A complete demo component has been created at `/src/components/GiveProtocolDemo.tsx` that showcases all the integrated functionality:

- **Wallet Connection**: Connect/disconnect wallet with RainbowKit
- **Vault Operations**: Deposit, withdraw, and harvest yield
- **Strategy Management**: Harvest and rebalance strategies
- **NGO Registry**: View verified NGOs and distribution stats
- **Real-time Data**: Live updates of balances and contract states

### Accessing the Demo

The demo is available at `/demo` route. You can:

1. Start your development server: `npm run dev`
2. Navigate to `http://localhost:5173/demo`
3. Connect your wallet and interact with the contracts

## Next Steps

1. **Test the Integration**:
   - Visit `/demo` to test all functionality
   - Connect your wallet to Sepolia
   - Try depositing/withdrawing from the vault
   - Test strategy management and NGO interactions

2. **Environment Setup**:
   ```bash
   # Add to your .env file
   VITE_SEPOLIA_RPC=https://rpc.sepolia.org/
   VITE_WALLETCONNECT_PROJECT_ID=your_project_id
   ```

3. **Add Error Handling**:
   - Implement proper error boundaries
   - Add user-friendly error messages
   - Handle network switching

4. **Enhance UI/UX**:
   - Add loading states
   - Implement transaction confirmations
   - Add success/error notifications

5. **Security Considerations**:
   - Validate all user inputs
   - Implement proper access controls
   - Add slippage protection for transactions

## Important Notes

- All amounts are handled in USDC with 6 decimal places
- Make sure users approve USDC spending before depositing
- The vault automatically invests excess cash into the Aave adapter
- Harvest operations distribute yield to the current NGO selected by the registry
- Always check transaction status before allowing new operations