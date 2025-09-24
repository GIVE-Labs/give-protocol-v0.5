# GIVE Protocol

No-loss giving built on ERC-4626 vaults. Users deposit an asset, keep their principal redeemable, and route realized yield to approved campaigns.

## The Problem

Traditional donation platforms have issues:
- 30-50% goes to intermediaries
- You lose your money forever
- No transparency in fund usage
- Zero engagement after donating

## How It Works

Users deposit into an ERC-4626 vault (e.g., USDC vault). The vault invests via a pluggable adapter (e.g., Aave). Principal stays redeemable as vault shares track totalAssets; only realized profit is harvested and routed to campaign payout addresses via the Payout Router.

Example:
- Deposit 1,000 USDC into the USDC GiveVault4626
- Vault keeps a cash buffer and supplies excess to Aave via adapter
- Periodically, `harvest()` realizes profit and routes it to the active campaign
- You can withdraw your principal (subject to available liquidity)

## Quick Start

### Prerequisites
- Node.js 18+ (with pnpm)
- Foundry (forge, cast, anvil)
- Git
- Wallet with Scroll Sepolia configured (for testnet deployment)

### Installation

#### 1. Clone the Repository
```bash
git clone <repository-url>
cd GiveProtocol_MVP
```

#### 2. Install Frontend Dependencies
```bash
cd frontend
pnpm install
```

#### 3. Install Backend Dependencies
```bash
cd ../backend
make install
# or manually: forge install
```

#### 4. Environment Configuration

**Frontend (.env.local):**
```bash
cd frontend
cp .env.example .env.local
# Edit .env.local with your configuration
```

**Backend (.env):**
```bash
cd backend
cp .env.example .env
# Add your private key and API keys:
# DEPLOYER_KEY=your_private_key
# SCROLL_SEPOLIA_RPC_URL=https://sepolia-rpc.scroll.io
# ETHERSCAN_API_KEY=your_etherscan_api_key
```

#### 5. Build and Test
```bash
# Build contracts
cd backend
make build

# Run tests
make test

# Build frontend
cd ../frontend
pnpm build
```

### Development Setup

#### Option A: Full Local Development
```bash
# Terminal 1: Start local blockchain
cd backend
make dev  # Starts Anvil and deploys contracts

# Terminal 2: Start frontend
cd frontend
pnpm dev
```

#### Option B: Manual Setup
```bash
# Terminal 1: Start Anvil
anvil

# Terminal 2: Deploy contracts locally
cd backend
make deploy-local

# Terminal 3: Start frontend
cd frontend
pnpm dev
```

### Deployment

#### Local Deployment
```bash
cd backend
make deploy-local
```

#### Testnet Deployment (Ethereum Sepolia)
```bash
cd backend
# Ensure ETHERSCAN_API_KEY is set in .env
make deploy-sepolia
```

#### Testnet Deployment (Scroll Sepolia)
```bash
cd backend
# Ensure ETHERSCAN_API_KEY is set in .env
make deploy-scroll
```

#### Other Networks
```bash
# Custom network
make deploy NETWORK=custom RPC_URL=your_rpc_url
```

## Tech Stack

- Frontend: Next.js + TypeScript + TailwindCSS + Viem/Wagmi
- Contracts: Foundry + Solidity (ERC-4626 vault, Aave adapters, registry/router)
- Networks: Ethereum Sepolia (deployed), Scroll Sepolia (configurable)
- DeFi Integration: Aave V3 for yield generation
- Tokens: Asset-specific vaults (USDC deployed, wstETH configurable)

## Project Structure

```
.
├── frontend/          # Next.js web app (TypeScript, TailwindCSS)
├── backend/           # Foundry contracts (Solidity)
├── docs/              # Documentation & design notes
├── llm/               # AI collaboration & prompts
└── README.md          # Quick start & overview
```

## Key Features

### For Supporters
- Deposit into simple ERC-4626 vault interface
- Keep principal redeemable; donate only yield
- **Choose your impact**: Select 50%, 75%, or 100% of yield to donate
- **Select your campaign**: Pick from approved causes curated in the registry
- Transparent harvest/donation events
- Withdraw anytime within liquidity constraints
- Remaining yield can return to a beneficiary or the protocol treasury (per preference)

### For Campaign Owners
- Submit campaigns permissionlessly with metadata, curator, and payout address
- Receive ongoing yield based on supporter preferences
- Transparent on-chain donation receipts per epoch
- Attach multiple pre-approved strategies to tailor risk/return profiles

## Development

### Smart Contracts
```bash
cd backend

# Development
make help           # Show all available commands
make build          # Build contracts
make test           # Run tests
make test-fork      # Run fork tests
make format         # Format code
make lint           # Lint code

# Deployment
make deploy-local   # Deploy to local Anvil
make deploy-sepolia # Deploy to Ethereum Sepolia
make deploy-scroll  # Deploy to Scroll Sepolia

# Management
make verify         # Verify contracts on Etherscan
make check-env      # Check environment setup
```

### Frontend
```bash
cd frontend
pnpm dev           # Start dev server
pnpm build         # Build for production
pnpm test          # Run tests
pnpm lint          # Lint code
pnpm type-check    # TypeScript check
```

## Current Status

- ✅ Docs updated for GIVE Protocol architecture
- ✅ Implemented v0.1: GiveVault4626 + Aave adapter + Registry/Router
- ✅ **Deployed to Sepolia testnet** (September 18, 2025)
- ✅ All contracts verified on Etherscan
- 🔄 Frontend integration with testnet deployment
- 🎯 User testing and feedback collection

## Getting Started

1. Clone the repo
2. Install dependencies: `pnpm install`
3. Configure environment: `.env.local` for frontend as needed
4. Start the dev server: `pnpm dev`

## Contributing

1. Read docs in `/docs/SystemRequirements.md` for architecture
2. Write tests first
3. Follow repo guidelines in `AGENTS.md`
4. Submit PRs with clear descriptions

---

Target network: Scroll Sepolia — GIVE Protocol MVP
