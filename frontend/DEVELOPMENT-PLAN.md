# GIVE Protocol Frontend Development Plan

## Overview
Based on GiveHope patterns, adapted for GIVE Protocol’s no-loss giving. Focus on NGO discovery, ERC-4626 deposit/withdraw UX, harvest/donation visibility.

## Architecture
- **Framework**: React + TypeScript + Vite/NextJS
- **Web3**: Wagmi v2 + RainbowKit v2 + Viem
- **Styling**: Tailwind CSS
- **State**: React Query for server state, local state for UI
- **Routing**: React Router v6

## Contract Integration Strategy
1. **GiveVault4626**: ERC-4626 deposit/withdraw + previews
2. **NGORegistry**: Display and validate approved NGOs
3. **DonationRouter**: Show DonationPaid events and NGO receipts
4. **StrategyManager**: Admin/ops panel (gated) for adapter/cash buffer

## Page Structure

### 1. Home Page (`/`) - Hero + NGO Discovery
**Components:**
- Hero section with platform value prop
- Featured NGOs component
- How It Works section (staking process)
- Statistics dashboard

### 2. Discover NGOs (`/discover`) - NGO Selection
**Components:**
- NGO filtering by cause/location
- NGO cards with impact metrics
- NGO detail modal/page
- Connect wallet CTA for non-connected users

### 3. Deposit Page (`/deposit`) - Core Functionality
**Components:**
- NGO selection (single NGO for v0.1)
- Asset selection (per vault; USDC v0.1)
- Amount input with balance check
- ERC-4626 previews (shares, assets)
- Deposit confirmation modal

### 4. Portfolio (`/portfolio`) - User Dashboard
**Components:**
- Vault position overview (shares, estimated assets)
- Total donated (from events)
- Recent harvests/donations
- Transaction history

### 5. NGO Details (`/ngo/:id`) - NGO Information
**Components:**
- NGO profile with verification status
- Total donations received (on-chain)
- Impact stories/metrics
- Deposit button

## Component Structure

### Layout Components
- `Header.tsx` - Navigation with wallet connection
- `Footer.tsx` - Links and social
- `Layout.tsx` - Main layout wrapper

### UI Components
- `Button.tsx` - Reusable button variants
- `Card.tsx` - NGO cards, stake cards
- `Modal.tsx` - Staking modals
- `Input.tsx` - Form inputs
- `Slider.tsx` - Yield contribution slider
- `CountdownTimer.tsx` - Lock period timers
- `TokenSelector.tsx` - USDC/WETH selection
- `LoadingSpinner.tsx` - Loading states

### Web3 Components
- `ConnectWallet.tsx` - Wallet connection button
- `BalanceDisplay.tsx` - Token balances
- `TransactionStatus.tsx` - Transaction feedback
- `ApproveToken.tsx` - Token approval flow
- `VaultPreviews.tsx` - ERC-4626 preview helpers

### Feature Components
- `NGOCard.tsx` - NGO display card
- `DepositForm.tsx` - ERC-4626 deposit interface
- `WithdrawForm.tsx` - ERC-4626 withdraw interface
- `DonationFeed.tsx` - DonationPaid events
- `ImpactMetrics.tsx` - NGO impact display

## Data Flow

### State Management
- **Global**: Wallet connection, chain info
- **Local**: Form states, selected NGO, amounts
- **Server**: NGO data, user stakes, token balances

### Contract Reads
- `getNGOs()` - Fetch all NGOs
- `getNGO(id)` - Get specific NGO
- `balanceOf(address)` - User shares (vault)
- `previewDeposit/previewRedeem` - ERC-4626 previews
- `DonationPaid` events - NGO donation metrics

## Styling Strategy
- Use GiveHope's Tailwind patterns
- Glassmorphism effects for cards
- Gradient backgrounds for hero sections
- Consistent spacing and typography
- Dark mode ready

## Error Handling
- Wallet connection failures
- Insufficient balance checks
- Transaction rejections
- Network switch prompts
- Gas estimation failures

## Testing Strategy
- Run `pnpm dev` after each major component
- Test wallet connection flow
- Test deposit/withdraw with mock tokens
- Test error states

## Development Phases

### Phase 1: Setup & Core Structure (30 min)
1. Update contract addresses
2. Set up routing structure
3. Basic layout components
4. Test `pnpm dev`

### Phase 2: NGO Discovery (45 min)
1. NGO card components
2. NGO listing page
3. NGO detail view
4. Test with real NGO data

### Phase 3: Deposit/Withdraw Interface (60 min)
1. Deposit form with validation
2. Token approval flow
3. ERC-4626 previews
4. Withdraw form and shares view
5. Confirmations and toasts

### Phase 4: Portfolio (45 min)
1. User dashboard layout
2. Active stakes display
3. Withdrawal functionality
4. Transaction history

### Phase 5: Polish & Testing (30 min)
1. Loading states
2. Error handling
3. Mobile responsiveness
4. Final testing

## Quick Commands
```bash
# Start development server
pnpm dev

# Install dependencies if needed
pnpm install

# Check types
pnpm run type-check
```

## Contract Addresses Update
Update these in `frontend/src/config/contracts.ts`:
- GiveVault4626 (USDC): 0x...
- StrategyManager: 0x...
- NGORegistry: 0x...
- DonationRouter: 0x...
