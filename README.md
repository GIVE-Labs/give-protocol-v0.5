# MorphImpact

A DeFi platform that lets you support NGOs by staking crypto instead of donating. You keep your principal, they get the yield.

## The Problem

Traditional NGO donations have issues:
- 30-50% goes to intermediaries
- You lose your money forever
- No transparency in fund usage
- Zero engagement after donating

## How It Works

Instead of giving money away, you stake ETH/USDC on Morph Chain. The yield goes to your chosen NGO, and you get your principal back after the lock period.

**Example:**
- Stake 1 ETH for a verified education NGO
- Choose 75% yield contribution (keep 25%)
- 12-month lock period
- NGO gets ~0.075 ETH in yield, you get 1 ETH back + 0.025 ETH

## Quick Start

### Prerequisites
- Node.js 18+
- Foundry
- MetaMask with Morph Chain

### Setup
```bash
# Install dependencies
cd frontend && pnpm install
cd ../backend && forge install

# Configure
# Copy .env.example to .env.local and add your thirdweb client ID

# Run
cd frontend && pnpm dev
```

## Tech Stack

- **Frontend**: Next.js + thirdweb SDK
- **Contracts**: Foundry + Solidity
- **Chain**: Morph L2
- **Tokens**: ETH, USDC

## Project Structure

```
morphimpact/
├── frontend/          # Next.js web app
├── backend/           # Foundry contracts
├── docs/              # Documentation
└── llm/               # Development notes
```

## Key Features

### For Supporters
- Browse verified NGOs by cause/location
- Stake crypto with configurable yield rates
- Track real-time impact
- Withdraw principal after lock period

### For NGOs
- Register and get verified
- Receive continuous yield funding
- Build supporter communities
- Transparent reporting

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

- ✅ Frontend setup with thirdweb
- 🔄 Smart contracts in development
- 🎯 Morph testnet deployment planned

## Getting Started

1. Clone the repo
2. Install dependencies: `pnpm install`
3. Add your thirdweb client ID to `.env.local`
4. Start the dev server: `pnpm dev`

## Contributing

1. Read docs in `/llm/` for development guidelines
2. Write tests first
3. Follow the established patterns
4. Submit PRs with clear descriptions

---

Built for the Morph Chain Hackathon 2025