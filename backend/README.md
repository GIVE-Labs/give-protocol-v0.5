# GiveProtocol Backend

Smart contracts for the GiveProtocol - a no-loss giving platform built on ERC-4626 vaults.

## Architecture

The GiveProtocol consists of several key components:

- **GiveVault4626 / CampaignVault**: ERC-4626 compliant vaults that accept deposits and generate yield for campaigns
- **StrategyRegistry**: Catalog of approved yield strategies that campaigns can adopt
- **CampaignRegistry**: Permissionless registry for campaign submissions, approvals, and strategy attachments
- **PayoutRouter**: Routes harvested yield to campaigns and supporter beneficiaries according to preferences
- **CampaignVaultFactory**: Deploys campaign-bound vaults with predefined lock profiles and strategies
- **HelperConfig**: Network configuration for different deployment environments

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Make (for using the Makefile commands)
- Node.js 18+ (for some scripts)

## Quick Start

### 1. Install Dependencies
```bash
make install
# or manually: forge install
```

### 2. Build Contracts
```bash
make build
```

### 3. Run Tests
```bash
make test
```

### 4. Deploy Locally
```bash
# Start local development environment (Anvil + contracts)
make dev

# Or deploy to existing Anvil instance
make deploy-local
```

## Environment Setup

### Required Environment Variables

Copy `.env.example` to `.env` and configure:

```bash
cp .env.example .env
```

**For Local Development:**
```bash
DEPLOYER_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

**For Testnet Deployment:**
```bash
DEPLOYER_KEY=your_private_key_here
SCROLL_SEPOLIA_RPC_URL=https://sepolia-rpc.scroll.io
ETHERSCAN_API_KEY=your_etherscan_api_key
```

**For Mainnet Deployment:**
```bash
DEPLOYER_KEY=your_private_key_here
ETHERSCAN_API_KEY=your_etherscan_api_key
```

## Deployment

### Local Development
```bash
# Full development setup (recommended)
make dev

# Manual deployment to local Anvil
make deploy-local
```

### Testnet Deployment
```bash
# Deploy to Scroll Sepolia
make deploy-scroll

# Deploy to Ethereum Sepolia
make deploy-sepolia
```

### Mainnet Deployment
```bash
# Deploy to Ethereum Mainnet (use with caution)
make deploy NETWORK=mainnet
```

### Custom Network
```bash
make deploy NETWORK=custom RPC_URL=your_rpc_url PRIVATE_KEY=your_key
```

## Development Commands

### Building and Testing
```bash
make build          # Build all contracts
make test           # Run unit tests
make test-fork      # Run fork tests against live networks
make clean          # Clean build artifacts
```

### Code Quality
```bash
make format         # Format Solidity code
make lint           # Check code formatting
```

### Contract Management
```bash
make verify         # Verify contracts on Etherscan
```

### Environment Utilities
```bash
make check-env      # Check environment configuration
make help           # Show all available commands
```

## Contract Verification

After deployment to testnets or mainnet, verify your contracts:

```bash
# Automatic verification during deployment (if API key is set)
make deploy-scroll  # Automatically verifies on Scrollscan
make deploy-sepolia # Automatically verifies on Etherscan

# Manual verification
make verify CONTRACT_ADDRESS=0x... CONTRACT_NAME=GiveVault4626
```

## Testing

### Unit Tests
```bash
make test
```

### Fork Tests
Run tests against live networks:
```bash
make test-fork
```

### Gas Optimization
```bash
forge snapshot      # Generate gas snapshots
forge test --gas-report  # Detailed gas usage report
```

## Project Structure

```
backend/
├── src/
│   ├── GiveVault4626.sol      # Main vault contract
│   ├── AaveAdapter.sol        # Aave yield strategy
│   ├── campaign/              # Campaign registry + types
│   ├── payout/                # Yield distribution (PayoutRouter)
│   └── interfaces/            # Contract interfaces
├── script/
│   ├── Deploy.s.sol           # Main deployment script
│   ├── DeployLocal.s.sol      # Local deployment script
│   └── HelperConfig.s.sol     # Network configurations
├── test/
│   ├── unit/                  # Unit tests
│   ├── integration/           # Integration tests
│   └── fork/                  # Fork tests
├── lib/                       # Dependencies
├── Makefile                   # Build and deployment automation
└── foundry.toml              # Foundry configuration
```

## Network Configurations

Supported networks:

- **Local**: Anvil (Chain ID: 31337)
- **Sepolia**: Ethereum Sepolia Testnet (Chain ID: 11155111)
- **Scroll Sepolia**: Scroll Sepolia Testnet (Chain ID: 534351)
- **Mainnet**: Ethereum Mainnet (Chain ID: 1)

## Troubleshooting

### Common Issues

1. **"forge not found"**
   ```bash
   # Install Foundry
   curl -L https://foundry.paradigm.xyz | bash
   foundryup
   ```

2. **"make not found"**
   ```bash
   # On Ubuntu/Debian
   sudo apt install make
   
   # On macOS
   xcode-select --install
   ```

3. **Deployment fails with "insufficient funds"**
   - Ensure your wallet has enough ETH for gas fees
   - For testnets, get ETH from faucets

4. **Contract verification fails**
   - Ensure `ETHERSCAN_API_KEY` is set correctly
   - Wait a few minutes after deployment before verifying

### Getting Help

```bash
make help           # Show all available commands
forge --help        # Foundry help
cast --help         # Cast help
anvil --help        # Anvil help
```

## Resources

- [Foundry Documentation](https://book.getfoundry.sh/)
- [ERC-4626 Standard](https://eips.ethereum.org/EIPS/eip-4626)
- [Aave Documentation](https://docs.aave.com/)
- [Scroll Documentation](https://docs.scroll.io/)
