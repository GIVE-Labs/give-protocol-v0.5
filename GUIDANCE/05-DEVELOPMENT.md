# Development Guide - GIVE Protocol

## 🚀 Getting Started

### **Prerequisites**

Before you begin, ensure you have the following installed:

- **Node.js 18+** - [Download](https://nodejs.org/)
- **pnpm** - `npm install -g pnpm` (required, no yarn/npm)
- **Foundry** - `curl -L https://foundry.paradigm.xyz | bash`
- **Git** - [Download](https://git-scm.com/)
- **VS Code** (recommended) - [Download](https://code.visualstudio.com/)

## 🌐 Latest Development Infrastructure
- Makefile supports multi-network deployment (Sepolia, Scroll Sepolia, local)
- Automated contract verification and environment validation
- Updated asset configs for Sepolia
- Improved admin role assignment and access control in deployment scripts

### **Initial Setup**

```bash
# 1. Clone the repository
git clone https://github.com/GIVE-Labs/give-protocol-v0.git
cd give-protocol-v0

# 2. Install frontend dependencies
cd frontend
pnpm install

# 3. Install backend dependencies
cd ../backend
make install
# or manually: forge install

# 4. Environment configuration
cd frontend
cp .env.example .env.local
# Edit .env.local with your configuration

cd ../backend
cp .env.example .env
# Add your private key and RPC URLs
```

### **Environment Variables**

#### **Frontend (.env.local)**:
```bash
# Optional: Custom RPC endpoints
VITE_SCROLL_SEPOLIA_RPC=https://sepolia-rpc.scroll.io
VITE_WALLETCONNECT_PROJECT_ID=your_project_id
```

#### **Backend (.env)**:
```bash
# Required for deployment
DEPLOYER_KEY=your_private_key_here
SCROLL_SEPOLIA_RPC_URL=https://sepolia-rpc.scroll.io
SCROLLSCAN_API_KEY=your_scrollscan_api_key

# Optional
ADMIN_ADDRESS=0x...
FEE_RECIPIENT_ADDRESS=0x...
```

## 🛠️ Development Workflow

### **Option A: Full Local Development**

```bash
# Terminal 1: Start local blockchain and deploy contracts
cd backend
make dev  # Starts Anvil and deploys all contracts

# Terminal 2: Start frontend
cd frontend
pnpm dev
```

### **Option B: Manual Setup**

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

### **Option C: Testnet Development**

```bash
# Deploy to Scroll Sepolia testnet
cd backend
make deploy-scroll

# Update frontend config with deployed addresses
# Edit frontend/src/config/contracts.ts

# Start frontend
cd frontend
pnpm dev
```

## 🏗️ Build & Test Commands

### **Backend Commands**

```bash
cd backend

# Development
make help           # Show all available commands
make build          # Build contracts
make test           # Run tests
make test-v         # Run tests with verbose output
make test-fork      # Run fork tests (requires RPC)
make format         # Format code (forge fmt)
make lint           # Lint code

# Deployment
make deploy-local   # Deploy to local Anvil
make deploy-sepolia # Deploy to Ethereum Sepolia
make deploy-scroll  # Deploy to Scroll Sepolia

# Management
make register-ngo   # Register test NGO (local only)
make verify         # Verify contracts on Etherscan
make check-env      # Check environment setup
```

### **Frontend Commands**

```bash
cd frontend

# Development
pnpm dev           # Start development server (http://localhost:5173)
pnpm build         # Build for production
pnpm preview       # Preview production build
pnpm lint          # Run ESLint
pnpm type-check    # TypeScript type checking

# Contract Integration
pnpm sync-abis     # Sync ABIs from backend
pnpm build:contracts # Build contracts and sync ABIs
```

## 🔧 Development Environment

### **VS Code Setup**

Recommended extensions:
- **Solidity** - Juan Blanco
- **ES7+ React/Redux/React-Native snippets**
- **Tailwind CSS IntelliSense**
- **TypeScript Importer**
- **Prettier - Code formatter**
- **ESLint**

### **VS Code Settings** (`.vscode/settings.json`):
```json
{
  "solidity.defaultCompiler": "localNodeModule",
  "solidity.packageDefaultDependenciesDirectory": "lib",
  "typescript.preferences.importModuleSpecifier": "relative",
  "editor.formatOnSave": true,
  "editor.defaultFormatter": "esbenp.prettier-vscode"
}
```

## 📁 Project Structure Deep Dive

### **Backend Structure**
```
backend/
├── src/                    # Smart contract source code
│   ├── vault/             # Core vault contracts
│   │   └── GiveVault4626.sol
│   ├── adapters/          # Yield strategy adapters
│   │   ├── IYieldAdapter.sol
│   │   ├── AaveAdapter.sol
│   │   └── MockYieldAdapter.sol
│   ├── donation/          # NGO and donation system
│   │   ├── NGORegistry.sol
│   │   └── DonationRouter.sol
│   ├── manager/           # Management contracts
│   │   └── StrategyManager.sol
│   └── utils/             # Shared utilities
│       ├── Errors.sol
│       └── IWETH.sol
├── test/                  # Contract tests
│   ├── VaultRouter.t.sol  # Integration tests
│   ├── Router.t.sol       # Router-specific tests
│   └── *.t.sol           # Other test files
├── script/                # Deployment scripts
│   ├── Deploy.s.sol       # Main deployment
│   ├── HelperConfig.s.sol # Network configuration
│   └── *.s.sol           # Other scripts
├── lib/                   # Dependencies (forge install)
├── foundry.toml           # Foundry configuration
├── Makefile              # Build automation
└── README.md             # Backend documentation
```

### **Frontend Structure**
```
frontend/
├── src/
│   ├── components/        # Reusable components
│   │   ├── ui/           # Basic UI elements
│   │   ├── layout/       # Layout components
│   │   ├── ngo/          # NGO-related components
│   │   ├── portfolio/    # Dashboard components
│   │   └── staking/      # Staking components
│   ├── pages/            # Route components
│   │   ├── Home.tsx      # Landing page
│   │   ├── CampaignStaking.tsx # Main staking interface
│   │   ├── Dashboard.tsx # User dashboard
│   │   └── *.tsx        # Other pages
│   ├── hooks/            # Custom React hooks
│   ├── config/           # Configuration
│   │   ├── contracts.ts  # Contract addresses
│   │   ├── web3.ts      # Web3 configuration
│   │   └── local.ts     # Local development config
│   ├── services/         # External services
│   │   └── ipfs.ts      # IPFS integration
│   ├── types/            # TypeScript definitions
│   ├── data/             # Mock data
│   ├── assets/           # Static assets
│   └── abis/            # Contract ABIs
├── public/               # Public assets
├── package.json          # Dependencies
├── vite.config.ts       # Vite configuration
├── tailwind.config.js   # TailwindCSS config
└── tsconfig.json        # TypeScript config
```

## 🔄 Development Cycle

### **1. Feature Development Flow**

```bash
# 1. Create feature branch
git checkout -b feature/new-feature

# 2. Backend development
cd backend
# Edit contracts in src/
make build                # Compile
make test                 # Test
make format              # Format

# 3. Frontend development  
cd ../frontend
# Edit components/pages in src/
pnpm dev                 # Hot reload development
pnpm type-check          # TypeScript validation
pnpm lint               # Lint code

# 4. Integration testing
cd ../backend
make deploy-local        # Deploy locally
cd ../frontend
pnpm sync-abis          # Update ABIs
# Test integration manually

# 5. Commit and push
git add .
git commit -m "feat: add new feature"
git push origin feature/new-feature
```

### **2. Contract Development**

```bash
# 1. Write contract
vim backend/src/vault/NewContract.sol

# 2. Write tests
vim backend/test/NewContract.t.sol

# 3. Test locally
cd backend
make build
make test -m testNewFeature

# 4. Integration test
make deploy-local
# Test via frontend or cast commands

# 5. Deploy to testnet
make deploy-scroll
```

### **3. Frontend Development**

```bash
# 1. Create component
mkdir frontend/src/components/new-feature
vim frontend/src/components/new-feature/Component.tsx

# 2. Add to pages
vim frontend/src/pages/PageUsingComponent.tsx

# 3. Add routing (if needed)
vim frontend/src/App.tsx

# 4. Test locally
cd frontend
pnpm dev
# Test in browser at http://localhost:5173

# 5. Build for production
pnpm build
```

## 🧪 Testing Strategy

### **Smart Contract Testing**

```bash
cd backend

# Unit tests
make test

# Specific test
make test -m testDeposit

# Fork tests (requires RPC URL)
make test-fork

# Gas optimization tests
forge test --gas-report

# Coverage analysis
forge coverage
```

### **Frontend Testing**

```bash
cd frontend

# Type checking
pnpm type-check

# Linting
pnpm lint

# Build test
pnpm build

# Manual testing
pnpm dev
# Test user flows in browser
```

## 🔍 Debugging

### **Smart Contract Debugging**

```bash
# Verbose test output
forge test -vvv

# Trace specific test
forge test -vvv -m testFunctionName

# Debug with console.log in contracts
import "forge-std/console.sol";
console.log("Debug value:", someVariable);

# Deploy and interact via cast
cast call $CONTRACT "functionName()" --rpc-url http://localhost:8545
```

### **Frontend Debugging**

```bash
# Development with detailed logs
pnpm dev

# Browser developer tools
# Open Network tab to see failed transactions
# Check Console for errors
# Use React DevTools extension

# TypeScript errors
pnpm type-check
```

## 📦 Deployment

### **Local Deployment**
```bash
cd backend
make deploy-local
# Contracts deployed to http://localhost:8545
# Addresses printed to console
```

### **Testnet Deployment**
```bash
cd backend
make deploy-scroll  # Scroll Sepolia
# or
make deploy-sepolia # Ethereum Sepolia
```

### **Production Deployment**
```bash
# Backend
cd backend
make deploy-mainnet  # When ready for mainnet

# Frontend
cd frontend
pnpm build
# Deploy dist/ folder to hosting service
```

## 🔧 Troubleshooting

### **Common Issues**

#### **"Stack too deep" error**
- **Solution**: Already configured in `foundry.toml` with `via_ir = true`

#### **Frontend can't connect to contracts**
- **Check**: Contract addresses in `frontend/src/config/contracts.ts`
- **Check**: Network configuration in wallet
- **Check**: ABIs are up to date (`pnpm sync-abis`)

#### **Tests failing**
- **Check**: Foundry is up to date (`foundryup`)
- **Check**: Dependencies installed (`make install`)
- **Check**: Environment variables set

#### **Deployment fails**
- **Check**: Private key in `.env`
- **Check**: Network RPC URL is correct
- **Check**: Account has sufficient balance
- **Check**: API keys for verification

### **Getting Help**

1. **Check documentation** in `docs/` folder
2. **Review test files** for usage examples  
3. **Check GitHub issues** for known problems
4. **Ask in Discord/Telegram** (if available)

---

*This development guide provides everything needed to contribute effectively to GIVE Protocol.*