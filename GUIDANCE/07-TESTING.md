# Testing Guide - GIVE Protocol

## 🧪 Testing Strategy Overview

GIVE Protocol employs a comprehensive testing strategy covering smart contracts, frontend components, and end-to-end user flows.

## 🌐 Latest Testing Updates
- All core contracts tested and verified on Sepolia
- New test coverage for account-based deployment, asset validation, and access control
- Updated test suite for multi-network support

## 🔧 Smart Contract Testing

### **Testing Framework: Foundry**

GIVE Protocol uses Foundry's testing framework with the following structure:

```
backend/test/
├── VaultRouter.t.sol      # Core integration tests
├── Router.t.sol           # Donation router tests  
├── AaveAdapterBasic.t.sol # Adapter functionality tests
├── StrategyManagerBasic.t.sol # Strategy management tests
├── UserPreferences.t.sol  # User preference tests
├── VaultETH.t.sol        # ETH vault tests
├── VaultETH_Aave.t.sol   # ETH vault with Aave tests
└── Fork_AaveSepolia.t.sol # Fork testing against live Aave
```

### **Test Categories**

#### **1. Unit Tests**
Test individual contract functions in isolation.

```solidity
contract GiveVault4626Test is Test {
    function test_deposit_success() public {
        // Setup
        uint256 depositAmount = 1000e6; // 1000 USDC
        deal(address(usdc), user, depositAmount);
        
        // Execute
        vm.startPrank(user);
        usdc.approve(address(vault), depositAmount);
        uint256 shares = vault.deposit(depositAmount, user);
        vm.stopPrank();
        
        // Assert
        assertEq(shares, depositAmount); // 1:1 ratio initially
        assertEq(vault.balanceOf(user), shares);
        assertEq(usdc.balanceOf(user), 0);
    }
}
```

#### **2. Integration Tests**
Test interactions between multiple contracts.

```solidity
contract VaultRouterTest is Test {
    function test_full_deposit_harvest_donate_cycle() public {
        // 1. User deposits
        vm.startPrank(user);
        usdc.approve(address(vault), 1000e6);
        vault.deposit(1000e6, user);
        vm.stopPrank();
        
        // 2. Simulate yield generation
        adapter.simulateYield();
        
        // 3. Harvest and donate
        vm.prank(manager);
        vault.harvest();
        
        // 4. Verify donation
        assertGt(usdc.balanceOf(ngo), 0);
        assertTrue(registry.ngoInfo(ngo).totalReceived > 0);
    }
}
```

#### **3. Fork Tests**
Test against live mainnet/testnet data.

```solidity
contract Fork_AaveSepoliaTest is Test {
    uint256 sepoliaFork;
    
    function setUp() public {
        sepoliaFork = vm.createFork(vm.envString("SEPOLIA_RPC_URL"));
        vm.selectFork(sepoliaFork);
        
        // Use real Aave addresses on Sepolia
        aavePool = IPool(0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951);
    }
    
    function test_real_aave_integration() public {
        // Test with actual Aave protocol
    }
}
```

### **Running Smart Contract Tests**

```bash
cd backend

# Run all tests
make test

# Run specific test file
forge test --match-path test/VaultRouter.t.sol

# Run specific test function
forge test --match-test test_deposit_success

# Run with verbose output
forge test -vvv

# Run fork tests
make test-fork

# Generate coverage report
forge coverage

# Gas optimization report
forge test --gas-report
```

### **Key Test Scenarios**

#### **Core Vault Functionality**
- ✅ Deposit and withdrawal flows
- ✅ Share calculation and redemption
- ✅ Cash buffer management
- ✅ Total assets accounting
- ✅ Emergency pause functionality

#### **Yield Generation**
- ✅ Adapter investment and divestment
- ✅ Yield harvesting mechanics
- ✅ Profit and loss calculation
- ✅ Emergency withdrawal from adapters

#### **Donation System**
- ✅ NGO registration and approval
- ✅ Donation routing and fee handling
- ✅ Multi-NGO distribution support
- ✅ Donation recording and tracking

#### **Access Control**
- ✅ Role-based permission testing
- ✅ Unauthorized access prevention
- ✅ Role granting and revoking

#### **Edge Cases**
- ✅ Zero amount operations
- ✅ Maximum value handling
- ✅ Slippage protection
- ✅ Loss limitation enforcement

### **Test Data & Helpers**

#### **Mock Contracts**

**MockERC20.sol**:
```solidity
contract MockERC20 is ERC20 {
    uint8 private _decimals;
    
    constructor(string memory name, string memory symbol, uint8 decimals_) ERC20(name, symbol) {
        _decimals = decimals_;
    }
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
    
    function decimals() public view override returns (uint8) {
        return _decimals;
    }
}
```

**MockYieldAdapter.sol**:
```solidity
contract MockYieldAdapter is IYieldAdapter {
    uint256 public yieldRate = 500; // 5% APY
    uint256 public totalInvested;
    
    function simulateYield() external {
        // Simulate passage of time and yield accrual
        uint256 yield = (totalInvested * yieldRate) / 10000;
        totalInvested += yield;
    }
}
```

#### **Test Utilities**

```solidity
contract TestHelpers {
    function dealTokens(address token, address to, uint256 amount) internal {
        deal(token, to, amount);
    }
    
    function skipTime(uint256 seconds_) internal {
        vm.warp(block.timestamp + seconds_);
    }
    
    function expectRevertWithSelector(bytes4 selector) internal {
        vm.expectRevert(selector);
    }
}
```

## 🖥️ Frontend Testing

### **Testing Framework: Vitest + Testing Library**

Frontend testing setup (to be implemented):

```json
{
  "devDependencies": {
    "@testing-library/react": "^13.4.0",
    "@testing-library/jest-dom": "^5.16.5",
    "vitest": "^0.32.0",
    "jsdom": "^22.1.0"
  }
}
```

### **Component Testing**

#### **Example: Button Component Test**

```tsx
import { render, screen } from '@testing-library/react';
import { describe, it, expect } from 'vitest';
import Button from '../components/ui/Button';

describe('Button Component', () => {
  it('renders with correct text', () => {
    render(<Button>Click me</Button>);
    expect(screen.getByRole('button')).toHaveTextContent('Click me');
  });

  it('shows loading state', () => {
    render(<Button loading>Click me</Button>);
    expect(screen.getByRole('button')).toBeDisabled();
  });
});
```

#### **Web3 Component Testing**

```tsx
import { render } from '@testing-library/react';
import { WagmiConfig } from 'wagmi';
import { mockClient } from './test-utils';
import CampaignStaking from '../pages/CampaignStaking';

describe('CampaignStaking', () => {
  it('shows connect wallet when disconnected', () => {
    render(
      <WagmiConfig client={mockClient}>
        <CampaignStaking />
      </WagmiConfig>
    );
    
    expect(screen.getByText('Connect Wallet')).toBeInTheDocument();
  });
});
```

### **Frontend Test Categories**

#### **1. Unit Tests**
- Component rendering
- State management
- Utility functions
- Form validation

#### **2. Integration Tests**
- User interaction flows
- Web3 connection
- Contract interaction mocking

#### **3. E2E Tests** (Planned)
- Full user journeys
- Cross-browser compatibility
- Mobile responsiveness

### **Running Frontend Tests**

```bash
cd frontend

# Run tests (when implemented)
pnpm test

# Run tests in watch mode
pnpm test:watch

# Run tests with coverage
pnpm test:coverage

# Type checking
pnpm type-check

# Linting
pnpm lint
```

## 🔄 Continuous Integration Testing

### **GitHub Actions Workflow** (Planned)

```yaml
name: CI/CD Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  backend-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Install Foundry
        uses: foundry-rs/foundry-toolchain@v1
      - name: Run tests
        run: |
          cd backend
          forge build
          forge test
      - name: Coverage
        run: |
          cd backend
          forge coverage

  frontend-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
      - name: Install pnpm
        run: npm install -g pnpm
      - name: Install dependencies
        run: |
          cd frontend
          pnpm install
      - name: Type check
        run: |
          cd frontend
          pnpm type-check
      - name: Run tests
        run: |
          cd frontend
          pnpm test
```

## 📊 Test Coverage Goals

### **Smart Contract Coverage**

Target coverage levels:
- **Line Coverage**: >95%
- **Branch Coverage**: >90%
- **Function Coverage**: 100%

Current coverage (example):
```
| File                    | % Lines | % Statements | % Branches | % Funcs |
|-------------------------|---------|-------------|------------|---------|
| src/vault/GiveVault4626 | 98.5%   | 98.2%       | 92.3%      | 100%    |
| src/donation/NGORegistry| 96.8%   | 96.5%       | 89.1%      | 100%    |
| src/adapters/AaveAdapter| 94.2%   | 94.0%       | 87.5%      | 100%    |
```

### **Frontend Coverage**

Target coverage levels:
- **Component Coverage**: >90%
- **Hook Coverage**: >95%
- **Utility Coverage**: 100%

## 🔍 Testing Best Practices

### **Smart Contract Testing**

1. **Test Edge Cases**:
   ```solidity
   function test_deposit_zero_amount_reverts() public {
       vm.expectRevert(Errors.ZeroAmount.selector);
       vault.deposit(0, user);
   }
   ```

2. **Test Access Control**:
   ```solidity
   function test_only_vault_manager_can_set_adapter() public {
       vm.expectRevert();
       vm.prank(user);
       vault.setActiveAdapter(address(newAdapter));
   }
   ```

3. **Test Event Emissions**:
   ```solidity
   function test_deposit_emits_event() public {
       vm.expectEmit(true, true, false, true);
       emit Deposit(user, user, 1000e6, 1000e6);
       
       vm.startPrank(user);
       usdc.approve(address(vault), 1000e6);
       vault.deposit(1000e6, user);
       vm.stopPrank();
   }
   ```

4. **Use Fuzzing**:
   ```solidity
   function testFuzz_deposit(uint256 amount) public {
       vm.assume(amount > 0 && amount <= type(uint128).max);
       deal(address(usdc), user, amount);
       
       vm.startPrank(user);
       usdc.approve(address(vault), amount);
       uint256 shares = vault.deposit(amount, user);
       vm.stopPrank();
       
       assertEq(shares, vault.balanceOf(user));
   }
   ```

### **Frontend Testing**

1. **Mock External Dependencies**:
   ```tsx
   // Mock wagmi hooks
   vi.mock('wagmi', () => ({
     useAccount: () => ({ address: '0x123', isConnected: true }),
     useReadContract: () => ({ data: mockContractData }),
   }));
   ```

2. **Test User Interactions**:
   ```tsx
   import userEvent from '@testing-library/user-event';
   
   it('handles form submission', async () => {
     const user = userEvent.setup();
     render(<StakeForm />);
     
     await user.type(screen.getByLabelText('Amount'), '100');
     await user.click(screen.getByRole('button', { name: 'Stake' }));
     
     expect(mockWriteContract).toHaveBeenCalled();
   });
   ```

3. **Test Error States**:
   ```tsx
   it('shows error for insufficient balance', () => {
     render(<StakeForm balance="50" />);
     
     userEvent.type(screen.getByLabelText('Amount'), '100');
     
     expect(screen.getByText('Insufficient balance')).toBeInTheDocument();
   });
   ```

## 🚨 Testing Troubleshooting

### **Common Issues**

#### **Foundry Test Issues**
```bash
# Clean and rebuild
forge clean && forge build

# Update dependencies
forge update

# Check Foundry version
forge --version
```

#### **Fork Test Issues**
```bash
# Verify RPC URL
echo $SEPOLIA_RPC_URL

# Check network connectivity
curl -X POST $SEPOLIA_RPC_URL -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
```

#### **Gas Limit Issues**
```bash
# Increase gas limit in tests
forge test --gas-limit 30000000
```

### **Debugging Test Failures**

1. **Use Console Logging**:
   ```solidity
   import "forge-std/console.sol";
   
   function test_debug() public {
       console.log("Balance:", token.balanceOf(user));
       console.log("Allowance:", token.allowance(user, vault));
   }
   ```

2. **Trace Execution**:
   ```bash
   forge test -vvvv --match-test test_failing_function
   ```

3. **Check Revert Reasons**:
   ```solidity
   vm.expectRevert("Specific error message");
   ```

## 📈 Performance Testing

### **Gas Optimization Testing**

```bash
# Generate gas report
forge test --gas-report

# Snapshot testing for gas optimization
forge snapshot
```

### **Load Testing** (Future)

For mainnet deployment:
- Stress test with high transaction volumes
- Test under network congestion
- Verify MEV protection

---

*This testing guide ensures comprehensive coverage and quality assurance for GIVE Protocol.*