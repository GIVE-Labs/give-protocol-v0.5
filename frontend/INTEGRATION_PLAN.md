# Frontend Integration Plan – Base Sepolia v0.5

**Objective:** Migrate the legacy Vite + React frontend from MVP v0.4 architecture to v0.5 modular architecture with Base Sepolia deployment.

**Timeline:** 4-6 hours  
**Priority:** HIGH (blocking public testing)

---

## Current State Assessment

### ✅ What's Already Working
- **Tech Stack:** Vite + React + TypeScript + Wagmi v2 + RainbowKit
- **ABI Sync Script:** `pnpm sync-abis` exists in `package.json`
- **Existing Hooks:** Basic Wagmi patterns in `useContracts.ts`
- **Legacy Contracts:** NGORegistry, DonationRouter, GiveVault4626, StrategyManager, AaveAdapter

### ❌ What Needs Updating
- **Contract Addresses:** Still pointing to old Sepolia/Local (not Base Sepolia)
- **ABIs:** 5 old contract ABIs, missing 4 new v0.5 contracts
- **Architecture Mismatch:** Frontend assumes MVP v0.4 (NGO-centric) vs v0.5 (Campaign-centric)
- **Missing Contracts:** ACLManager, CampaignRegistry, StrategyRegistry, PayoutRouter, CampaignVaultFactory

### 🔄 Migration Strategy
**Approach:** Incremental update (preserve working code, add v0.5 alongside MVP)
- Keep existing MVP hooks functional (for reference)
- Add new v0.5 hooks in parallel
- Update config to use Base Sepolia addresses
- Create new campaign-centric UI components
- Deprecate old components gradually

---

## Phase 1 – Configuration Update (30 min)

### Task 1.1: Add Base Sepolia Network Config
**File:** `src/config/baseSepolia.ts` (new)

```typescript
export const BASE_SEPOLIA_ADDRESSES = {
  // Core Governance
  ACL_MANAGER: '0xC6454Ec62f53823692f426F1fb4Daa57c184A36A',
  GIVE_PROTOCOL_CORE: '0xB73B90207D6Fe0e44A090002bf4e2e9aA37564D9',
  
  // Registries
  CAMPAIGN_REGISTRY: '0x51929ec1C089463fBeF6148B86F34117D9CCF816',
  STRATEGY_REGISTRY: '0xA31D2D9dc6E58568B65AA3643B1076C6a48De6FC',
  
  // Payout & Factory
  PAYOUT_ROUTER: '0xe1BD0BA2e0891c95Bd02eA248f8115E7c7DC37c5',
  CAMPAIGN_VAULT_FACTORY: '0x2ff82c02775550e038787E4403687e1Fe24E2B44',
  
  // Vaults
  GIVE_WETH_VAULT: '0x28ac6D6505E2875FFF9E13d1B788A8d4740a7278',
  CAMPAIGN_VAULT_IMPL: '0x9db2a61a2Ea9Eb4bb52AE9c5135BB7264bD29615',
  
  // Adapters
  MOCK_YIELD_ADAPTER: '0x31fAf52536FC9c4DaA224fb8AB76868DE4731A0E',
  
  // Tokens
  WETH: '0x4200000000000000000000000000000000000006',
  
  // Legacy (deprecated)
  NGO_REGISTRY: '0x0000000000000000000000000000000000000000', // Not deployed
  DONATION_ROUTER: '0x0000000000000000000000000000000000000000', // Replaced by PayoutRouter
} as const;

export const BASE_SEPOLIA_CONFIG = {
  chainId: 84532,
  name: 'Base Sepolia',
  rpcUrl: 'https://base-sepolia.g.alchemy.com/v2/...',
  blockExplorer: 'https://sepolia.basescan.org',
  contracts: BASE_SEPOLIA_ADDRESSES,
} as const;
```

### Task 1.2: Update `src/config/contracts.ts`
**Changes:**
1. Import Base Sepolia config
2. Add Base Sepolia to `NETWORK_CONFIG`
3. Update default to Base Sepolia (not Sepolia mainnet)
4. Add environment variable `VITE_USE_BASE_SEPOLIA=true`

```typescript
import { BASE_SEPOLIA_CONFIG } from './baseSepolia';

export const NETWORK_CONFIG = {
  LOCAL: { /* ... */ },
  SEPOLIA: { /* ... */ },
  BASE_SEPOLIA: BASE_SEPOLIA_CONFIG, // NEW
} as const;

const useBaseSepolia = import.meta.env.VITE_USE_BASE_SEPOLIA !== 'false'; // Default to Base Sepolia

export const CONTRACT_ADDRESSES = useBaseSepolia
  ? BASE_SEPOLIA_CONFIG.contracts
  : /* fallback logic */;
```

### Task 1.3: Update `.env` file
```env
# Base Sepolia (Default)
VITE_USE_BASE_SEPOLIA=true
VITE_ALCHEMY_API_KEY=your_alchemy_key_here

# Deprecated
VITE_USE_LOCAL=false
```

### Task 1.4: Update `src/config/web3.ts` (Wagmi/RainbowKit config)
**Add Base Sepolia chain:**
```typescript
import { baseSepolia } from 'wagmi/chains';

export const config = createConfig({
  chains: [baseSepolia], // Replace sepolia with baseSepolia
  transports: {
    [baseSepolia.id]: http(), // Auto-detects RPC
  },
  // ... rest
});
```

**Checklist:**
- [ ] Create `src/config/baseSepolia.ts` with all deployed addresses
- [ ] Update `src/config/contracts.ts` to support Base Sepolia
- [ ] Update `.env` with `VITE_USE_BASE_SEPOLIA=true`
- [ ] Update `src/config/web3.ts` to use `baseSepolia` chain
- [ ] Test config loads correctly (`pnpm dev`)

---

## Phase 2 – ABI Synchronization (45 min)

### Task 2.1: Update `sync-abis` Script in `package.json`
**Current script:** Only syncs 5 MVP contracts  
**New script:** Sync all 9 v0.5 contracts

```json
{
  "scripts": {
    "sync-abis": "cd ../backend && forge inspect ACLManager abi > ../frontend/src/abis/ACLManager.json && forge inspect GiveProtocolCore abi > ../frontend/src/abis/GiveProtocolCore.json && forge inspect CampaignRegistry abi > ../frontend/src/abis/CampaignRegistry.json && forge inspect StrategyRegistry abi > ../frontend/src/abis/StrategyRegistry.json && forge inspect PayoutRouter abi > ../frontend/src/abis/PayoutRouter.json && forge inspect CampaignVaultFactory abi > ../frontend/src/abis/CampaignVaultFactory.json && forge inspect GiveVault4626 abi > ../frontend/src/abis/GiveVault4626.json && forge inspect CampaignVault4626 abi > ../frontend/src/abis/CampaignVault4626.json && forge inspect MockYieldAdapter abi > ../frontend/src/abis/MockYieldAdapter.json"
  }
}
```

**Better approach (Bash script):**
Create `scripts/sync-abis.sh`:
```bash
#!/bin/bash
set -e

BACKEND_DIR="../backend"
ABI_DIR="../frontend/src/abis"

echo "🔄 Syncing ABIs from backend..."

contracts=(
  "ACLManager"
  "GiveProtocolCore"
  "CampaignRegistry"
  "StrategyRegistry"
  "PayoutRouter"
  "CampaignVaultFactory"
  "GiveVault4626"
  "CampaignVault4626"
  "MockYieldAdapter"
)

for contract in "${contracts[@]}"; do
  echo "  📄 $contract"
  cd "$BACKEND_DIR" && forge inspect "$contract" abi > "$ABI_DIR/$contract.json"
done

echo "✅ ABIs synced successfully!"
```

### Task 2.2: Run ABI Sync
```bash
cd frontend
chmod +x scripts/sync-abis.sh
pnpm sync-abis
# or
bash scripts/sync-abis.sh
```

### Task 2.3: Verify ABI Files
**Expected files in `src/abis/`:**
- [x] ACLManager.json (NEW)
- [x] GiveProtocolCore.json (NEW)
- [x] CampaignRegistry.json (NEW)
- [x] StrategyRegistry.json (NEW)
- [x] PayoutRouter.json (NEW)
- [x] CampaignVaultFactory.json (NEW)
- [x] GiveVault4626.json (UPDATED)
- [x] CampaignVault4626.json (NEW)
- [x] MockYieldAdapter.json (NEW)
- [ ] DonationRouter.json (DEPRECATED – keep for reference)
- [ ] NGORegistry.json (DEPRECATED – keep for reference)
- [ ] StrategyManager.json (DEPRECATED – merged into StrategyRegistry)
- [ ] AaveAdapter.json (DEPRECATED – using MockYieldAdapter)

**Checklist:**
- [ ] Create `scripts/sync-abis.sh` bash script
- [ ] Update `package.json` `sync-abis` to use bash script
- [ ] Run `pnpm sync-abis` and verify 9 new JSON files
- [ ] Commit ABIs to git (track contract interface changes)

---

## Phase 3 – Wagmi Hooks (v0.5 Architecture) (90 min)

### Task 3.1: Create `src/hooks/v05/` Directory Structure
```
src/hooks/v05/
├── useACL.ts              # Role management
├── useCampaignRegistry.ts # Campaign CRUD + voting
├── useStrategyRegistry.ts # Strategy metadata
├── usePayoutRouter.ts     # Payout preferences
├── useVaultFactory.ts     # Campaign vault creation
├── useGiveVault.ts        # WETH vault operations
├── useCampaignVault.ts    # Campaign-specific vault
├── useYieldAdapter.ts     # Adapter interactions
└── index.ts               # Re-export all hooks
```

### Task 3.2: Implement Core Hooks

#### `useGiveVault.ts` (WETH Vault Operations)
**Priority:** HIGH (needed for deposit testing)

```typescript
import { useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { parseUnits, formatUnits } from 'viem';
import { BASE_SEPOLIA_ADDRESSES } from '../../config/baseSepolia';
import GiveVault4626ABI from '../../abis/GiveVault4626.json';

export function useGiveVault(vaultAddress?: `0x${string}`) {
  const address = vaultAddress || BASE_SEPOLIA_ADDRESSES.GIVE_WETH_VAULT;
  
  const { writeContract, data: hash, isPending } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  // Read: Vault stats
  const { data: totalAssets } = useReadContract({
    address,
    abi: GiveVault4626ABI,
    functionName: 'totalAssets',
  });

  const { data: totalSupply } = useReadContract({
    address,
    abi: GiveVault4626ABI,
    functionName: 'totalSupply',
  });

  const { data: sharePrice } = useReadContract({
    address,
    abi: GiveVault4626ABI,
    functionName: 'convertToAssets',
    args: [parseUnits('1', 18)], // 1 share in wei
  });

  // Read: User balance
  const getUserBalance = (userAddress?: `0x${string}`) => {
    return useReadContract({
      address,
      abi: GiveVault4626ABI,
      functionName: 'balanceOf',
      args: userAddress ? [userAddress] : undefined,
      query: { enabled: !!userAddress },
    });
  };

  // Read: Adapter stats
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

  // Write: Deposit
  const deposit = async (assets: bigint, receiver: `0x${string}`) => {
    return writeContract({
      address,
      abi: GiveVault4626ABI,
      functionName: 'deposit',
      args: [assets, receiver],
    });
  };

  // Write: Withdraw
  const withdraw = async (assets: bigint, receiver: `0x${string}`, owner: `0x${string}`) => {
    return writeContract({
      address,
      abi: GiveVault4626ABI,
      functionName: 'withdraw',
      args: [assets, receiver, owner],
    });
  };

  // Write: Harvest
  const harvest = async () => {
    return writeContract({
      address,
      abi: GiveVault4626ABI,
      functionName: 'harvest',
    });
  };

  return {
    // Read data (formatted)
    totalAssets: totalAssets ? formatUnits(totalAssets as bigint, 18) : '0',
    totalSupply: totalSupply ? formatUnits(totalSupply as bigint, 18) : '0',
    sharePrice: sharePrice ? formatUnits(sharePrice as bigint, 18) : '1',
    adapterAssets: adapterAssets ? formatUnits(adapterAssets as bigint, 18) : '0',
    cashBalance: cashBalance ? formatUnits(cashBalance as bigint, 18) : '0',
    // Write functions
    deposit,
    withdraw,
    harvest,
    getUserBalance,
    // Transaction state
    isPending,
    isConfirming,
    isSuccess,
    hash,
  };
}
```

#### `useCampaignRegistry.ts` (Campaign Management)
**Priority:** MEDIUM (needed for campaign listing)

```typescript
import { useReadContract, useWriteContract } from 'wagmi';
import { BASE_SEPOLIA_ADDRESSES } from '../../config/baseSepolia';
import CampaignRegistryABI from '../../abis/CampaignRegistry.json';

export function useCampaignRegistry() {
  const { writeContract, data: hash, isPending } = useWriteContract();

  // Read: Get campaign count
  const { data: campaignCount } = useReadContract({
    address: BASE_SEPOLIA_ADDRESSES.CAMPAIGN_REGISTRY,
    abi: CampaignRegistryABI,
    functionName: 'getCampaignCount',
  });

  // Read: Get campaign by ID
  const getCampaign = (campaignId: bigint) => {
    return useReadContract({
      address: BASE_SEPOLIA_ADDRESSES.CAMPAIGN_REGISTRY,
      abi: CampaignRegistryABI,
      functionName: 'campaigns',
      args: [campaignId],
    });
  };

  // Read: Get all active campaigns
  const { data: activeCampaigns } = useReadContract({
    address: BASE_SEPOLIA_ADDRESSES.CAMPAIGN_REGISTRY,
    abi: CampaignRegistryABI,
    functionName: 'getActiveCampaigns',
  });

  // Write: Submit campaign
  const submitCampaign = async (
    name: string,
    metadataCid: string,
    recipient: `0x${string}`,
    strategyId: bigint
  ) => {
    return writeContract({
      address: BASE_SEPOLIA_ADDRESSES.CAMPAIGN_REGISTRY,
      abi: CampaignRegistryABI,
      functionName: 'submitCampaign',
      args: [name, metadataCid, recipient, strategyId],
    });
  };

  // Write: Vote on checkpoint
  const voteOnCheckpoint = async (
    campaignId: bigint,
    checkpointId: bigint,
    support: boolean
  ) => {
    return writeContract({
      address: BASE_SEPOLIA_ADDRESSES.CAMPAIGN_REGISTRY,
      abi: CampaignRegistryABI,
      functionName: 'voteOnCheckpoint',
      args: [campaignId, checkpointId, support],
    });
  };

  return {
    campaignCount,
    activeCampaigns,
    getCampaign,
    submitCampaign,
    voteOnCheckpoint,
    isPending,
    hash,
  };
}
```

#### `usePayoutRouter.ts` (Payout Preferences)
**Priority:** HIGH (needed for yield allocation)

```typescript
import { useReadContract, useWriteContract } from 'wagmi';
import { BASE_SEPOLIA_ADDRESSES } from '../../config/baseSepolia';
import PayoutRouterABI from '../../abis/PayoutRouter.json';

export function usePayoutRouter() {
  const { writeContract, data: hash, isPending } = useWriteContract();

  // Read: Get user's payout preference
  const getPreference = (vaultId: bigint, userAddress?: `0x${string}`) => {
    return useReadContract({
      address: BASE_SEPOLIA_ADDRESSES.PAYOUT_ROUTER,
      abi: PayoutRouterABI,
      functionName: 'payoutPreferences',
      args: userAddress ? [vaultId, userAddress] : undefined,
      query: { enabled: !!userAddress },
    });
  };

  // Write: Set payout preference
  const setPreference = async (
    vaultId: bigint,
    campaignId: bigint,
    beneficiary: `0x${string}`,
    allocationBps: number // 0-10000 (100% = 10000)
  ) => {
    return writeContract({
      address: BASE_SEPOLIA_ADDRESSES.PAYOUT_ROUTER,
      abi: PayoutRouterABI,
      functionName: 'setPayoutPreference',
      args: [vaultId, campaignId, beneficiary, BigInt(allocationBps)],
    });
  };

  return {
    getPreference,
    setPreference,
    isPending,
    hash,
  };
}
```

### Task 3.3: Create Hook Index File
**File:** `src/hooks/v05/index.ts`

```typescript
export { useGiveVault } from './useGiveVault';
export { useCampaignRegistry } from './useCampaignRegistry';
export { useStrategyRegistry } from './useStrategyRegistry';
export { usePayoutRouter } from './usePayoutRouter';
export { useVaultFactory } from './useVaultFactory';
export { useCampaignVault } from './useCampaignVault';
export { useYieldAdapter } from './useYieldAdapter';
export { useACL } from './useACL';
```

**Checklist:**
- [ ] Create `src/hooks/v05/` directory
- [ ] Implement `useGiveVault.ts` (deposit/withdraw/harvest)
- [ ] Implement `useCampaignRegistry.ts` (list/submit/vote)
- [ ] Implement `usePayoutRouter.ts` (preferences)
- [ ] Implement `useVaultFactory.ts` (create campaign vaults)
- [ ] Implement `useCampaignVault.ts` (campaign-specific operations)
- [ ] Implement `useYieldAdapter.ts` (adapter stats)
- [ ] Create `index.ts` re-export file
- [ ] Test hooks with `pnpm dev` (no TypeScript errors)

---

## Phase 4 – UI Component Updates (60 min)

### Task 4.1: Create Campaign-Centric Components
**New components needed:**

#### `src/components/campaign/CampaignCard.tsx`
**Purpose:** Display individual campaign with donate button

```tsx
import { useCampaignRegistry } from '../../hooks/v05';
import { usePayoutRouter } from '../../hooks/v05';

export function CampaignCard({ campaignId }: { campaignId: bigint }) {
  const { getCampaign } = useCampaignRegistry();
  const { data: campaign } = getCampaign(campaignId);
  const { setPreference } = usePayoutRouter();

  const handleDonate = async () => {
    // Set 100% allocation to this campaign
    await setPreference(
      BigInt(1), // vaultId (GIVE WETH Vault)
      campaignId,
      campaign.recipient,
      10000 // 100%
    );
  };

  return (
    <Card>
      <h3>{campaign?.name}</h3>
      <p>Recipient: {campaign?.recipient}</p>
      <Button onClick={handleDonate}>Donate Yield</Button>
    </Card>
  );
}
```

#### `src/components/vault/VaultDepositForm.tsx`
**Purpose:** Deposit WETH to vault with approval flow

```tsx
import { useState } from 'react';
import { useAccount } from 'wagmi';
import { parseUnits } from 'viem';
import { useGiveVault } from '../../hooks/v05';
import { useWETH } from '../../hooks/useWETH'; // Need to create

export function VaultDepositForm() {
  const { address } = useAccount();
  const { deposit, isPending } = useGiveVault();
  const { approve, allowance } = useWETH();
  const [amount, setAmount] = useState('');

  const handleDeposit = async () => {
    if (!address) return;
    
    const assets = parseUnits(amount, 18); // WETH has 18 decimals
    
    // Check allowance
    const currentAllowance = parseUnits(allowance, 18);
    if (currentAllowance < assets) {
      // Approve first
      await approve(amount);
      // Wait for approval confirmation, then deposit
      return;
    }
    
    // Deposit
    await deposit(assets, address);
  };

  return (
    <form onSubmit={(e) => { e.preventDefault(); handleDeposit(); }}>
      <input
        type="number"
        value={amount}
        onChange={(e) => setAmount(e.target.value)}
        placeholder="0.1"
        step="0.01"
      />
      <button type="submit" disabled={isPending}>
        {isPending ? 'Processing...' : 'Deposit WETH'}
      </button>
    </form>
  );
}
```

#### `src/components/vault/VaultStats.tsx`
**Purpose:** Display vault TVL, APY, share price

```tsx
import { useGiveVault } from '../../hooks/v05';

export function VaultStats() {
  const { totalAssets, totalSupply, sharePrice, adapterAssets, cashBalance } = useGiveVault();

  return (
    <div className="grid grid-cols-2 gap-4">
      <Stat label="Total Assets" value={`${totalAssets} WETH`} />
      <Stat label="Total Shares" value={totalSupply} />
      <Stat label="Share Price" value={sharePrice} />
      <Stat label="Invested (Adapter)" value={`${adapterAssets} WETH`} />
      <Stat label="Cash Buffer" value={`${cashBalance} WETH`} />
    </div>
  );
}
```

### Task 4.2: Update Pages

#### Update `src/pages/Home.tsx`
**Changes:**
- Replace NGO list with Campaign list
- Use `useCampaignRegistry()` instead of `useNGORegistry()`
- Update hero section to mention Base Sepolia testnet

#### Update `src/pages/Dashboard.tsx`
**Changes:**
- Show WETH vault balance (not USDC)
- Display payout preferences
- Show yield earned
- Add "Deposit More" and "Withdraw" buttons

#### Create `src/pages/Campaigns.tsx` (NEW)
**Purpose:** Browse all campaigns, filter by active/completed

```tsx
import { useCampaignRegistry } from '../hooks/v05';
import { CampaignCard } from '../components/campaign/CampaignCard';

export function Campaigns() {
  const { activeCampaigns } = useCampaignRegistry();

  return (
    <div>
      <h1>Active Campaigns</h1>
      <div className="grid grid-cols-3 gap-4">
        {activeCampaigns?.map((id) => (
          <CampaignCard key={id.toString()} campaignId={id} />
        ))}
      </div>
    </div>
  );
}
```

**Checklist:**
- [ ] Create `src/components/campaign/CampaignCard.tsx`
- [ ] Create `src/components/vault/VaultDepositForm.tsx`
- [ ] Create `src/components/vault/VaultStats.tsx`
- [ ] Create `src/hooks/useWETH.ts` (WETH approve/balance)
- [ ] Update `src/pages/Home.tsx` for v0.5
- [ ] Update `src/pages/Dashboard.tsx` for WETH vault
- [ ] Create `src/pages/Campaigns.tsx` (campaign browser)
- [ ] Update `src/App.tsx` routing to include `/campaigns`

---

## Phase 5 – Testing & Debugging (90 min)

### Task 5.1: Local Development Testing
```bash
cd frontend
pnpm install
pnpm dev
```

**Manual test checklist:**
- [ ] App loads without errors
- [ ] RainbowKit connects to Base Sepolia
- [ ] Wallet connection works (MetaMask/Rainbow/Coinbase)
- [ ] Campaign list loads from `CampaignRegistry`
- [ ] Vault stats display correctly
- [ ] WETH balance shows in wallet
- [ ] Approve WETH flow works
- [ ] Deposit WETH to vault succeeds
- [ ] Share balance updates after deposit
- [ ] Payout preference can be set
- [ ] Withdraw WETH from vault works
- [ ] Transaction history visible (Basescan links)

### Task 5.2: Contract Interaction Testing

#### Test Deposit Flow
1. Wrap ETH → WETH via WETH contract
2. Approve WETH to vault
3. Deposit WETH to vault
4. Verify shares minted
5. Check adapter received 99%
6. Confirm 1% cash buffer

#### Test Payout Preferences
1. Select a campaign
2. Set 100% allocation
3. Verify on-chain via `cast call`
4. Change to 50% allocation
5. Verify update

#### Test Withdrawal
1. Withdraw 50% of shares
2. Verify WETH received
3. Check adapter balance decreased
4. Confirm share balance updated

### Task 5.3: Error Handling
**Common errors to handle:**
- User rejects transaction → Show friendly message
- Insufficient WETH balance → Show "Wrap ETH first"
- Insufficient allowance → Trigger approve flow
- Network mismatch → Prompt to switch to Base Sepolia
- RPC timeout → Retry with exponential backoff

**Implementation:**
```tsx
// src/utils/errorHandler.ts
export function handleTxError(error: any): string {
  if (error.message?.includes('user rejected')) {
    return 'Transaction cancelled by user';
  }
  if (error.message?.includes('insufficient funds')) {
    return 'Insufficient WETH balance. Wrap ETH first.';
  }
  if (error.message?.includes('allowance')) {
    return 'Please approve WETH spending first';
  }
  return error.message || 'Transaction failed';
}
```

**Checklist:**
- [ ] Test full deposit flow end-to-end
- [ ] Test payout preference update
- [ ] Test withdrawal flow
- [ ] Test error cases (reject, insufficient balance)
- [ ] Verify gas estimates are reasonable
- [ ] Check transaction receipts on Basescan
- [ ] Test mobile responsiveness (Chrome DevTools)

---

## Phase 6 – Deployment to Vercel (45 min)

### Task 6.1: Prepare for Production
**Environment variables:**
Create `frontend/.env.production`:
```env
VITE_USE_BASE_SEPOLIA=true
VITE_ALCHEMY_API_KEY=production_key_here
VITE_WALLETCONNECT_PROJECT_ID=your_project_id
```

**Build test:**
```bash
cd frontend
pnpm build
pnpm preview
# Test built app on http://localhost:4173
```

### Task 6.2: Deploy to Vercel
**Option A: Vercel CLI**
```bash
npm i -g vercel
cd frontend
vercel --prod
```

**Option B: GitHub Integration**
1. Push to GitHub (`v-0.5` branch)
2. Connect repo to Vercel
3. Configure build settings:
   - Framework: Vite
   - Build Command: `pnpm build`
   - Output Directory: `dist`
   - Root Directory: `frontend`
4. Add environment variables in Vercel dashboard
5. Deploy

### Task 6.3: Post-Deployment Verification
**Test on production URL:**
- [ ] App loads (no 404s)
- [ ] Assets load correctly (images, fonts)
- [ ] RainbowKit modal works
- [ ] Contract reads work (campaign list)
- [ ] Contract writes work (deposit)
- [ ] Mobile view works (iOS Safari, Android Chrome)
- [ ] Share link with team for feedback

### Task 6.4: Update Documentation
**Update `frontend/README.md`:**
```markdown
# GIVE Protocol Frontend – v0.5 (Base Sepolia)

**Live URL:** https://give-protocol-v05.vercel.app

## Features
- WETH vault deposits/withdrawals
- Campaign browsing and yield allocation
- Payout preference management
- Checkpoint voting (coming soon)

## Local Development
```bash
pnpm install
pnpm dev # http://localhost:5173
```

## Tech Stack
- Vite + React 18
- Wagmi v2 + RainbowKit
- Base Sepolia testnet
- TailwindCSS + Framer Motion
```

**Checklist:**
- [ ] Build passes without errors
- [ ] Preview local build works
- [ ] Deploy to Vercel successfully
- [ ] Test production URL
- [ ] Update README with live link
- [ ] Share with community (Discord, Twitter)

---

## Phase 7 – Public Testing Period (Ongoing)

### Task 7.1: Share Links
**Channels:**
- [ ] Discord announcement with:
  - Live URL
  - Base Sepolia faucet links
  - WETH wrapper contract
  - Basescan contract links
  - Test scenario guide
- [ ] Twitter thread showcasing deposit flow
- [ ] GitHub README badge "Live on Base Sepolia"

### Task 7.2: Monitor Issues
**Setup monitoring:**
- [ ] Vercel Analytics (free tier)
- [ ] Sentry error tracking (optional)
- [ ] Discord feedback channel
- [ ] GitHub Issues for bug reports

### Task 7.3: Collect Feedback
**Focus areas:**
- UX friction points (confusing flows)
- Missing features (expected but not present)
- Gas cost concerns
- Mobile experience issues
- Error message clarity

### Task 7.4: Iterate Quickly
**Weekly sprints:**
- Week 1: Fix critical bugs, improve deposit UX
- Week 2: Add campaign creation flow
- Week 3: Implement checkpoint voting UI
- Week 4: Add portfolio analytics

---

## Success Metrics

### Phase 1-2 (Config + ABIs)
- ✅ All 9 ABIs synced
- ✅ Base Sepolia config active
- ✅ No TypeScript errors

### Phase 3 (Hooks)
- ✅ 8 v0.5 hooks implemented
- ✅ Type-safe contract calls
- ✅ Transaction state handling

### Phase 4 (UI)
- ✅ Campaign list renders
- ✅ Vault deposit form works
- ✅ Payout preferences UI complete

### Phase 5 (Testing)
- ✅ End-to-end deposit flow tested
- ✅ Withdrawal flow tested
- ✅ Error cases handled gracefully

### Phase 6 (Deployment)
- ✅ Production build succeeds
- ✅ Vercel deployment live
- ✅ Mobile responsive

### Phase 7 (Public Testing)
- 🎯 10+ community testers
- 🎯 50+ testnet deposits
- 🎯 <5 critical bugs reported
- 🎯 Positive feedback on UX

---

## Risk Mitigation

### High Risk
**Contract address mismatch** → Double-check all addresses against `DEPLOYMENT.md`  
**ABI version mismatch** → Always sync ABIs after backend changes  
**Network config error** → Test Base Sepolia RPC connectivity before deployment

### Medium Risk
**Gas estimation failures** → Use fixed gas limits for complex transactions  
**Wallet connection issues** → Test with MetaMask, Rainbow, Coinbase Wallet  
**Mobile safari bugs** → Test on real iOS device before launch

### Low Risk
**Vercel build failures** → Test `pnpm build` locally first  
**Image optimization** → Use Next.js Image for auto-optimization (future migration)  
**Analytics not loading** → Use client-side rendering for analytics scripts

---

## Timeline & Ownership

| Phase | Duration | Owner | Blocker |
|-------|----------|-------|---------|
| 1. Config Update | 30 min | Dev | None |
| 2. ABI Sync | 45 min | Dev | Backend ABIs ready ✅ |
| 3. Wagmi Hooks | 90 min | Dev | ABIs synced |
| 4. UI Components | 60 min | Dev | Hooks complete |
| 5. Testing | 90 min | Dev + QA | UI complete |
| 6. Deployment | 45 min | Dev | Tests pass |
| 7. Public Testing | Ongoing | Community | Deployment live |

**Total Estimated Time:** 6 hours (active development)  
**Total Elapsed Time:** 2-3 days (with testing feedback loop)

---

## Rollback Plan

**If critical issues found after deployment:**

1. **Immediate:** Revert to previous Vercel deployment (1-click in dashboard)
2. **Short-term:** Fix bugs locally, redeploy to preview URL first
3. **Long-term:** Add Cypress E2E tests to prevent regression

**Rollback triggers:**
- Unable to connect wallet
- Contract reads fail (wrong network)
- Deposit transaction reverts unexpectedly
- UI completely broken on mobile

---

## Next Steps After Integration

**Phase 18 – Pre-Mainnet Finalization:**
- [ ] Third-party security audit (if budget permits)
- [ ] Bug bounty program (ImmuneFi)
- [ ] Mainnet deployment plan
- [ ] Marketing campaign for mainnet launch

**Phase 19 – Ecosystem Growth:**
- [ ] SDK for developers
- [ ] Subgraph for indexed data
- [ ] Mobile app (React Native)
- [ ] L2 expansion (Arbitrum, Optimism)

---

**Last Updated:** October 24, 2025  
**Status:** 🟡 In Progress (Phase 1 starting)  
**Blocker:** None – ready to begin!
