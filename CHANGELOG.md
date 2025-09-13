GIVE Protocol Changelog

All notable changes to the GIVE Protocol will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2025-09-13

### Added - MVP Release (Aave/Euler only, single NGO)

#### Core Vault System
- **GiveVault4626**: ERC-4626 compliant vault with cash buffer functionality
  - Cash buffer management (1% default)
  - Single active adapter support
  - Yield harvesting and donation distribution
  - Emergency pause functionality
  - Role-based access control (VAULT_MANAGER, PAUSER)
  - Integration with StrategyManager and DonationRouter

- **StrategyManager**: Centralized adapter and strategy management
  - Single active adapter configuration
  - Cash buffer management (1% default)
  - Slippage tolerance configuration (0.5% default)
  - Maximum loss protection (0.5% default)
  - Adapter allocation and rebalancing
  - Emergency functions for asset recovery

#### Yield Generation
- **AaveAdapter**: Supply-only yield adapter for Aave protocol
  - USDC supply to Aave lending pools
  - Automatic yield harvesting
  - Total assets calculation
  - Emergency withdrawal capabilities
  - Integration with vault and strategy manager

#### Donation System
- **NGORegistry**: NGO approval and management system
  - NGO registration with comprehensive metadata
  - Approval/removal workflow
  - Current NGO selection for donations
  - Donation tracking and analytics
  - Role-based access control (NGO_MANAGER)

- **DonationRouter**: Profit distribution to approved NGOs
  - Flat split donation distribution
  - Optional fee configuration (2.5% default)
  - Fee recipient management
  - Weighted distribution support
  - Current NGO preference handling
  - Emergency pause functionality

#### Access Control & Security
- **Role-based Access Control**: Comprehensive permission system
  - `DEFAULT_ADMIN_ROLE`: System administration
  - `VAULT_MANAGER_ROLE`: Vault configuration and management
  - `NGO_MANAGER_ROLE`: NGO approval and management
  - `PAUSER_ROLE`: Emergency pause capabilities
  - `DONATION_MANAGER_ROLE`: Donation distribution control
  - `ADAPTER_MANAGER_ROLE`: Yield adapter management

- **Security Features**:
  - Reentrancy protection on all external calls
  - Emergency pause functionality across all contracts
  - Maximum loss protection for yield strategies
  - Slippage tolerance for adapter operations
  - Access control on all administrative functions

#### Configuration Parameters
- **Cash Buffer**: 1% of total assets kept in vault for immediate withdrawals
- **Slippage Tolerance**: 0.5% maximum slippage for adapter operations
- **Maximum Loss**: 0.5% maximum acceptable loss during strategy operations
- **Fee Structure**: 2.5% optional fee on donations with configurable recipient

### Testing Infrastructure

#### Unit Tests
- **GiveVault4626.t.sol**: Comprehensive vault functionality testing
  - Deposit/withdrawal operations
  - Cash buffer management
  - Adapter integration
  - Emergency functions
  - Access control verification

- **StrategyManager.t.sol**: Strategy management testing
  - Adapter configuration
  - Rebalancing operations
  - Emergency functions
  - Role-based access control

- **AaveAdapter.t.sol**: Yield adapter testing
  - Investment/divestment operations
  - Yield harvesting
  - Total assets calculation
  - Emergency functions

- **NGORegistry.t.sol**: NGO management testing
  - NGO registration and approval
  - Metadata management
  - Current NGO selection
  - Donation tracking

- **DonationRouter.t.sol**: Donation distribution testing
  - Flat split distribution
  - Weighted distribution
  - Fee configuration
  - Emergency functions

#### Integration & End-to-End Tests
- **Integration.t.sol**: Cross-contract integration testing
  - Complete deposit/withdraw cycles
  - Yield generation and harvesting
  - Multi-user scenarios
  - NGO management workflows
  - Emergency scenarios

- **EndToEnd.t.sol**: Fork testing against mainnet
  - Real Aave protocol integration
  - Gas optimization verification
  - Reentrancy attack protection

### Changed (2025-09-13)

- Align v0.1 donation flow: `GiveVault4626.harvest()` now transfers profit to `DonationRouter` and immediately calls `distribute(asset, amount)` to avoid stranded funds.
- Harden NGO accounting: `NGORegistry.recordDonation` is now restricted by `DONATION_RECORDER_ROLE` (granted to `DonationRouter`).
- Replace legacy tests with v0.1-aligned suite:
  - Added `VaultRouter.t.sol` covering deposit → invest (cash buffer) → harvest → router donation → withdraw.
  - Added `Router.t.sol` covering fee config, authorized callers, `distribute` and `distributeToMultiple` flows.
  - Added `AaveAdapterBasic.t.sol` for invest/divest/harvest happy-path and access control.
  - Added `StrategyManagerBasic.t.sol` for adapter approval/activation and vault parameter updates.
- Removed outdated tests referencing deprecated APIs (multi-mode router, allocations/rebalance API, Morph prototype).
- forge build: green. forge test: updated, but execution blocked in sandbox; run locally to verify.
  - Large-scale operation testing

### Deployment Infrastructure

#### Deployment Scripts
- **Deploy.s.sol**: Comprehensive deployment script
  - Multi-network support (Ethereum, Polygon, Arbitrum, Base)
  - Automated contract deployment and configuration
  - Role setup and permission management
  - Deployment verification and validation
  - Network-specific configuration

- **SmokeTestScript**: Post-deployment validation
  - Basic deposit/withdrawal testing
  - System integration verification
  - Smoke test automation

#### Network Support
- **Mainnet Networks**:

- **Testnet Networks**:
  - Scroll Sepolia

### Architecture Decisions

#### Design Principles
- **Modularity**: Separate contracts for distinct responsibilities
- **Upgradeability**: Prepared for future proxy upgrade implementation
- **Security**: Multiple layers of protection and access control
- **Efficiency**: Gas-optimized operations and minimal external calls
- **Transparency**: Comprehensive event emission for off-chain tracking

#### Contract Interactions
```
GiveVault4626
├── StrategyManager (yield strategy management)
│   └── AaveAdapter (Aave protocol integration)
└── DonationRouter (profit distribution)
    └── NGORegistry (NGO management)
```

#### Key Features
- **ERC-4626 Compliance**: Standard vault interface for DeFi integration
- **Cash Buffer**: Immediate liquidity for user withdrawals
- **Single Adapter**: Simplified yield strategy with Aave focus
- **Flat Distribution**: Equal profit sharing among approved NGOs
- **Emergency Controls**: Comprehensive pause and recovery mechanisms

### Technical Specifications

#### Dependencies
- **OpenZeppelin Contracts v5.0.0**:
  - ERC4626 (vault standard)
  - AccessControl (role management)
  - ReentrancyGuard (reentrancy protection)
  - Pausable (emergency controls)
  - SafeERC20 (safe token operations)

- **Foundry Framework**:
  - Forge (testing and compilation)
  - Cast (blockchain interaction)
  - Anvil (local development)

#### Solidity Version
- **Compiler**: Solidity ^0.8.20
- **EVM Version**: Paris (post-merge)
- **Optimization**: Enabled with 200 runs

### Events & Monitoring

#### Vault Events
- `Deposit(caller, owner, assets, shares)`
- `Withdraw(caller, receiver, owner, assets, shares)`
- `YieldHarvested(amount, donationAmount)`
- `CashBufferUpdated(oldBuffer, newBuffer)`
- `ActiveAdapterChanged(oldAdapter, newAdapter)`

#### NGO Events
- `NGOAdded(ngoAddress, name, description)`
- `NGORemoved(ngoAddress, reason)`
- `NGOUpdated(ngoAddress, field, oldValue, newValue)`
- `CurrentNGOSet(oldNGO, newNGO)`
- `DonationRecorded(ngoAddress, amount, timestamp)`

#### Donation Events
- `DonationDistributed(totalAmount, ngoCount, feeAmount)`
- `FeeConfigurationUpdated(oldFeeBps, newFeeBps, oldRecipient, newRecipient)`
- `WeightedDistribution(ngoAddresses, amounts, weights)`

### Security Considerations

#### Implemented Protections
- **Reentrancy Guards**: All external calls protected
- **Access Control**: Role-based permissions on all admin functions
- **Input Validation**: Comprehensive parameter validation
- **Emergency Pauses**: Circuit breakers for all major operations
- **Maximum Loss Limits**: Configurable loss tolerance for yield operations
- **Slippage Protection**: Configurable slippage tolerance for swaps

#### Audit Recommendations
- Regular security audits before mainnet deployment
- Formal verification of critical mathematical operations
- Stress testing with large asset amounts
- Time-locked administrative operations for production

### Future Roadmap

#### Planned for v0.2
- **Multi-Adapter Support**: Multiple yield strategies simultaneously
- **Proxy Upgrades**: Upgradeable contract architecture
- **Advanced Distribution**: Time-weighted and impact-based allocation
- **Governance Token**: Community governance and incentives

#### Planned for v0.3
- **Cross-Chain Support**: Multi-chain deployment and bridging
- **Advanced Strategies**: Leveraged yield farming and derivatives
- **Impact Tracking**: On-chain impact measurement and verification
- **DAO Governance**: Fully decentralized autonomous organization

### Breaking Changes
- Initial release - no breaking changes

### Migration Guide
- Initial release - no migration required

### Contributors
- Development Team: GIVE Protocol Core Team
- Security Review: [Pending]
- Community Testing: [Pending]

---

**Note**: This is the initial MVP release focusing on core functionality with Aave integration. Future versions will expand capabilities while maintaining backward compatibility where possible.
