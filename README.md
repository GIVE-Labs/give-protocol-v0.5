# GIVE Protocol

No-loss giving built on ERC-4626 vaults. Users deposit an asset, keep their principal redeemable, and route realized yield to approved NGOs.

## The Problem

Traditional NGO donations have issues:
- 30-50% goes to intermediaries
- You lose your money forever
- No transparency in fund usage
- Zero engagement after donating

## How It Works

Users deposit into an ERC-4626 vault (e.g., USDC vault). The vault invests via a pluggable adapter (e.g., Aave). Principal stays redeemable as vault shares track totalAssets; only realized profit is harvested and routed to NGOs via a Donation Router.

Example:
- Deposit 1,000 USDC into the USDC GiveVault4626
- Vault keeps a cash buffer and supplies excess to Aave via adapter
- Periodically, `harvest()` realizes profit and donates it to the current NGO
- You can withdraw your principal (subject to available liquidity)

## Quick Start

### Prerequisites
- Node.js 18+
- Foundry
- Wallet with Scroll Sepolia configured

### Setup
```bash
# Install dependencies
cd frontend && pnpm install
cd ../backend && forge install

# Configure
# Copy .env.example to .env.local and add required keys

# Run
cd frontend && pnpm dev
```

## Tech Stack

- Frontend: Next.js + TypeScript + TailwindCSS
- Contracts: Foundry + Solidity (ERC-4626 vault, adapters, registry/router)
- Chain: Scroll Sepolia (test/deploy targets configurable)
- Tokens: Asset-specific vaults (e.g., USDC, wstETH)

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
- **Select your NGO**: Pick from approved organizations
- Transparent harvest/donation events
- Withdraw anytime within liquidity constraints
- Remaining yield goes to protocol treasury for sustainability

### For NGOs
- Apply and get approved in the NGO Registry
- Receive ongoing yield based on user preferences
- Transparent on-chain donation receipts
- Proportional distribution based on user allocations

## Development

### Smart Contracts
```bash
cd backend
forge test          # Run tests
forge build         # Build contracts
forge deploy        # Deploy to testnet
```

### Frontend
```bash
cd frontend
pnpm dev           # Start dev server
pnpm build         # Build for production
```

## Current Status

- ✅ Docs updated for GIVE Protocol architecture
- 🔄 Implementing v0.1: GiveVault4626 + Aave adapter + Registry/Router
- 🎯 Testnet deployment plan after unit/fork tests

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
