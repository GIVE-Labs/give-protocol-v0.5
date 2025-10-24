# GIVE Protocol v0.5 – No-Loss Giving on Base

> **Principal Protection Guaranteed**: Donors deposit assets → Earn yield → 100% of profits fund social impact campaigns → Withdraw principal anytime

**Status:** ✅ **DEPLOYED TO BASE SEPOLIA** (October 24, 2025)  
**Tests:** ✅ **116/116 passing** | **Verified:** ✅ **9/9 contracts on Basescan**  
**Network:** Base Sepolia (Chain ID: 84532) | [View Deployment →](./DEPLOYMENT.md)

---

## � Quick Start

### For Users
1. Get Base Sepolia ETH: https://www.coinbase.com/faucets/base-ethereum-sepolia-faucet
2. Wrap to WETH: `0x4200000000000000000000000000000000000006`
3. Deposit to vault: `0x28ac6D6505E2875FFF9E13d1B788A8d4740a7278`
4. **Your principal stays safe** - only yield goes to campaigns!

### For Developers
```bash
# Backend (Foundry)
cd backend
forge build && forge test

# Frontend (Next.js)
cd apps/web
pnpm install && pnpm dev
```

**Contract Addresses:** All deployed addresses in `DEPLOYMENT.md` or `apps/web/src/config/addresses.ts`

---

## 📊 Deployed Contracts (Base Sepolia)

| Contract | Address | Purpose |
|----------|---------|---------|
| **ACLManager** | `0xC6454Ec62f53823692f426F1fb4Daa57c184A36A` | Role-based access control |
| **GiveProtocolCore** | `0xB73B90207D6Fe0e44A090002bf4e2e9aA37564D9` | Protocol orchestrator |
| **CampaignRegistry** | `0x51929ec1C089463fBeF6148B86F34117D9CCF816` | Campaign lifecycle |
| **PayoutRouter** | `0xe1BD0BA2e0891c95Bd02eA248f8115E7c7DC37c5` | Yield distribution |
| **GIVE WETH Vault** | `0x28ac6D6505E2875FFF9E13d1B788A8d4740a7278` | Main deposit vault |

**Full list:** See `DEPLOYMENT.md` for all addresses, gas costs, and verification links

---

## ✅ What's Complete (Phase 0-17)

- ✅ **Core Architecture** - UUPS proxies, shared storage, ACL governance
- ✅ **Vault System** - ERC-4626 vaults with 99% auto-investment, 1% cash buffer
- ✅ **Yield Adapters** - Aave, Compound integration + MockYieldAdapter
- ✅ **Campaign System** - Registry, factory (EIP-1167 clones), checkpoint voting
- ✅ **Payout System** - Campaign-aware yield distribution via PayoutRouter
- ✅ **Strategy Manager** - Adapter validation and risk management
- ✅ **Security Audit** - Flash loan protection, emergency controls, fee timelocks
- ✅ **Testnet Deployment** - Base Sepolia with 41.5M gas (0.0000415 ETH)
- ✅ **Contract Verification** - All 9 implementations verified on Basescan
- ✅ **Functional Testing** - Deposit/withdraw/harvest flows tested successfully

### Key Metrics
- **Factory Size:** 5KB (was 26KB - 80% reduction via EIP-1167)
- **Gas Costs:** Deposit ~320k | Withdraw ~138k | Harvest ~490k
- **Test Coverage:** 116/116 passing (ACL, vaults, campaigns, payouts)
- **Documentation:** Architecture, operations guide, emergency procedures

See `DEPLOYMENT.md` for complete deployment details and `docs/` for technical documentation.

---

## Architecture Overview

%% Architecture Diagram

flowchart TB
    subgraph Users
        U[Supporters/Donors]
    end

    subgraph Governance
        ACL[ACLManager Role-Based Access Control]
        MS[Multisig + Timelock]
    end

    subgraph Campaign System
        CR[CampaignRegistry Lifecycle Management]
        SR[StrategyRegistry Risk Tiers & Adapters]
        VF[VaultFactory Deploy Campaign Vaults]
    end

    subgraph Core Vault Layer
        V1[CampaignVault 4626]
        V2[CampaignVault 4626]
    end

    subgraph Yield Generation
        A1[AaveAdapter]
        A2[CompoundAdapter]
        A3[MockAdapter]
    end

    subgraph Distribution
        PR[PayoutRouter Yield Distribution]
        CAMP[Campaign Recipients]
    end

    MS --> ACL
    ACL -.->|Controls| CR
    ACL -.->|Controls| VF
    ACL -.->|Controls| PR

    CR -->|Metadata| VF
    SR -->|Strategy Config| VF
    VF -->|Deploys| V1
    VF -->|Deploys| V2

    U -->|Deposit| V1
    U -->|Deposit| V2

    V1 -->|Auto-Invest 99%| A1
    V2 -->|Auto-Invest 99%| A2

    A1 -->|Harvest Yield| PR
    A2 -->|Harvest Yield| PR

    PR -->|50% Campaign| CAMP
    PR -->|50% Supporter| U

    CR -.->|Checkpoint Voting| CAMP
    U -.->|Vote on Milestones| CR

    style ACL fill:#e74c3c,stroke:#333,stroke-width:2px,color:#fff
    style V1 fill:#4a90e2,stroke:#333,stroke-width:2px,color:#fff
    style V2 fill:#4a90e2,stroke:#333,stroke-width:2px,color:#fff
    style PR fill:#27ae60,stroke:#333,stroke-width:2px,color:#fff
    style CAMP fill:#f39c12,stroke:#333,stroke-width:2px,color:#fff


### Core Architecture Principles

- **Governance:** Multisig + Timelock → ACLManager issues role-based permissions for all protocol operations
- **Campaign-Centric:** Each campaign gets its own ERC-4626 vault deployed by the factory with strategy-specific risk parameters
- **Auto-Investment:** 99% of deposits automatically flow to yield adapters (Aave, Compound), 1% kept as cash buffer
- **Yield Distribution:** PayoutRouter splits harvested yield between campaigns (default 80%) and supporters (default 50%)
- **Checkpoint Voting:** Supporters vote on campaign milestones; failed checkpoints halt payouts until resolved
- **Upgradeability:** All core contracts use UUPS proxies controlled by ACL's `ROLE_UPGRADER`
- **Shared Storage:** Module libraries (VaultModule, AdapterModule, etc.) operate on a single storage struct via `StorageLib`

**Principal Protection:** User deposits remain withdrawable at all times (subject to optional lock periods). Only yield flows to campaigns.

**For full technical details**, see [`docs/ARCHITECTURE.md`](/docs/ARCHITECTURE.md) - includes governance flows, emergency procedures, and security model.

---

## 📁 Repository Structure

```
backend/          Foundry contracts + tests (116 passing)
  src/            Modular v0.5 architecture
    core/         GiveProtocolCore orchestrator
    governance/   ACLManager role-based access
    vault/        ERC-4626 vaults + auto-investment
    adapters/     Yield generation (Aave, Mock)
    registry/     Campaign & strategy registries
    payout/       PayoutRouter for yield distribution
  test/           Integration & unit tests
  script/         Bootstrap.s.sol (single deployment script)

apps/web/         Next.js 14 frontend (RainbowKit + Wagmi)
docs/             Technical documentation
  TESTNET_OPERATIONS_GUIDE.md    User guide (100+ sections)
  ARCHITECTURE.md                System design
  EMERGENCY_PROCEDURES.md        Incident response

DEPLOYMENT.md     Complete deployment details + addresses
README.md         This file (quick start + overview)
```

---

## 🛠️ Development

### Local Testing
```bash
cd backend
forge build           # Compile contracts
forge test -vv        # Run 116 tests
forge snapshot        # Gas benchmarks
```

### Testnet Interaction
```bash
# Example: Deposit 0.1 WETH to vault
source .env
cast send $WETH "approve(address,uint256)" $VAULT 100000000000000000 \
  --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY

cast send $VAULT "deposit(uint256,address)" 100000000000000000 $YOUR_ADDRESS \
  --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

**Full operations guide:** `docs/TESTNET_OPERATIONS_GUIDE.md`

### Frontend Development
```bash
cd apps/web
pnpm install
pnpm dev              # http://localhost:3000
```

Contract addresses configured in `apps/web/src/config/addresses.ts`

---

## 📚 Documentation

- **`DEPLOYMENT.md`** - Deployment summary, all addresses, gas costs, operations guide
- **`docs/ARCHITECTURE.md`** - System design, data flows, security model
- **`docs/TESTNET_OPERATIONS_GUIDE.md`** - Step-by-step user guide
- **`docs/EMERGENCY_PROCEDURES.md`** - Incident response procedures
- **`.github/copilot-instructions.md`** - AI agent context for development

---

## 🔐 Security Principles

1. **Principal Protection** - User deposits always withdrawable (yield-only campaigns)
2. **UUPS Upgrades** - Only `ROLE_UPGRADER` can upgrade via ACL
3. **Role-Based Access** - No `Ownable`, all permissions via ACLManager
4. **Shared Storage** - All state via `StorageLib` for consistency
5. **Emergency Controls** - Pause, emergency withdraw, grace periods
6. **EIP-1167 Clones** - Campaign vaults as minimal proxies (gas efficient)

**Audit Status:** All critical/high issues resolved | Flash loan protection | Fee timelocks

---

## 🌐 Links

- **Testnet:** https://sepolia.basescan.org
- **Base Sepolia Faucet:** https://www.coinbase.com/faucets/base-ethereum-sepolia-faucet
- **Deployment Details:** [DEPLOYMENT.md](./DEPLOYMENT.md)
- **Operations Guide:** [docs/TESTNET_OPERATIONS_GUIDE.md](./docs/TESTNET_OPERATIONS_GUIDE.md)

---

## 📞 Support

- **Issues:** Open GitHub issue with transaction hash
- **Documentation:** Check `docs/` for technical details
- **Operations:** See testnet operations guide for troubleshooting

---

*Last Updated: October 24, 2025 | Version: 0.5.0 | Network: Base Sepolia*
