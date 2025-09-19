# Smart Contracts - GIVE Protocol

## 📋 Contract Overview

GIVE Protocol consists of 5 core smart contracts working together to enable no-loss giving through yield generation.

## 🏦 Core Vault System

### **GiveVault4626.sol**

**Location**: `backend/src/vault/GiveVault4626.sol`  
**Inherits**: `ERC4626`, `AccessControl`, `ReentrancyGuard`, `Pausable`

The primary vault contract that users interact with for deposits and withdrawals.

#### **Key Features**:
- ERC-4626 compliant vault interface
- Cash buffer management for instant withdrawals
- Yield harvesting and donation distribution
- Emergency pause functionality
- Role-based access control

#### **Core Functions**:

```solidity
// ERC-4626 Standard Functions
function deposit(uint256 assets, address receiver) external returns (uint256 shares);
function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares);
function totalAssets() public view returns (uint256); // cash + adapter assets

// Vault Management
function harvest() external whenNotPaused returns (uint256 profit, uint256 loss);
function setActiveAdapter(address adapter) external onlyRole(VAULT_MANAGER_ROLE);
function setCashBufferBps(uint256 bps) external onlyRole(VAULT_MANAGER_ROLE);

// Emergency Functions
function pause() external onlyRole(PAUSER_ROLE);
function emergencyWithdrawFromAdapter(uint256 amount) external onlyRole(VAULT_MANAGER_ROLE);
```

#### **State Variables**:
```solidity
IYieldAdapter public activeAdapter;
address public donationRouter;
address public wrappedNative; // For ETH support

uint256 public cashBufferBps = 100; // 1% default
uint256 public slippageBps = 50; // 0.5% default
uint256 public maxLossBps = 50; // 0.5% default

bool public investPaused;
bool public harvestPaused;
```

#### **Events**:
```solidity
event AdapterUpdated(address indexed oldAdapter, address indexed newAdapter);
event CashBufferUpdated(uint256 oldBps, uint256 newBps);
event Harvest(uint256 profit, uint256 loss, uint256 donated);
event EmergencyWithdraw(uint256 amount);
```

### **StrategyManager.sol**

**Location**: `backend/src/manager/StrategyManager.sol`  
**Role**: Vault parameter and adapter management

Central management contract for vault configuration and yield strategy coordination.

#### **Key Functions**:
```solidity
function setActiveAdapter(address adapter) external onlyRole(VAULT_MANAGER_ROLE);
function allocateToAdapter(uint256 amount) external onlyRole(VAULT_MANAGER_ROLE);
function setCashBufferBps(uint256 bps) external onlyRole(VAULT_MANAGER_ROLE);
function setSlippageBps(uint256 bps) external onlyRole(VAULT_MANAGER_ROLE);
function setMaxLossBps(uint256 bps) external onlyRole(VAULT_MANAGER_ROLE);
```

## 💰 Yield Generation Layer

### **IYieldAdapter.sol**

**Location**: `backend/src/adapters/IYieldAdapter.sol`  
**Type**: Interface

Standard interface that all yield adapters must implement.

```solidity
interface IYieldAdapter {
    function asset() external view returns (IERC20);
    function totalAssets() external view returns (uint256);
    function invest(uint256 assets) external;
    function divest(uint256 assets) external returns (uint256 returned);
    function harvest() external returns (uint256 profit, uint256 loss);
    function emergencyWithdraw() external returns (uint256 returned);
    function vault() external view returns (address);
}
```

### **AaveAdapter.sol**

**Location**: `backend/src/adapters/AaveAdapter.sol`  
**Inherits**: `IYieldAdapter`, `AccessControl`

Aave protocol integration for yield generation through lending.

#### **Key Features**:
- Supply assets to Aave lending pools
- Track aToken balances for yield calculation
- Harvest interest generated from Aave
- Emergency withdrawal from Aave

#### **Core Functions**:
```solidity
function invest(uint256 assets) external onlyVault {
    asset.approve(address(aavePool), assets);
    aavePool.supply(address(asset), assets, address(this), 0);
}

function divest(uint256 assets) external onlyVault returns (uint256 returned) {
    return aavePool.withdraw(address(asset), assets, address(vault));
}

function harvest() external onlyVault returns (uint256 profit, uint256 loss) {
    uint256 currentBalance = aToken.balanceOf(address(this));
    if (currentBalance > lastRecordedBalance) {
        profit = currentBalance - lastRecordedBalance;
        lastRecordedBalance = currentBalance;
    }
}

function totalAssets() external view returns (uint256) {
    return aToken.balanceOf(address(this));
}
```

#### **Integration Points**:
```solidity
IPool public immutable aavePool;
IERC20 public immutable aToken;
uint256 private lastRecordedBalance;
```

## 🎁 Donation System

### **NGORegistry.sol**

**Location**: `backend/src/donation/NGORegistry.sol`  
**Inherits**: `AccessControl`, `Pausable`

Registry for managing approved NGOs that can receive donations.

#### **Key Features**:
- NGO approval and removal workflow
- Metadata storage with IPFS integration
- KYC/attestation tracking
- Donation history recording
- Current NGO selection for single-NGO mode

#### **Core Functions**:
```solidity
function addNGO(
    address ngo, 
    string calldata metadataCid, 
    bytes32 kycHash, 
    address attestor
) external onlyRole(NGO_MANAGER_ROLE);

function removeNGO(address ngo) external onlyRole(NGO_MANAGER_ROLE);

function setCurrentNGO(address ngo) external onlyRole(NGO_MANAGER_ROLE);

function recordDonation(address ngo, uint256 amount) 
    external onlyRole(DONATION_RECORDER_ROLE);
```

#### **Data Structures**:
```solidity
struct NGOInfo {
    string metadataCid;      // IPFS hash for metadata
    bytes32 kycHash;         // Attestation hash
    address attestor;        // Verifier address
    uint256 createdAt;       // Registration timestamp
    uint256 updatedAt;       // Last update timestamp
    uint256 version;         // Metadata version
    uint256 totalReceived;   // Total donations received
    bool isActive;           // Status flag
}

mapping(address => bool) public isApproved;
mapping(address => NGOInfo) public ngoInfo;
address public currentNGO;
```

#### **Events**:
```solidity
event NGOApproved(address indexed ngo, string metadataCid, bytes32 kycHash, address attestor, uint256 timestamp);
event NGORemoved(address indexed ngo, string metadataCid, uint256 timestamp);
event CurrentNGOSet(address indexed oldNGO, address indexed newNGO, uint256 eta);
event DonationRecorded(address indexed ngo, uint256 amount, uint256 newTotalReceived);
```

### **DonationRouter.sol**

**Location**: `backend/src/donation/DonationRouter.sol`  
**Inherits**: `AccessControl`, `Pausable`

Routes harvested yield to approved NGOs with optional protocol fees.

#### **Key Features**:
- Distribute harvested yield to NGOs
- Protocol fee handling
- Multi-NGO distribution support (future)
- Emergency pause functionality

#### **Core Functions**:
```solidity
function distribute(IERC20 asset, uint256 amount) external whenNotPaused {
    require(authorizedCallers[msg.sender], "Unauthorized");
    
    // Calculate fee
    uint256 fee = (amount * feeBps) / BASIS_POINTS;
    uint256 netAmount = amount - fee;
    
    // Transfer to current NGO
    address currentNGO = ngoRegistry.currentNGO();
    require(currentNGO != address(0), "No current NGO");
    
    asset.safeTransferFrom(msg.sender, currentNGO, netAmount);
    if (fee > 0) {
        asset.safeTransferFrom(msg.sender, feeRecipient, fee);
    }
    
    // Record donation
    ngoRegistry.recordDonation(currentNGO, netAmount);
    
    emit DonationDistributed(currentNGO, address(asset), netAmount, fee);
}

function setFeeBps(uint256 newFeeBps) external onlyRole(DEFAULT_ADMIN_ROLE);
function setFeeRecipient(address newFeeRecipient) external onlyRole(DEFAULT_ADMIN_ROLE);
function setAuthorizedCaller(address caller, bool authorized) external onlyRole(DEFAULT_ADMIN_ROLE);
```

#### **State Variables**:
```solidity
NGORegistry public immutable ngoRegistry;
address public feeRecipient;
uint256 public feeBps; // Protocol fee in basis points

mapping(address => bool) public authorizedCallers; // Vaults that can call distribute
```

## 🛠️ Utility Contracts

### **Errors.sol**

**Location**: `backend/src/utils/Errors.sol`

Centralized error definitions for gas-efficient reverts.

```solidity
library Errors {
    error ZeroAddress();
    error ZeroAmount();
    error InsufficientBalance();
    error InsufficientShares();
    error InsufficientAssets();
    error InvalidAdapter();
    error InvalidNGOAddress();
    error NGOAlreadyApproved();
    error NGONotApproved();
    error InvalidConfiguration();
    error ExceedsMaxLoss();
    error ExceedsSlippage();
    error InvestPaused();
    error HarvestPaused();
    // ... more errors
}
```

### **IWETH.sol**

**Location**: `backend/src/utils/IWETH.sol`

WETH interface for ETH vault functionality (future feature).

```solidity
interface IWETH is IERC20 {
    function deposit() external payable;
    function withdraw(uint256 amount) external;
}
```

## 🔐 Access Control & Roles

### **Role Definitions**

```solidity
// Universal admin role
bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

// Vault-specific roles
bytes32 public constant VAULT_MANAGER_ROLE = keccak256("VAULT_MANAGER_ROLE");
bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

// NGO Registry roles
bytes32 public constant NGO_MANAGER_ROLE = keccak256("NGO_MANAGER_ROLE");
bytes32 public constant DONATION_RECORDER_ROLE = keccak256("DONATION_RECORDER_ROLE");
bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");

// Adapter roles
bytes32 public constant ADAPTER_MANAGER_ROLE = keccak256("ADAPTER_MANAGER_ROLE");
```

### **Role Permissions**

| Role | Permissions |
|------|-------------|
| `DEFAULT_ADMIN_ROLE` | Grant/revoke all roles, emergency functions |
| `VAULT_MANAGER_ROLE` | Vault configuration, adapter management |
| `NGO_MANAGER_ROLE` | NGO approval/removal, current NGO selection |
| `PAUSER_ROLE` | Emergency pause/unpause |
| `DONATION_RECORDER_ROLE` | Record donations (assigned to DonationRouter) |
| `ADAPTER_MANAGER_ROLE` | Adapter configuration and parameters |

## 📊 Contract Interactions

### **Typical User Flow**:

1. **Deposit**: `User → GiveVault4626.deposit() → StrategyManager → AaveAdapter.invest()`
2. **Yield Generation**: `AaveAdapter (passive) → Aave Protocol → Generate Interest`
3. **Harvest**: `Admin → GiveVault4626.harvest() → AaveAdapter.harvest() → DonationRouter.distribute() → NGO`
4. **Withdraw**: `User → GiveVault4626.withdraw() → AaveAdapter.divest() (if needed) → User`

### **Administrative Actions**:

1. **Add NGO**: `Admin → NGORegistry.addNGO()`
2. **Set Current NGO**: `Admin → NGORegistry.setCurrentNGO()`
3. **Configure Vault**: `Admin → StrategyManager.setCashBufferBps()`
4. **Emergency**: `Admin → GiveVault4626.pause()`

## 🧪 Testing Contracts

### **MockYieldAdapter.sol**

**Location**: `backend/src/adapters/MockYieldAdapter.sol`

Mock adapter for testing that simulates yield generation without external dependencies.

```solidity
contract MockYieldAdapter is IYieldAdapter {
    uint256 public yieldRate = 500; // 5% APY
    uint256 public constant SECONDS_PER_YEAR = 365 * 24 * 60 * 60;
    
    function simulateYield() external {
        uint256 timeElapsed = block.timestamp - lastUpdate;
        uint256 yield = (totalInvested * yieldRate * timeElapsed) / (BASIS_POINTS * SECONDS_PER_YEAR);
        totalInvested += yield;
        lastUpdate = block.timestamp;
    }
}
```

---

*This contract documentation provides comprehensive technical details for developers and auditors working with GIVE Protocol smart contracts.*