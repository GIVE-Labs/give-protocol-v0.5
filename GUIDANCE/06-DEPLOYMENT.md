# Deployment Guide - GIVE Protocol

## 🌐 Supported Networks

GIVE Protocol supports deployment on multiple EVM-compatible networks:

- **Scroll Sepolia** (Primary testnet)
- **Ethereum Sepolia** (Testing)
- **Local Development** (Anvil)
- **Ethereum Mainnet** (Future)

## 🔧 Deployment Prerequisites

### **Required Software**
- Foundry (forge, cast, anvil)
- Node.js 18+ with pnpm
- Git

### **Required Accounts & Keys**
- Ethereum wallet with private key
- Sufficient native tokens for gas fees
- API keys for contract verification (optional)

### **Network Requirements**

| Network | Gas Token | Faucet | Explorer |
|---------|-----------|---------|----------|
| Scroll Sepolia | ETH | [Scroll Faucet](https://sepolia.scroll.io/faucet) | [Scrollscan](https://sepolia.scrollscan.com/) |
| Ethereum Sepolia | ETH | [Sepolia Faucet](https://sepoliafaucet.com/) | [Etherscan](https://sepolia.etherscan.io/) |
| Local Anvil | ETH | Built-in | Local |

## ⚙️ Environment Configuration

### **Backend Environment Setup**

Create `backend/.env` file:

```bash
# Required
DEPLOYER_KEY=0x1234...your_private_key_here

# Network RPCs
SCROLL_SEPOLIA_RPC_URL=https://sepolia-rpc.scroll.io
SEPOLIA_RPC_URL=https://ethereum-sepolia.blockpi.network/v1/rpc/public

# Contract verification (optional)
SCROLLSCAN_API_KEY=your_scrollscan_api_key
ETHERSCAN_API_KEY=your_etherscan_api_key

# Deployment configuration (optional)
ADMIN_ADDRESS=0x...          # Defaults to deployer
ASSET_ADDRESS=0x...          # Defaults to network USDC
FEE_RECIPIENT_ADDRESS=0x...  # Defaults to admin
CASH_BUFFER_BPS=100          # 1% default
SLIPPAGE_BPS=50              # 0.5% default
MAX_LOSS_BPS=50              # 0.5% default  
FEE_BPS=250                  # 2.5% default
```

### **Frontend Environment Setup**

Create `frontend/.env.local` file:

```bash
# Optional: Custom RPC endpoints
VITE_SCROLL_SEPOLIA_RPC=https://sepolia-rpc.scroll.io
VITE_SEPOLIA_RPC=https://ethereum-sepolia.blockpi.network/v1/rpc/public

# WalletConnect configuration
VITE_WALLETCONNECT_PROJECT_ID=your_project_id
```

## 🚀 Deployment Procedures

### **Local Development Deployment**

#### **Option A: Automated Setup**
```bash
cd backend
make dev
```
This command:
1. Starts Anvil local blockchain
2. Deploys all contracts
3. Registers a test NGO
4. Prints contract addresses

#### **Option B: Manual Setup**
```bash
# Terminal 1: Start Anvil
anvil

# Terminal 2: Deploy contracts
cd backend
make deploy-local

# Optional: Register test NGO
make register-ngo
```

### **Testnet Deployment**

#### **Scroll Sepolia Deployment**
```bash
cd backend

# Check environment
make check-env

# Deploy contracts
make deploy-scroll

# Verify contracts (optional)
make verify-scroll
```

#### **Ethereum Sepolia Deployment**
```bash
cd backend

# Deploy contracts
make deploy-sepolia

# Verify contracts (optional)  
make verify-sepolia
```

### **Mainnet Deployment** (Future)

```bash
cd backend

# Deploy contracts (when ready)
make deploy-mainnet

# Verify contracts
make verify-mainnet
```

## 📋 Deployment Flow

### **Contract Deployment Order**

The deployment script follows this sequence:

1. **Deploy Core Infrastructure**:
   - `NGORegistry` (with admin)
   - `DonationRouter` (with registry, fee recipient, fee %)

2. **Deploy Vault System**:
   - `GiveVault4626` (with asset, name, symbol, admin)
   - `StrategyManager` (with vault, admin)

3. **Deploy Yield Adapters**:
   - `AaveAdapter` (with asset, vault, aave pool, admin)
   - Additional adapters as needed

4. **Configure System**:
   - Set donation router in vault
   - Set active adapter in strategy manager
   - Authorize vault in donation router
   - Grant roles to appropriate contracts

### **Deployment Script Details**

**Location**: `backend/script/Deploy.s.sol`

```solidity
contract Deploy is Script {
    function run() external returns (Deployed memory) {
        // Get network configuration
        HelperConfig helperConfig = new HelperConfig();
        
        // Deploy core contracts
        NGORegistry registry = new NGORegistry(admin);
        DonationRouter router = new DonationRouter(admin, address(registry), feeRecipient, feeBps);
        
        // Deploy vault system
        GiveVault4626 vault = new GiveVault4626(asset, name, symbol, admin);
        StrategyManager manager = new StrategyManager(address(vault), admin);
        
        // Deploy adapters
        AaveAdapter adapter = new AaveAdapter(address(asset), address(vault), aavePool, admin);
        
        // Configure system
        vault.setDonationRouter(address(router));
        manager.setActiveAdapter(address(adapter));
        router.setAuthorizedCaller(address(vault), true);
        registry.grantRole(registry.DONATION_RECORDER_ROLE(), address(router));
        
        return Deployed({
            vault: address(vault),
            manager: address(manager),
            adapter: address(adapter),
            registry: address(registry),
            router: address(router)
        });
    }
}
```

## 📝 Deployment Configuration

### **Network-Specific Configuration**

**Location**: `backend/script/HelperConfig.s.sol`

```solidity
contract HelperConfig is Script {
    struct NetworkConfig {
        address wethUsdPriceFeed;
        address wbtcUsdPriceFeed;
        address weth;
        address wbtc;
        address usdc;
        address aavePool;
        uint256 deployerKey;
    }

    function getActiveNetworkConfig() public returns (NetworkConfig memory) {
        if (block.chainid == 534351) { // Scroll Sepolia
            return getScrollSepoliaConfig();
        } else if (block.chainid == 11155111) { // Ethereum Sepolia
            return getSepoliaConfig();
        } else {
            return getAnvilEthConfig();
        }
    }
}
```

### **Makefile Commands**

**Location**: `backend/Makefile`

Key deployment commands:
```makefile
# Local deployment
deploy-local:
	@forge script script/DeployLocal.s.sol:DeployLocal --rpc-url $(LOCAL_RPC_URL) --private-key $(ANVIL_KEY) --broadcast

# Testnet deployments  
deploy-scroll:
	@forge script script/Deploy.s.sol:Deploy --rpc-url $(SCROLL_SEPOLIA_RPC_URL) --private-key $(DEPLOYER_KEY) --broadcast --verify --etherscan-api-key $(SCROLLSCAN_API_KEY)

deploy-sepolia:
	@forge script script/Deploy.s.sol:Deploy --rpc-url $(SEPOLIA_RPC_URL) --private-key $(DEPLOYER_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY)

# Contract verification
verify-scroll:
	@forge verify-contract $(CONTRACT_ADDRESS) src/$(CONTRACT_FILE).sol:$(CONTRACT_NAME) --etherscan-api-key $(SCROLLSCAN_API_KEY) --rpc-url $(SCROLL_SEPOLIA_RPC_URL)
```

## 📍 Current Deployment Addresses

### **Scroll Sepolia (Testnet)**

```
Network: Scroll Sepolia (Chain ID: 534351)
Deployed: 2025-01-15

NGO_REGISTRY=0xeFBC3D84420D848A8b6F5FD614E5740279D834Fa
VAULT=0x330EC5985f4a8A03ac148a4fa12d4c45120e73bB  
STRATEGY_MANAGER=0xDd7800b4871816Ccc4E185A101055Ea47a73b32d
AAVE_ADAPTER=0x284Ac57242f5657Cb2E45157D80068639EBac026
DONATION_ROUTER=0xcA3826a36f1B82121c18F35d218e7163aFF904a4

Token Addresses:
USDC=0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8
WETH=0xC558DBdd856501FCd9aaF1E62eae57A9F0629a3c
ETH=0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
```

### **Local Development**

```
Network: Anvil Local (Chain ID: 31337)
RPC: http://localhost:8545

NGO_REGISTRY=0x5FbDB2315678afecb367f032d93F642f64180aa3
VAULT=0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
STRATEGY_MANAGER=0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0
AAVE_ADAPTER=0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9
DONATION_ROUTER=0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9

Mock Token Addresses:
USDC=0x8A791620dd6260079BF849Dc5567aDC3F2FdC318
WETH=0x610178dA211FEF7D417bC0e6FeD39F05609AD788
ETH=0x0165878A594ca255338adfa4d48449f69242Eb8F
```

## ✅ Post-Deployment Verification

### **Contract Verification Checklist**

After deployment, verify:

1. **Contract Verification on Explorer**:
   ```bash
   make verify-scroll  # or verify-sepolia
   ```

2. **Role Configuration**:
   ```bash
   # Check admin roles
   cast call $NGO_REGISTRY "hasRole(bytes32,address)" 0x0000000000000000000000000000000000000000000000000000000000000000 $ADMIN_ADDRESS --rpc-url $RPC_URL

   # Check vault manager role
   cast call $VAULT "hasRole(bytes32,address)" $(cast keccak "VAULT_MANAGER_ROLE") $ADMIN_ADDRESS --rpc-url $RPC_URL
   ```

3. **System Configuration**:
   ```bash
   # Check donation router
   cast call $VAULT "donationRouter()" --rpc-url $RPC_URL
   
   # Check active adapter
   cast call $VAULT "activeAdapter()" --rpc-url $RPC_URL
   
   # Check authorized caller
   cast call $DONATION_ROUTER "authorizedCallers(address)" $VAULT --rpc-url $RPC_URL
   ```

4. **Test Basic Functionality**:
   ```bash
   # Register test NGO (if needed)
   make register-ngo
   
   # Test deposit (small amount)
   cast send $USDC "approve(address,uint256)" $VAULT 1000000 --private-key $DEPLOYER_KEY --rpc-url $RPC_URL
   cast send $VAULT "deposit(uint256,address)" 1000000 $DEPLOYER_ADDRESS --private-key $DEPLOYER_KEY --rpc-url $RPC_URL
   ```

## 🔄 Frontend Configuration Update

After contract deployment, update frontend configuration:

### **Update Contract Addresses**

Edit `frontend/src/config/contracts.ts`:

```typescript
const SEPOLIA_CONTRACT_ADDRESSES = {
  NGO_REGISTRY: '0xeFBC3D84420D848A8b6F5FD614E5740279D834Fa',
  VAULT: '0x330EC5985f4a8A03ac148a4fa12d4c45120e73bB',
  STRATEGY_MANAGER: '0xDd7800b4871816Ccc4E185A101055Ea47a73b32d',
  AAVE_ADAPTER: '0x284Ac57242f5657Cb2E45157D80068639EBac026',
  DONATION_ROUTER: '0xcA3826a36f1B82121c18F35d218e7163aFF904a4',
  
  TOKENS: {
    ETH: '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2',
    USDC: '0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8',
    WETH: '0xC558DBdd856501FCd9aaF1E62eae57A9F0629a3c',
  }
};
```

### **Sync Contract ABIs**

```bash
cd frontend
pnpm sync-abis
```

### **Test Frontend Connection**

```bash
cd frontend
pnpm dev
# Navigate to http://localhost:5173
# Test wallet connection and contract interaction
```

## 🔒 Security Considerations

### **Deployment Security**

1. **Private Key Management**:
   - Never commit private keys to version control
   - Use hardware wallets for mainnet deployments
   - Consider multi-signature wallets for admin roles

2. **Network Verification**:
   - Always verify you're deploying to the correct network
   - Check chain ID before deployment
   - Confirm contract addresses after deployment

3. **Role Management**:
   - Grant roles only to trusted addresses
   - Use multi-signature wallets for critical roles
   - Implement timelock for sensitive operations

### **Post-Deployment Security**

1. **Contract Verification**:
   - Always verify contracts on block explorers
   - Check that verified source code matches deployment

2. **Access Control Audit**:
   - Review all granted roles
   - Confirm role holders are correct
   - Test role permissions

3. **System Integration Testing**:
   - Test all critical user flows
   - Verify emergency pause functionality
   - Test adapter functionality with small amounts

## 🚨 Troubleshooting Deployment

### **Common Issues**

1. **Insufficient Gas**:
   ```bash
   # Increase gas limit
   --gas-limit 3000000
   ```

2. **Nonce Issues**:
   ```bash
   # Reset nonce
   --reset
   ```

3. **RPC Issues**:
   ```bash
   # Try alternative RPC
   --rpc-url https://alternative-rpc.com
   ```

4. **Verification Failures**:
   ```bash
   # Manual verification
   forge verify-contract --help
   ```

### **Recovery Procedures**

If deployment fails:

1. **Check transaction hash** for revert reason
2. **Verify account balance** for gas fees
3. **Check network connectivity** and RPC endpoints
4. **Review environment variables** and configuration
5. **Try deployment to local network** first

---

*This deployment guide provides comprehensive instructions for deploying GIVE Protocol across different networks and environments.*