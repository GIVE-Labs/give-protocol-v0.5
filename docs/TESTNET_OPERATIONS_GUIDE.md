# GIVE Protocol v0.5 - Base Sepolia Testnet Operations Guide

**Network:** Base Sepolia (Chain ID: 84532)  
**Deployment Date:** October 24, 2025  
**Status:** ✅ Fully Deployed & Operational

---

## 📋 Quick Reference

### Core Contract Addresses

| Contract | Address | Basescan |
|----------|---------|----------|
| **ACLManager** | `0xC6454Ec62f53823692f426F1fb4Daa57c184A36A` | [View](https://sepolia.basescan.org/address/0xC6454Ec62f53823692f426F1fb4Daa57c184A36A) |
| **GiveProtocolCore** | `0xB73B90207D6Fe0e44A090002bf4e2e9aA37564D9` | [View](https://sepolia.basescan.org/address/0xB73B90207D6Fe0e44A090002bf4e2e9aA37564D9) |
| **CampaignRegistry** | `0x51929ec1C089463fBeF6148B86F34117D9CCF816` | [View](https://sepolia.basescan.org/address/0x51929ec1C089463fBeF6148B86F34117D9CCF816) |
| **StrategyRegistry** | `0xA31D2D9dc6E58568B65AA3643B1076C6a48De6FC` | [View](https://sepolia.basescan.org/address/0xA31D2D9dc6E58568B65AA3643B1076C6a48De6FC) |
| **PayoutRouter** | `0xe1BD0BA2e0891c95Bd02eA248f8115E7c7DC37c5` | [View](https://sepolia.basescan.org/address/0xe1BD0BA2e0891c95Bd02eA248f8115E7c7DC37c5) |
| **CampaignVaultFactory** | `0x2ff82c02775550e038787E4403687e1Fe24E2B44` | [View](https://sepolia.basescan.org/address/0x2ff82c02775550e038787E4403687e1Fe24E2B44) |
| **GIVE WETH Vault** | `0x28ac6D6505E2875FFF9E13d1B788A8d4740a7278` | [View](https://sepolia.basescan.org/address/0x28ac6D6505E2875FFF9E13d1B788A8d4740a7278) |
| **MockYieldAdapter** | `0x31fAf52536FC9c4DaA224fb8AB76868DE4731A0E` | [View](https://sepolia.basescan.org/address/0x31fAf52536FC9c4DaA224fb8AB76868DE4731A0E) |

### External Contracts

| Contract | Address | Notes |
|----------|---------|-------|
| **WETH** | `0x4200000000000000000000000000000000000006` | Base Sepolia native WETH |
| **Aave V3 Pool** | `0x8bAB6d1b75f19e9eD9fCe8b9BD338844fF79aE27` | For future AaveAdapter |

---

## 🚀 Getting Started

### Prerequisites

1. **MetaMask or Compatible Wallet**
   - Add Base Sepolia network: https://chainlist.org/chain/84532
   - RPC: https://sepolia.base.org
   - Chain ID: 84532
   - Currency: ETH

2. **Get Base Sepolia ETH**
   - **Coinbase Faucet**: https://www.coinbase.com/faucets/base-ethereum-sepolia-faucet
   - **Alchemy Faucet**: https://www.alchemy.com/faucets/base-sepolia
   - Required: ~0.2 ETH for testing (gas is very cheap!)

3. **Development Tools** (optional)
   ```bash
   # Install Foundry
   curl -L https://foundry.paradigm.xyz | bash
   foundryup
   
   # Or use cast-cli from npm
   npm install -g @foundry-rs/cast
   ```

---

## 💰 Basic Operations

### 1. Wrap ETH to WETH

**Via Cast:**
```bash
cast send 0x4200000000000000000000000000000000000006 \
  "deposit()" \
  --value 0.1ether \
  --rpc-url https://sepolia.base.org \
  --private-key $PRIVATE_KEY
```

**Via Contract Interaction:**
1. Go to [WETH Contract](https://sepolia.basescan.org/address/0x4200000000000000000000000000000000000006#writeContract)
2. Connect wallet
3. Call `deposit()` with value (e.g., 0.1 ETH)

**Check WETH Balance:**
```bash
cast call 0x4200000000000000000000000000000000000006 \
  "balanceOf(address)(uint256)" \
  YOUR_ADDRESS \
  --rpc-url https://sepolia.base.org
```

---

### 2. Deposit to GIVE Vault

**Step 1: Approve Vault**
```bash
cast send 0x4200000000000000000000000000000000000006 \
  "approve(address,uint256)" \
  0x28ac6D6505E2875FFF9E13d1B788A8d4740a7278 \
  100000000000000000 \
  --rpc-url https://sepolia.base.org \
  --private-key $PRIVATE_KEY
```

**Step 2: Deposit WETH**
```bash
cast send 0x28ac6D6505E2875FFF9E13d1B788A8d4740a7278 \
  "deposit(uint256,address)" \
  100000000000000000 \
  YOUR_ADDRESS \
  --rpc-url https://sepolia.base.org \
  --private-key $PRIVATE_KEY \
  --gas-limit 500000
```

**What Happens:**
- You receive vault shares (1:1 on first deposit)
- 99% of your deposit goes to the yield adapter
- 1% stays in vault as cash buffer
- Example: Deposit 0.1 WETH → Get 0.1 shares, adapter gets 0.099 WETH, vault keeps 0.001 WETH

**Check Your Shares:**
```bash
cast call 0x28ac6D6505E2875FFF9E13d1B788A8d4740a7278 \
  "balanceOf(address)(uint256)" \
  YOUR_ADDRESS \
  --rpc-url https://sepolia.base.org
```

---

### 3. Withdraw from Vault

**Withdraw Specific Amount:**
```bash
cast send 0x28ac6D6505E2875FFF9E13d1B788A8d4740a7278 \
  "withdraw(uint256,address,address)" \
  50000000000000000 \
  YOUR_ADDRESS \
  YOUR_ADDRESS \
  --rpc-url https://sepolia.base.org \
  --private-key $PRIVATE_KEY \
  --gas-limit 500000
```

**Redeem All Shares:**
```bash
# First get your share balance
SHARES=$(cast call 0x28ac6D6505E2875FFF9E13d1B788A8d4740a7278 \
  "balanceOf(address)(uint256)" YOUR_ADDRESS \
  --rpc-url https://sepolia.base.org)

# Then redeem
cast send 0x28ac6D6505E2875FFF9E13d1B788A8d4740a7278 \
  "redeem(uint256,address,address)" \
  $SHARES \
  YOUR_ADDRESS \
  YOUR_ADDRESS \
  --rpc-url https://sepolia.base.org \
  --private-key $PRIVATE_KEY \
  --gas-limit 500000
```

---

### 4. Harvest Yield

**Check Harvestable Yield:**
```bash
# Call harvest to simulate (no transaction)
cast call 0x28ac6D6505E2875FFF9E13d1B788A8d4740a7278 \
  "harvest()" \
  --rpc-url https://sepolia.base.org
```

Returns: `(uint256 profit, uint256 loss)`

**Execute Harvest:**
```bash
cast send 0x28ac6D6505E2875FFF9E13d1B788A8d4740a7278 \
  "harvest()" \
  --rpc-url https://sepolia.base.org \
  --private-key $PRIVATE_KEY \
  --gas-limit 800000
```

**What Happens:**
- Adapter returns generated yield to vault
- Vault sends yield to PayoutRouter
- PayoutRouter distributes based on user preferences
- Events emitted: `Harvested(profit, loss, distributed)`

---

### 5. Set Payout Preferences

**Configure Where Your Yield Goes:**
```bash
# Set single beneficiary (100%)
cast send 0xe1BD0BA2e0891c95Bd02eA248f8115E7c7DC37c5 \
  "setBeneficiary(bytes32,address)" \
  VAULT_ID \
  BENEFICIARY_ADDRESS \
  --rpc-url https://sepolia.base.org \
  --private-key $PRIVATE_KEY
```

**Vault ID for WETH Vault:**
```
0xc186b294154d0e32dbe3a73135e1514019bb5394bda7ae20ba930f0a8ed00159
```

**Multiple Beneficiaries (Split):**
```bash
# Coming soon - PayoutRouter v2 will support % splits
```

---

## 🏛️ Campaign Operations

### 1. Register as Campaign Creator

**Requires:** `CAMPAIGN_CREATOR_ROLE` from ACLManager

**Request Role** (for testing, contact deployer):
```
Deployer Address: 0xe45d65267F0DDA5e6163ED6D476F72049972ce3b
```

### 2. Submit Campaign Proposal

```bash
cast send 0x51929ec1C089463fBeF6148B86F34117D9CCF816 \
  "submitCampaign(bytes32,string,string,address,uint256,uint256,uint256)" \
  CAMPAIGN_ID \
  "Campaign Name" \
  "ipfs://QmHash..." \
  RECIPIENT_ADDRESS \
  1000000000000000000 \
  DURATION_SECONDS \
  0 \
  --rpc-url https://sepolia.base.org \
  --private-key $PRIVATE_KEY
```

**Parameters:**
- `campaignId`: Unique bytes32 identifier
- `name`: Human-readable name
- `metadataUri`: IPFS or HTTP link to JSON metadata
- `recipient`: Address that receives campaign payouts
- `goal`: Fundraising goal in wei
- `duration`: Campaign duration in seconds
- `lockProfile`: Lock profile ID (0 for none)

### 3. Approve Campaign (Curator Role)

**Requires:** `CAMPAIGN_CURATOR_ROLE`

```bash
cast send 0x51929ec1C089463fBeF6148B86F34117D9CCF816 \
  "approveCampaign(bytes32)" \
  CAMPAIGN_ID \
  --rpc-url https://sepolia.base.org \
  --private-key $PRIVATE_KEY
```

### 4. Create Campaign Vault

**After campaign approval, create dedicated vault:**

```bash
cast send 0x2ff82c02775550e038787E4403687e1Fe24E2B44 \
  "deployCampaignVault(bytes32,address,string,string)" \
  CAMPAIGN_ID \
  0x4200000000000000000000000000000000000006 \
  "Campaign WETH Vault" \
  "cgvWETH" \
  --rpc-url https://sepolia.base.org \
  --private-key $PRIVATE_KEY \
  --gas-limit 1000000
```

**What You Get:**
- Dedicated EIP-1167 minimal proxy vault (~45 bytes!)
- Immutable campaign metadata
- Isolated accounting per campaign
- Lock profile enforcement

---

## 🎯 Advanced Operations

### Check Vault Status

**Total Assets:**
```bash
cast call 0x28ac6D6505E2875FFF9E13d1B788A8d4740a7278 \
  "totalAssets()(uint256)" \
  --rpc-url https://sepolia.base.org
```

**Total Supply:**
```bash
cast call 0x28ac6D6505E2875FFF9E13d1B788A8d4740a7278 \
  "totalSupply()(uint256)" \
  --rpc-url https://sepolia.base.org
```

**Share Price (assets per share):**
```bash
cast call 0x28ac6D6505E2875FFF9E13d1B788A8d4740a7278 \
  "convertToAssets(uint256)(uint256)" \
  1000000000000000000 \
  --rpc-url https://sepolia.base.org
```

### Check Campaign Status

**Get Campaign Details:**
```bash
cast call 0x51929ec1C089463fBeF6148B86F34117D9CCF816 \
  "getCampaign(bytes32)" \
  CAMPAIGN_ID \
  --rpc-url https://sepolia.base.org
```

**Check Campaign State:**
```bash
cast call 0x51929ec1C089463fBeF6148B86F34117D9CCF816 \
  "getCampaignState(bytes32)" \
  CAMPAIGN_ID \
  --rpc-url https://sepolia.base.org
```

States:
- `0`: NonExistent
- `1`: Submitted
- `2`: Approved
- `3`: Active
- `4`: Paused
- `5`: Completed

### Emergency Operations

**Emergency Withdraw (Admin Only):**
```bash
cast send 0x28ac6D6505E2875FFF9E13d1B788A8d4740a7278 \
  "emergencyWithdrawFromAdapter()" \
  --rpc-url https://sepolia.base.org \
  --private-key $PRIVATE_KEY
```

**Pause Vault (Admin Only):**
```bash
cast send 0x28ac6D6505E2875FFF9E13d1B788A8d4740a7278 \
  "pauseVault()" \
  --rpc-url https://sepolia.base.org \
  --private-key $PRIVATE_KEY
```

---

## 🧪 Testing & Debugging

### Test Yield Generation

**1. Add Simulated Yield:**
```bash
# Wrap extra WETH
cast send 0x4200000000000000000000000000000000000006 \
  "deposit()" --value 0.01ether \
  --rpc-url https://sepolia.base.org \
  --private-key $PRIVATE_KEY

# Send to adapter to simulate yield
cast send 0x4200000000000000000000000000000000000006 \
  "transfer(address,uint256)" \
  0x31fAf52536FC9c4DaA224fb8AB76868DE4731A0E \
  10000000000000000 \
  --rpc-url https://sepolia.base.org \
  --private-key $PRIVATE_KEY
```

**2. Harvest:**
```bash
cast send 0x28ac6D6505E2875FFF9E13d1B788A8d4740a7278 \
  "harvest()" \
  --rpc-url https://sepolia.base.org \
  --private-key $PRIVATE_KEY \
  --gas-limit 800000
```

### Monitor Events

**Watch Deposits:**
```bash
cast logs \
  --address 0x28ac6D6505E2875FFF9E13d1B788A8d4740a7278 \
  --topic0 0xdcbc1c05240f31ff3ad067ef1ee35ce4997762752e3a095284754544f4c709d7 \
  --from-block latest \
  --rpc-url https://sepolia.base.org
```

**Watch Harvests:**
```bash
cast logs \
  --address 0x28ac6D6505E2875FFF9E13d1B788A8d4740a7278 \
  --topic0 $(cast keccak "Harvest(uint256,uint256,uint256)") \
  --from-block latest \
  --rpc-url https://sepolia.base.org
```

### Common Issues & Solutions

#### "Insufficient allowance"
```bash
# Check current allowance
cast call 0x4200000000000000000000000000000000000006 \
  "allowance(address,address)(uint256)" \
  YOUR_ADDRESS \
  0x28ac6D6505E2875FFF9E13d1B788A8d4740a7278 \
  --rpc-url https://sepolia.base.org

# Approve if needed
cast send 0x4200000000000000000000000000000000000006 \
  "approve(address,uint256)" \
  0x28ac6D6505E2875FFF9E13d1B788A8d4740a7278 \
  115792089237316195423570985008687907853269984665640564039457584007913129639935 \
  --rpc-url https://sepolia.base.org \
  --private-key $PRIVATE_KEY
```

#### "HarvestPaused"
```bash
# Check pause status
cast call 0x28ac6D6505E2875FFF9E13d1B788A8d4740a7278 \
  "harvestPaused()(bool)" \
  --rpc-url https://sepolia.base.org

# Unpause (admin only)
cast send 0x28ac6D6505E2875FFF9E13d1B788A8d4740a7278 \
  "resumeHarvest()" \
  --rpc-url https://sepolia.base.org \
  --private-key $PRIVATE_KEY
```

#### "Out of gas"
Add `--gas-limit 800000` to complex operations like harvest

#### "Transaction reverted"
Use `cast call` (simulation) first to see revert reason:
```bash
cast call 0x28ac6D6505E2875FFF9E13d1B788A8d4740a7278 \
  "deposit(uint256,address)" \
  100000000000000000 \
  YOUR_ADDRESS \
  --rpc-url https://sepolia.base.org
```

---

## 🔧 Frontend Integration

### Update Contract Addresses

**File:** `apps/web/src/config/addresses.ts`

```typescript
export const CONTRACTS = {
  [base]: {
    // Add Base Mainnet addresses later
  },
  [baseSepolia]: {
    aclManager: '0xC6454Ec62f53823692f426F1fb4Daa57c184A36A',
    giveProtocolCore: '0xB73B90207D6Fe0e44A090002bf4e2e9aA37564D9',
    campaignRegistry: '0x51929ec1C089463fBeF6148B86F34117D9CCF816',
    strategyRegistry: '0xA31D2D9dc6E58568B65AA3643B1076C6a48De6FC',
    payoutRouter: '0xe1BD0BA2e0891c95Bd02eA248f8115E7c7DC37c5',
    campaignVaultFactory: '0x2ff82c02775550e038787E4403687e1Fe24E2B44',
    giveWethVault: '0x28ac6D6505E2875FFF9E13d1B788A8d4740a7278',
    mockYieldAdapter: '0x31fAf52536FC9c4DaA224fb8AB76868DE4731A0E',
    weth: '0x4200000000000000000000000000000000000006',
  },
}
```

### Sync ABIs

```bash
cd /home/give-protocol-v0
pnpm sync-abis
```

### Test Frontend

```bash
cd apps/web
pnpm dev
```

Visit: http://localhost:3000

---

## 📊 Gas Costs Reference

| Operation | Gas Used | Cost @ 1 gwei | Notes |
|-----------|----------|---------------|-------|
| Wrap ETH → WETH | ~44,000 | 0.000044 ETH | Standard ERC20 deposit |
| Approve WETH | ~46,000 | 0.000046 ETH | First-time approval |
| Deposit to Vault | ~320,000 | 0.00032 ETH | Includes adapter investment |
| Withdraw from Vault | ~138,000 | 0.000138 ETH | Includes adapter divest |
| Harvest | ~490,000 | 0.00049 ETH | Includes distribution |
| Create Campaign Vault | ~800,000 | 0.0008 ETH | One-time EIP-1167 clone |

**Note:** Base Sepolia gas prices are typically 0.001 gwei (very cheap!), so actual costs are 1000x less than shown above.

---

## 🎓 Architecture Notes

### EIP-4626 Tokenized Vaults

All GIVE vaults implement the [EIP-4626](https://eips.ethereum.org/EIPS/eip-4626) standard:

- **Shares**: Represent proportional ownership of vault assets
- **1:1 Initial Ratio**: First depositor gets 1 share per 1 asset
- **Dynamic Ratio**: As yield accrues, 1 share = more assets
- **Standard Interface**: Compatible with all EIP-4626 tooling

### EIP-1167 Minimal Proxies

Campaign vaults use [EIP-1167](https://eips.ethereum.org/EIPS/eip-1167) clones:

- **Size**: ~45 bytes per clone vs ~19KB for full contract
- **Deployment Cost**: ~50k gas vs ~4M gas
- **Implementation**: Shared at `0x9db2a61a2Ea9Eb4bb52AE9c5135BB7264bD29615`
- **Deterministic**: CREATE2 salts for predictable addresses

### Yield Flow

```
1. User deposits → Vault mints shares
2. Vault invests 99% → Adapter deploys to yield protocol
3. Vault keeps 1% → Cash buffer for instant withdrawals
4. Yield accrues → Adapter balance grows
5. Harvest called → Adapter returns profit to vault
6. Vault sends profit → PayoutRouter distributes
7. PayoutRouter → Campaign recipients + user beneficiaries
```

### Security Features

- **UUPS Upgradeability**: Only `ROLE_UPGRADER` can upgrade
- **Role-Based Access**: ACLManager controls all permissions
- **Pause Mechanisms**: Admin can pause deposits/withdrawals/harvests
- **Reentrancy Guards**: All state-changing functions protected
- **Emergency Shutdown**: Grace period for recovery

---

## 📚 Additional Resources

- **Codebase**: https://github.com/GIVE-Labs/give-protocol-v0
- **Deployment Summary**: `/DEPLOYMENT_BASE_SEPOLIA.md`
- **Architecture Overview**: `/.github/copilot-instructions.md`
- **Phase Plan**: `/OVERHAUL_PLAN.md`
- **Base Sepolia Faucet**: https://www.coinbase.com/faucets/base-ethereum-sepolia-faucet
- **Base Sepolia Explorer**: https://sepolia.basescan.org
- **EIP-4626 Spec**: https://eips.ethereum.org/EIPS/eip-4626
- **EIP-1167 Spec**: https://eips.ethereum.org/EIPS/eip-1167

---

## 🆘 Support

For technical issues or questions:

1. Check the **troubleshooting section** above
2. Review **contract verification** on Basescan for ABI
3. Check **recent transactions** for similar operations
4. Open an issue on GitHub with transaction hash and error

---

## ✅ Testing Checklist

Use this checklist to verify your testnet setup:

- [ ] Got Base Sepolia ETH from faucet
- [ ] Wrapped ETH to WETH successfully
- [ ] Approved vault to spend WETH
- [ ] Deposited WETH to vault (received shares)
- [ ] Checked vault share balance
- [ ] Withdrew partial amount (burned shares)
- [ ] Simulated yield generation
- [ ] Called harvest (check via `cast call` first)
- [ ] Set payout preference
- [ ] Viewed transaction on Basescan

**Status**: All operations tested and working! ✅

---

*Last Updated: October 24, 2025*  
*Deployment: Base Sepolia Testnet*  
*Version: GIVE Protocol v0.5*
