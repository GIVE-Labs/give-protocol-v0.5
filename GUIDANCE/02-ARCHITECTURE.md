# Architecture - GIVE Protocol

## 🏗️ System Architecture Overview

GIVE Protocol follows a modular, upgradeable architecture built on ERC-4626 vaults with pluggable yield adapters and a flexible donation distribution system.

### 🌐 Multi-Network Support
- Supports Scroll Sepolia, Ethereum Sepolia, and local Anvil deployments
- All core contracts deployed and verified on Sepolia (see [06-DEPLOYMENT.md](06-DEPLOYMENT.md))
- Frontend and backend auto-configure for selected network

### 🏦 Latest Contract Addresses (Sepolia)
- GiveVault4626 (USDC): `0x9816de1f27c15AAe597548f09E2188d16752C4C8`
- StrategyManager: `0x42cB507dfe0f7D8a01c9ad9e1b18B84CCf0A41B9`
- AaveAdapter: `0xFc03875B2B2a84D9D1Bd24E41281fF371b3A1948`
- NGORegistry: `0x77182f2C8E86233D3B0095446Da20ecDecF96Cc2`
- DonationRouter: `0x33952be800FbBc7f8198A0efD489204720f64A4C`

```
┌─────────────────────────────────────────────────────────────┐
│                     GIVE Protocol                           │
├─────────────────────────────────────────────────────────────┤
│  Frontend (React + Web3)                                   │
│  ├── Wallet Connection (RainbowKit + wagmi)                │
│  ├── Vault Interface (Deposit/Withdraw)                    │
│  ├── NGO Selection & Preferences                           │
│  └── Portfolio Dashboard                                   │
├─────────────────────────────────────────────────────────────┤
│  Smart Contract Layer                                      │
│  ├── Core Vault System                                     │
│  │   ├── GiveVault4626 (ERC-4626)                        │
│  │   └── StrategyManager                                  │
│  ├── Yield Generation                                      │
│  │   ├── IYieldAdapter (Interface)                       │
│  │   ├── AaveAdapter                                     │
│  │   └── MockYieldAdapter (Testing)                     │
│  ├── Donation System                                      │
│  │   ├── NGORegistry                                     │
│  │   └── DonationRouter                                  │
│  └── Utilities                                           │
│      ├── Access Control (Roles)                          │
│      ├── Emergency Pause                                 │
│      └── Error Handling                                  │
├─────────────────────────────────────────────────────────────┤
│  External Integrations                                     │
│  ├── Aave Protocol (Yield Generation)                     │
│  ├── IPFS/Arweave (Metadata Storage)                     │
│  └── Chainlink (Price Feeds - Future)                    │
└─────────────────────────────────────────────────────────────┘
```

## 📊 Data Flow Architecture

### 1. User Deposit Flow
```
User → Frontend → GiveVault4626.deposit() → StrategyManager → YieldAdapter.invest()
                                       ↓
                            Mint Vault Shares → User Wallet
```

### 2. Yield Generation Flow
```
YieldAdapter (Aave) → Generate Interest → StrategyManager.harvest() → GiveVault4626.harvest()
                                                                   ↓
                                                        DonationRouter.distribute()
                                                                   ↓
                                                            NGO Wallet + Protocol Fee
```

### 3. User Withdrawal Flow
```
User → GiveVault4626.withdraw() → Check Cash Buffer → If Needed: YieldAdapter.divest()
                               ↓
                    Burn Vault Shares → Transfer Assets → User Wallet
```

## 🔧 Component Architecture

### Core Vault System

#### **GiveVault4626**
- **Role**: Primary user interface and accounting
- **Inherits**: ERC4626, AccessControl, ReentrancyGuard, Pausable
- **Key Functions**:
  - `deposit()` / `withdraw()` - User asset management
  - `totalAssets()` - Cash + adapter assets
  - `harvest()` - Yield collection and donation
  - Emergency functions

#### **StrategyManager**
- **Role**: Vault parameter and adapter management
- **Key Functions**:
  - `setActiveAdapter()` - Switch yield strategies
  - `setCashBufferBps()` - Liquidity management
  - `allocateToAdapter()` - Investment allocation
  - Risk parameter management

### Yield Generation Layer

#### **IYieldAdapter Interface**
```solidity
interface IYieldAdapter {
    function asset() external view returns (IERC20);
    function totalAssets() external view returns (uint256);
    function invest(uint256 assets) external;
    function divest(uint256 assets) external returns (uint256);
    function harvest() external returns (uint256 profit, uint256 loss);
    function emergencyWithdraw() external returns (uint256);
}
```

#### **AaveAdapter Implementation**
- **Role**: Aave protocol integration
- **Functions**:
  - Supply assets to Aave lending pools
  - Track aToken balances
  - Calculate yield and harvest profits
  - Emergency asset recovery

### Donation System

#### **NGORegistry**
- **Role**: NGO verification and management
- **Key Features**:
  - NGO approval/removal workflow
  - IPFS metadata storage
  - KYC/attestation tracking
  - Donation history recording

#### **DonationRouter**
- **Role**: Yield distribution to NGOs
- **Key Features**:
  - Multi-NGO distribution support
  - Protocol fee handling
  - Weighted allocation (future)
  - Emergency pause functionality

## 🔐 Security Architecture

### Access Control Model

```
Role Hierarchy:
├── DEFAULT_ADMIN_ROLE (Multisig)
│   ├── VAULT_MANAGER_ROLE
│   │   ├── Vault configuration
│   │   └── Adapter management
│   ├── NGO_MANAGER_ROLE
│   │   ├── NGO approval
│   │   └── Registry management
│   ├── PAUSER_ROLE
│   │   ├── Emergency pause
│   │   └── System protection
│   └── DONATION_RECORDER_ROLE
│       ├── Record donations
│       └── Update statistics
```

### Security Layers

1. **Contract Level**:
   - OpenZeppelin AccessControl
   - ReentrancyGuard on external calls
   - Pausable emergency stops
   - SafeERC20 for token transfers

2. **Economic Security**:
   - Cash buffer for immediate liquidity
   - Slippage protection on adapter calls
   - Maximum loss limits on divestments
   - Protocol fee sustainability

3. **Operational Security**:
   - Time-locked governance changes
   - Multi-signature admin controls
   - Emergency withdrawal mechanisms
   - Comprehensive event logging

## 🔄 Upgrade Architecture (Future)

### UUPS Proxy Pattern (v1.0+)
```
Implementation Contract ← Proxy Contract ← User Interface
        ↓                      ↓
   Logic Storage          State Storage
```

**Benefits**:
- Gas-efficient upgrades
- Preserved contract addresses
- Gradual feature rollouts
- Bug fix capabilities

Note: the repository implements UUPS / ERC1967 upgradeability in V2 (upgrade role + UUPS pattern). Some tutorial diagrams mention `ProxyAdmin` (Transparent/ProxyAdmin upgrade flow) as an alternative. For clarity: the project uses UUPS (an upgradeable implementation contract guarded by an upgrader role). Below are short, actionable notes and examples to avoid confusion and help deployment.

UUPS vs ProxyAdmin (summary)
- UUPS: The implementation contract includes the upgrade function (usually protected by an UPGRADER_ROLE). The proxy (ERC1967) simply forwards calls and stores the implementation address. This pattern is gas-efficient and keeps the admin logic closer to the implementation.
- ProxyAdmin (Transparent Proxy): A separate, external admin contract (ProxyAdmin) is the owner of one or more proxies and performs upgrades on them. This is a convenient orchestration pattern when you want a single admin to manage multiple proxies.

When to use which
- Use UUPS when you prefer compact upgrade paths, gas-efficiency, and when each implementation can safely gate upgrades (this repo's V2 uses UUPS).
- Use ProxyAdmin when you want a dedicated admin contract (for example, a multisig or TimelockController owning the ProxyAdmin) to centralize upgrades across multiple proxies.

Quick deployment/upgrade snippets (conceptual)

Deploy (pattern)
1. Deploy implementation (ExampleImplementation)
2. Deploy ERC1967 proxy pointing to implementation with initialize calldata
3. Assign UPGRADER_ROLE to the multisig or timelock that should perform upgrades

Upgrade (UUPS)
1. The account with `UPGRADER_ROLE` calls `upgradeTo(newImplementation)` on the proxy (via the implementation's upgrade function)
2. Optionally run any migration/initialize step on the new implementation

Note: If you prefer a ProxyAdmin workflow, you can deploy a `ProxyAdmin` contract and have a multisig/TimelockController own the `ProxyAdmin`, then use `ProxyAdmin.upgrade(proxy, newImpl)` to perform upgrades.

Security recommendation
- In production, guard the `UPGRADER_ROLE` with a TimelockController (or similar) so upgrades are timelocked and transparent to the community. See `script/` for the repo's upgrade scripts; you can adapt them to grant the timelock the `UPGRADER_ROLE` during bootstrap.

Diagram rendering and the master diagram
- The master architecture diagram lives in `docs/MASTER_ARCHITECTURE_DIAGRAM.md`. If you need a rendered SVG, follow the local rendering instructions in `docs/DIAGRAM_RENDERING.md` (uses `@mermaid-js/mermaid-cli`). A placeholder SVG `docs/MASTER_ARCHITECTURE_DIAGRAM.svg` is included in the repo until you render the final version.


## 🌐 Network Architecture

### Multi-Chain Strategy
```
Ethereum Mainnet (v1.0)
├── Primary deployment
├── Maximum security
└── Institutional adoption

Scroll (Current)
├── Lower fees
├── EVM compatibility
└── Testing ground

Arbitrum/Polygon (v1.2)
├── Ecosystem expansion
├── Cross-chain bridges
└── Yield optimization
```

## 📈 Scalability Architecture

### Horizontal Scaling
- **Multiple Vaults**: Per asset type (USDC, ETH, WBTC)
- **Multiple Adapters**: Per yield source (Aave, Compound, Pendle)
- **Multiple Networks**: Cross-chain deployment

### Vertical Scaling
- **Batch Operations**: Multiple user actions in single tx
- **Gas Optimization**: Efficient contract design
- **State Management**: Minimal storage usage

## 🔧 Integration Architecture

### External Protocol Integration

#### **Aave Integration**
```solidity
AaveAdapter {
    IPool public aavePool;
    IERC20 public aToken;
    
    function invest(uint256 amount) external {
        asset.approve(address(aavePool), amount);
        aavePool.supply(address(asset), amount, address(this), 0);
    }
}
```

#### **IPFS Integration**
```javascript
// Frontend metadata storage
const metadata = {
    name: "NGO Name",
    description: "NGO Description",
    images: ["ipfs://..."],
    verification: {...}
};
const cid = await uploadToIPFS(metadata);
await ngoRegistry.addNGO(ngoAddress, cid, kycHash, attestor);
```

## 🏗️ Development Architecture

### Frontend Architecture
```
src/
├── components/          # Reusable UI components
│   ├── ui/             # Basic UI elements
│   ├── layout/         # Layout components
│   └── domain/         # Feature-specific components
├── pages/              # Route components
├── hooks/              # Custom React hooks
├── config/             # Configuration files
├── services/           # External service integrations
├── types/              # TypeScript definitions
└── utils/              # Utility functions
```

### Smart Contract Architecture
```
src/
├── vault/              # Core vault contracts
├── adapters/           # Yield strategy adapters
├── donation/           # NGO and donation contracts
├── manager/            # Management contracts
└── utils/              # Shared utilities

test/
├── unit/               # Unit tests
├── integration/        # Integration tests
└── fork/               # Mainnet fork tests
```

## 🔍 Monitoring & Observability

### Event Architecture
- **Comprehensive Logging**: All state changes emit events
- **Indexing Ready**: Events designed for subgraph indexing
- **Analytics Friendly**: Structured data for dashboards
- **Audit Trail**: Complete transaction history

### Key Metrics Tracking
- Total Value Locked (TVL)
- Yield generation rates
- Donation amounts and frequency
- User engagement metrics
- System health indicators

---

*This architecture documentation provides the technical foundation for understanding GIVE Protocol's design decisions and implementation details.*