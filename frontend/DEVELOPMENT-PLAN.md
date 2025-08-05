# MorphImpact Frontend Development Plan

## Overview
Based on GiveHope patterns, adapted for MorphImpact's DeFi NGO staking platform. Focus on NGO selection, staking with yield contribution, and portfolio tracking.

## Architecture
- **Framework**: React + TypeScript + Vite (migrated from NextJS)
- **Web3**: Wagmi v2 + RainbowKit v2 + Viem
- **Styling**: Tailwind CSS
- **State**: React Query for server state, local state for UI
- **Routing**: React Router v6

## Contract Integration Strategy
1. **NGORegistry**: Display and select verified NGOs
2. **MorphImpactStaking**: Core staking functionality
3. **YieldDistributor**: Track yield distributions
4. **MockYieldVault**: Simulate yield generation
5. **MockUSDC/MockWETH**: Token interactions

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

### 3. Stake Page (`/stake/:ngoId`) - Core Functionality
**Components:**
- NGO details header
- Token selection (USDC/WETH)
- Amount input with balance check
- Yield contribution slider (50%/75%/100%)
- Lock period selection (6/12/24 months)
- Estimated yield preview
- Stake confirmation modal

### 4. Portfolio (`/portfolio`) - User Dashboard
**Components:**
- Active stakes overview
- Total value locked
- Yield generated for NGOs
- Withdrawal countdown timers
- Transaction history
- NGO impact metrics

### 5. NGO Details (`/ngo/:id`) - NGO Information
**Components:**
- NGO profile with verification status
- Current active stakes supporting this NGO
- Total yield received
- Impact stories/metrics
- Stake button

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

### Feature Components
- `NGOCard.tsx` - NGO display card
- `StakingForm.tsx` - Main staking interface
- `StakeSummary.tsx` - Stake details display
- `YieldCalculator.tsx` - Yield estimation
- `ImpactMetrics.tsx` - NGO impact display

## Data Flow

### State Management
- **Global**: Wallet connection, chain info
- **Local**: Form states, selected NGO, amounts
- **Server**: NGO data, user stakes, token balances

### API Endpoints (via contracts)
- `getNGOs()` - Fetch all NGOs
- `getNGO(id)` - Get specific NGO
- `getUserStakes(address)` - User's active stakes
- `getStakeDetails(id)` - Specific stake info
- `getYieldGenerated(ngoId)` - NGO yield metrics

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
- Test staking with mock tokens
- Test withdrawal countdowns
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

### Phase 3: Staking Interface (60 min)
1. Staking form with validation
2. Token selection and approval
3. Yield contribution slider
4. Lock period selection
5. Stake confirmation

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
- NGORegistry: 0x724dc0c1AE0d8559C48D0325Ff4cC8F45FE703De
- MorphImpactStaking: 0xE05473424Df537c9934748890d3D8A5b549da1C0
- YieldDistributor: 0x26C19066b8492D642aDBaFD3C24f104fCeb14DA9
- MockUSDC: 0x44F38B49ddaAE53751BEEb32Eb3b958d950B26e6
- MockWETH: 0x81F5c69b5312aD339144489f2ea5129523437bdC