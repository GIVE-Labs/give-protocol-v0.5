# GIVE Protocol Backend Development Guide

This guide outlines how to implement the GIVE Protocol backend (v0.1 → v1) aligned with SystemRequirements.

## Architecture (v0.1)
- ERC-4626 vault: `GiveVault4626` (shares = claim on totalAssets)
- StrategyManager: config surface (active adapter, cash buffer, risk params)
- Adapters: `IYieldAdapter` with Aave/Euler supply-only for MVP
- **DonationRouter**: routes realized profit based on user preferences (50%/75%/100% allocation)
- **User Preferences**: each user selects NGO and allocation percentage
- **Protocol Treasury**: receives remaining yield + 1% protocol fee
- NGO Registry: approve/remove NGOs; validity checks used by vault/router

Key flows: deposit/withdraw per ERC-4626 with cash buffer; `harvest()` realizes P/L and distributes to users based on their preferences.

## Tech Stack
- Foundry + Solidity 0.8.x
- OpenZeppelin (ERC-20, ERC-4626, AccessControl, ReentrancyGuard)
- Anvil/Forge (unit, fork, fuzz, invariants)

## Suggested Directory Structure
```
backend/
├── src/
│   ├── vault/
│   │   └── GiveVault4626.sol
│   ├── manager/
│   │   └── StrategyManager.sol
│   ├── adapters/
│   │   ├── IYieldAdapter.sol
│   │   └── AaveAdapter.sol
│   ├── donation/
│   │   ├── DonationRouter.sol
│   │   └── NGORegistry.sol
│   └── utils/
│       └── Errors.sol
├── test/
│   ├── GiveVault4626.t.sol
│   ├── AaveAdapter.t.sol
│   ├── DonationRouter.t.sol
│   ├── NGORegistry.t.sol
│   └── integration/EndToEnd.t.sol
├── script/
│   ├── Deploy.s.sol
│   └── Smoke.s.sol
├── foundry.toml
└── remappings.txt
```

## Development Workflow
1. Implement interfaces and storage layout
2. Implement `GiveVault4626` using OZ ERC-4626 hooks:
   - `totalAssets() = cash + adapter.totalAssets()`
   - `afterDeposit`: invest excess above cash buffer + update user shares
   - `beforeWithdraw`: divest shortfall with `maxLossBps` + update user shares
3. Implement `IYieldAdapter` + `AaveAdapter` (supply-only)
4. Implement `NGORegistry` and `DonationRouter` with user preferences:
   - `setUserPreference(ngo, allocationPercentage)` - 50%, 75%, or 100%
   - `updateUserShares(user, asset, shares)` - track proportional ownership
   - `distributeToAllUsers(asset, amount)` - distribute based on preferences
5. Wire `harvest()` in vault → adapter.harvest() → DonationRouter.distributeToAllUsers()
6. Add AccessControl roles: DEFAULT_ADMIN, VAULT_MANAGER, NGO_MANAGER, PAUSER

## Risk & Controls (MVP hooks)
- `cashBufferBps`, `slippageBps`, `maxLossBps`
- Pausing: `pauseInvest`, `pauseHarvest` without blocking redemptions
- Reentrancy guards on external entrypoints
- Allowance hygiene & user-favored rounding

## Tests (priorities)
- ERC-4626 math: `previewDeposit/Withdraw/Mint/Redeem`
- Cash buffer invest/divest logic
- Donation flow: profit → DonationRouter → NGO
- Adapter round-trip (unit and fork)
- Reentrancy/pausing invariants

## Quick Commands
```bash
cd backend
forge build
forge test -vv
forge coverage
```

## Next Steps
- v0.2: delayed NGO rotation, granular pause events, best-effort unwind
- v0.3: Pendle PT adapter with oracle/TWAP
- v1: UUPS + Timelock upgrades, external audit

### Deployment
```bash
# Deploy to local
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast

# Deploy to Scroll Sepolia testnet
forge script script/Deploy.s.sol --rpc-url $SCROLL_SEPOLIA_RPC --private-key $PRIVATE_KEY --broadcast --verify

# Verify contracts
forge verify-contract --chain-id 534351 $VAULT_ADDRESS GiveVault4626
```

### Gas Optimization
```bash
# Check gas usage
forge snapshot

# Compare gas usage
forge snapshot --diff

# Gas report
forge test --gas-report
```

## 🛡️ Security Checklist

### Before Each Contract
- [ ] Reentrancy protection implemented
- [ ] Access control properly configured
- [ ] Input validation complete
- [ ] Gas optimization reviewed
- [ ] Events emitted for state changes
- [ ] Emergency mechanisms in place

### Testing Requirements
- [ ] Unit tests for all functions
- [ ] Integration tests for user flows
- [ ] Fuzz testing for edge cases
- [ ] Gas usage benchmarking
- [ ] Security test scenarios

### Deployment Checklist
- [ ] Testnet deployment successful
- [ ] Contract verification complete
- [ ] Documentation updated
- [ ] Monitoring configured
- [ ] Emergency procedures tested

## 📈 Performance Targets

### Gas Usage Optimization
- Deposit (no adapter move): <130,000 gas
- Withdraw (no adapter move): <130,000 gas
- Harvest (adapter-dependent): bounded and eventful
- NGO registration: <100,000 gas

### Test Coverage Goals
- **Line coverage**: 95%+
- **Function coverage**: 100%
- **Branch coverage**: 90%+
- **Integration scenarios**: 100%

## 🔄 Next Steps

### Immediate Actions (Next 30 minutes)
1. Initialize Foundry backend (5 min)
2. Scaffold ERC-4626 vault + interfaces (10 min)
3. Write initial ERC-4626 math tests (15 min)

### Next Hour
1. Implement NGORegistry.sol (30 min)
2. Write comprehensive tests (30 min)

### Next 2 Hours
1. Implement AaveAdapter.sol (60 min)
2. Implement DonationRouter.sol (45 min)
3. Integration testing (15 min)

## 🔗 Scroll Sepolia Resources

### Network Configuration
- **Chain ID**: 534351
- **RPC URL**: https://sepolia-rpc.scroll.io
- **Explorer**: https://sepolia.scrollscan.com
- **Bridge**: https://sepolia.scroll.io/bridge

### Deployment Addresses (TBD)
- GiveVault4626 (USDC): `0x...`
- StrategyManager: `0x...`
- NGORegistry: `0x...`
- DonationRouter: `0x...`

---

**Ready to implement GIVE Protocol v0.1 on Scroll Sepolia**
