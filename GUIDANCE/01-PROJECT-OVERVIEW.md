# Project Overview - GIVE Protocol

## 🎯 Vision & Mission

**GIVE Protocol** is a revolutionary no-loss giving platform that bridges traditional charitable giving with modern DeFi yield generation. Our mission is to enable sustainable funding for NGOs while preserving donor capital.

## � Latest Status

**MVP deployed and live on Ethereum Sepolia testnet (Sepolia Chain ID: 11155111)**
- All core contracts deployed and verified
- Frontend and backend updated for Sepolia support
- See deployment details in [06-DEPLOYMENT.md](06-DEPLOYMENT.md)


## �💡 The Problem We Solve

Traditional NGO donations suffer from several critical issues:
- **Capital Loss**: Donors lose their money forever
- **Intermediary Fees**: 30-50% goes to intermediaries, not the cause
- **Lack of Transparency**: No clear visibility into fund usage
- **Zero Engagement**: No ongoing relationship after donation

## 🔧 Our Solution

GIVE Protocol enables users to:
1. **Deposit crypto assets** (USDC, ETH) into ERC-4626 vaults
2. **Keep principal redeemable** while assets generate yield
3. **Donate only the yield** to approved NGOs
4. **Choose donation percentages** (50%, 75%, or 100% of yield)
5. **Withdraw anytime** subject to vault liquidity

## 🏗️ Deployed Contracts (Sepolia)

- GiveVault4626 (USDC): `0x9816de1f27c15AAe597548f09E2188d16752C4C8`
- StrategyManager: `0x42cB507dfe0f7D8a01c9ad9e1b18B84CCf0A41B9`
- AaveAdapter: `0xFc03875B2B2a84D9D1Bd24E41281fF371b3A1948`
- NGORegistry: `0x77182f2C8E86233D3B0095446Da20ecDecF96Cc2`
- DonationRouter: `0x33952be800FbBc7f8198A0efD489204720f64A4C`

## 🏗️ How It Works

```
User Deposit → ERC-4626 Vault → Yield Adapter (Aave) → Yield Generation
                     ↓
Principal Stays Redeemable ← Cash Buffer ← Harvest Yield → Donation Router → NGO
```

### Example Flow:
1. User deposits 1,000 USDC into GiveVault4626
2. Vault keeps 1% cash buffer (10 USDC) for withdrawals
3. Remaining 990 USDC supplied to Aave via adapter
4. Aave generates ~5% APY = 49.5 USDC/year yield
5. User chooses 75% donation = 37.125 USDC to NGO
6. Remaining 12.375 USDC goes to protocol treasury
7. User can withdraw their 1,000 USDC principal anytime

## 🎯 Core Value Propositions

### For Donors:
- ✅ **Keep your money** - Principal always redeemable
- ✅ **Choose your impact** - 50%, 75%, or 100% yield donation
- ✅ **Transparent giving** - All transactions on-chain
- ✅ **Flexible commitment** - 6, 12, or 24-month periods
- ✅ **Multiple assets** - USDC, ETH, WETH support

### For NGOs:
- ✅ **Sustainable funding** - Continuous yield-based donations
- ✅ **Lower barriers** - No upfront capital requirements
- ✅ **Transparent tracking** - All donations recorded on-chain
- ✅ **Verification system** - KYC/attestation support
- ✅ **Global reach** - Borderless crypto donations

### For the Ecosystem:
- ✅ **Capital efficiency** - Productive use of idle assets
- ✅ **Sustainable model** - Protocol fees ensure long-term viability
- ✅ **Composable DeFi** - Integrates with existing yield protocols
- ✅ **Innovation catalyst** - New primitive for charitable giving

## 📊 Market Opportunity

- **Global NGO sector**: $1.5+ trillion annually
- **Crypto market cap**: $2+ trillion
- **DeFi TVL**: $100+ billion
- **Yield farming**: $50+ billion in various protocols

GIVE Protocol sits at the intersection of these massive markets, creating a new category of "yield philanthropy."

## 🛣️ Roadmap

### ✅ v0.1 MVP (Current)
- Single NGO support per vault
- Aave yield adapter
- Basic frontend interface
- Scroll Sepolia deployment

### 🔄 v0.2 (Q1 2025)
- Multi-NGO allocation per user
- Pendle PT yield adapters
- Enhanced user preferences
- Governance token launch

### 🎯 v1.0 (Q2 2025)
- Cross-chain deployment
- Advanced yield strategies
- DAO governance system
- Institutional partnerships

## 🏆 Competitive Advantages

1. **No-Loss Model**: Unlike traditional donations, principal preservation
2. **Yield Optimization**: Professional DeFi yield strategies
3. **Transparency**: Full on-chain auditability
4. **Flexibility**: Customizable allocation and time periods
5. **Composability**: Integrates with existing DeFi ecosystem
6. **Scalability**: Can support unlimited NGOs and yield sources

## 📈 Success Metrics

- **Total Value Locked (TVL)**: Target $10M by end of 2025
- **NGO Partnerships**: 100+ verified NGOs
- **Yield Generated**: $1M+ donated through yield
- **User Adoption**: 10,000+ active donors
- **Network Effects**: Integration with 5+ major DeFi protocols

## 🌍 Social Impact

GIVE Protocol has the potential to:
- Generate millions in sustainable NGO funding
- Introduce crypto users to charitable giving
- Create new fundraising models for nonprofits
- Bridge traditional finance and DeFi for social good
- Enable global, borderless philanthropy

---

*This overview provides the foundation for understanding GIVE Protocol. For technical details, see the other documentation files in this GUIDANCE folder.*