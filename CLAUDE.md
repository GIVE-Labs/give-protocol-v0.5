# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**MorphImpact** - A DeFi NGO fundraising platform on Morph Chain that revolutionizes charitable giving through yield generation.

**Core Value Proposition**: Instead of traditional donations where you lose your principal forever, users stake ETH/USDC on Morph Chain on behalf of verified NGOs. Users select yield contribution rates (50%, 75%, or 100%) and lock periods (6, 12, or 24 months), then withdraw their full principal after the period while NGOs receive continuous yield funding.

## Technology Stack

- **Frontend**: NextJS + Vite with full web3 functionality
- **Backend**: Foundry smart contracts
- **Package Manager**: pnpm (MUST use - no Yarn or npm allowed)
- **Project Structure**:
  ```
  ├── frontend/           # NextJS + Vite web3 frontend
  ├── backend/            # Foundry smart contracts
  ├── llm/               # LLM collaboration files
  ├── pnpm-workspace.yaml # pnpm workspace configuration
  └── package.json       # Root package.json
  ```

## Multi-LLM Collaboration Rules

### Critical Rules for Claude

1. **ALWAYS check changelog**: Read `llm/LLM-CHANGELOG.md` on startup to understand what has been changed
2. **Log ALL changes**: Every code change, fix, or instruction must be logged in `llm/LLM-CHANGELOG.md` with format: `claude-sonnet-4-20250514 YYYY-MM-DD HH:MM:SS UTC description`
3. **Update master rules**: When updating instructions, update both this file AND `llm/LLM-INSTRUCTIONS.md`
4. **Follow master instructions**: All work must align with `llm/LLM-INSTRUCTIONS.md`

### Change Logging Protocol
- **When to log**: Code changes, bug fixes, new features, architecture decisions, configuration updates
- **Format**: `claude-sonnet-4-20250514 2025-08-04 08:55:00 UTC Created initial project structure`
- **Location**: `llm/LLM-CHANGELOG.md`

## Development Setup

### Initial Project Setup
Since this is a fresh workspace, initialize with:

1. **Initialize project root**:
   ```bash
   pnpm init
   ```

2. **Set up pnpm workspace**:
   ```bash
   # Create pnpm-workspace.yaml
   echo "packages:
     - 'frontend'
     - 'backend'" > pnpm-workspace.yaml
   ```

3. **Initialize frontend** (NextJS + Vite):
   ```bash
   mkdir frontend
   cd frontend
   pnpm create vite@latest . --template react-ts
   # Add NextJS dependencies
   pnpm add next@latest react@latest react-dom@latest
   ```

4. **Initialize backend** (Foundry):
   ```bash
   mkdir backend
   cd backend
   forge init
   ```

### Common Commands (to be added as implemented)
- `pnpm dev` - Start development servers
- `pnpm build` - Build for production
- `pnpm test` - Run tests
- `pnpm lint` - Run linter
- `pnpm format` - Format code

## Core Features to Implement

### Smart Contract Layer (backend/)
1. **Staking Contract**: Handle ETH/USDC staking
2. **Yield Distribution**: Manage yield contribution percentages
3. **Time Locking**: Implement 6/12/24 month periods
4. **NGO Registry**: Track supported NGOs
5. **Principal Return**: Ensure principal can be returned

### Frontend Layer (frontend/)
1. **NGO Selection Interface**: Browse and select NGOs
2. **Staking Dashboard**: Connect wallet and stake crypto
3. **Yield Contribution Selector**: Choose 50%/75%/100%
4. **Time Period Selection**: Choose 6/12/24 months
5. **Portfolio Tracking**: Monitor stakes and yields
6. **Web3 Integration**: Wallet connection and contract interaction

## Getting Started Checklist

- [ ] Initialize pnpm workspace
- [ ] Set up frontend with NextJS + Vite
- [ ] Set up backend with Foundry
- [ ] Create basic smart contract structure
- [ ] Set up web3 frontend integration
- [ ] Implement NGO selection interface
- [ ] Implement staking mechanism
- [ ] Add yield contribution logic
- [ ] Add time period selection
- [ ] Test end-to-end flow

## Next Steps

1. Initialize the project structure as outlined above
2. Set up the pnpm workspace
3. Begin with basic smart contract development in backend/
4. Set up frontend with web3 connectivity
5. Implement core staking and yield contribution features

Remember to log all changes in `llm/LLM-CHANGELOG.md` as you work!