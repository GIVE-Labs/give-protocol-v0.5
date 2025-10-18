# GIVE Protocol Frontend

A React + TypeScript frontend for the GIVE Protocol no-loss giving platform.

## 🚀 Quick Start

```bash
# Install dependencies
pnpm install

# Start development server
pnpm dev

# Build for production
pnpm build

# Sync contract ABIs from backend
pnpm sync-abis
```

## 🏗️ Tech Stack

- **Framework**: React + TypeScript + Vite
- **Web3**: Wagmi v2 + RainbowKit + Viem
- **Styling**: Tailwind CSS
- **State**: React Query

## 📋 Contract Integration

### Deployed Addresses (Sepolia)
- **Vault**: `0x2b67de726Fc1Fdc1AE1d34aa89e1d1152C11fA52`
- **StrategyManager**: `0x4aE8717F12b1618Ff68c7de430E53735c4e48F1d`
- **AaveAdapter**: `0x8c6824E4d86fBF849157035407B2418F5f992dB7`
- **NGORegistry**: `0x36Fb53A3d29d1822ec0bA73ae4658185C725F5CC`
- **DonationRouter**: `0x2F86620b005b4Bc215ebeB5d8A9eDfE7eC4Ccfb7`

### Available Hooks
- `useVault()` - Vault deposits, withdrawals, harvesting
- `useStrategyManager()` - Strategy management
- `useNGORegistry()` - NGO registration and lookup
- `useDonationRouter()` - Donation routing and preferences

## 🎯 Key Features

- **Wallet Connection**: RainbowKit integration
- **Vault Operations**: Deposit/withdraw USDC with yield generation
- **NGO Management**: Register and discover NGOs
- **Yield Distribution**: Configure donation percentages (50%, 75%, 100%)
- **Real-time Data**: Live vault statistics and balances

## 📁 Project Structure

```
src/
├── components/     # React components
├── hooks/         # Custom React hooks for contracts
├── config/        # Contract addresses and network config
├── abis/          # Contract ABIs
├── pages/         # Page components
├── types/         # TypeScript type definitions
└── services/      # API and external services
```

## 🔧 Development

### Environment Setup
1. Ensure backend contracts are deployed
2. Update contract addresses in `/src/config/contracts.ts`
3. Connect wallet to Sepolia testnet
4. Get Sepolia ETH and USDC for testing

### Force local contracts (optional)

By default, the frontend uses Sepolia testnet contract addresses. If you need to test against local Anvil contracts, set the environment variable `VITE_USE_LOCAL=true` when starting the dev server.

Example (Linux/macOS):

```bash
VITE_USE_LOCAL=true pnpm dev
```

### Testing the Demo
- Navigate to `/demo` route
- Connect wallet and switch to Sepolia
- Test vault operations and NGO interactions

## 🌐 Networks

- **Development**: Anvil (localhost:8545)
- **Testnet**: Sepolia
- **Production**: TBD

For address updates and deployment info, see the main project's `DEPLOYMENT_ADDRESS_GUIDE.md`.