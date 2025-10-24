# GIVE Protocol v0.5 - Deployment & Operations

**Network:** Base Sepolia (Chain ID: 84532)  
**Deployed:** October 24, 2025  
**Status:** ✅ Fully Deployed & Verified

---

## 📊 Deployment Summary

**Gas Used:** 41,526,167  
**Total Cost:** 0.0000415 ETH (~$0.00 at testnet prices)  
**Deployer:** `0xe45d65267F0DDA5e6163ED6D476F72049972ce3b`  
**Tests Passing:** 116/116 ✅  
**Contracts Verified:** 9/9 on Basescan ✅

---

## 📝 Contract Addresses

### Core Protocol (UUPS Proxies)

| Contract | Proxy Address | Implementation | Verified |
|----------|---------------|----------------|----------|
| **ACLManager** | `0xC6454Ec62f53823692f426F1fb4Daa57c184A36A` | `0xbfCC744Ae49D487aC7b949d9388D254C53d403ca` | ✅ |
| **GiveProtocolCore** | `0xB73B90207D6Fe0e44A090002bf4e2e9aA37564D9` | `0x67aE0bcD1AfAb2f590B91c5fE8fa0102E689862a` | ✅ |
| **StrategyRegistry** | `0xA31D2D9dc6E58568B65AA3643B1076C6a48De6FC` | `0x9198CE9eEBD2Ce6B84D051AC44065a3D23d3bcB3` | ✅ |
| **CampaignRegistry** | `0x51929ec1C089463fBeF6148B86F34117D9CCF816` | `0x67D62667899e1E5bD57A595390519D120485E64f` | ✅ |
| **PayoutRouter** | `0xe1BD0BA2e0891c95Bd02eA248f8115E7c7DC37c5` | `0xAA0b91B69eF950905EFFcE42a33652837dA1Ae18` | ✅ |
| **CampaignVaultFactory** | `0x2ff82c02775550e038787E4403687e1Fe24E2B44` | `0x2D49bf849B71a5e2Baa3F0336FC0f2c8FEB216c7` | ✅ |

### Vaults & Adapters

| Contract | Address | Type | Verified |
|----------|---------|------|----------|
| **CampaignVault4626 (impl)** | `0x9db2a61a2Ea9Eb4bb52AE9c5135BB7264bD29615` | Implementation for clones | ✅ |
| **GIVE WETH Vault** | `0x28ac6D6505E2875FFF9E13d1B788A8d4740a7278` | ERC-4626 Vault | ✅ |
| **Campaign Vault (clone)** | `0x7b60Ad047D204F543a10Ab8789075A0F8ad5AA59` | EIP-1167 Minimal Proxy | - |
| **MockYieldAdapter** | `0x31fAf52536FC9c4DaA224fb8AB76868DE4731A0E` | Test Adapter | ✅ |

### External Contracts

| Contract | Address | Notes |
|----------|---------|-------|
| **WETH** | `0x4200000000000000000000000000000000000006` | Base Sepolia native WETH |
| **Aave V3 Pool** | `0x8bAB6d1b75f19e9eD9fCe8b9BD338844fF79aE27` | For future AaveAdapter |

---

## 🏗️ Architecture Highlights

### EIP-1167 Minimal Proxies
- **Factory Size:** 5,168 bytes (was 26,252 - **80% reduction**)
- **Implementation:** Single vault at `0x9db2a61a2Ea9Eb4bb52AE9c5135BB7264bD29615`
- **Each Clone:** ~45 bytes vs ~19KB full contract
- **Gas Savings:** ~50k gas vs ~4M gas per vault deployment

### UUPS Upgradeable Pattern
- All core contracts use UUPS (Universal Upgradeable Proxy Standard)
- Only `ROLE_UPGRADER` can authorize upgrades via ACLManager
- Storage layout preservation via diamond storage pattern

### Verification Status
**Why only implementations show as verified:**
- Proxy addresses are ERC-1967 proxies (~100 bytes)
- They delegate all calls to implementation contracts
- Basescan automatically detects proxies and shows implementation ABI
- Users interact with proxy addresses, code reads from implementation
- **This is the standard and correct verification method for UUPS proxies!**

---

## 💰 Operations Guide

### 1. Wrap ETH to WETH

```bash
# Via cast
cast send 0x4200000000000000000000000000000000000006 \
  "deposit()" --value 0.1ether \
  --rpc-url https://sepolia.base.org \
  --private-key $PRIVATE_KEY
```

### 2. Deposit to Vault

```bash
# Step 1: Approve vault
cast send 0x4200000000000000000000000000000000000006 \
  "approve(address,uint256)" \
  0x28ac6D6505E2875FFF9E13d1B788A8d4740a7278 \
  100000000000000000 \
  --rpc-url https://sepolia.base.org \
  --private-key $PRIVATE_KEY

# Step 2: Deposit WETH
cast send 0x28ac6D6505E2875FFF9E13d1B788A8d4740a7278 \
  "deposit(uint256,address)" \
  100000000000000000 \
  $YOUR_ADDRESS \
  --rpc-url https://sepolia.base.org \
  --private-key $PRIVATE_KEY \
  --gas-limit 500000
```

**What happens:**
- Receive vault shares (1:1 on first deposit)
- 99% goes to yield adapter
- 1% stays as cash buffer
- Example: Deposit 0.1 WETH → Get 0.1 shares, adapter gets 0.099 WETH

### 3. Withdraw from Vault

```bash
cast send 0x28ac6D6505E2875FFF9E13d1B788A8d4740a7278 \
  "withdraw(uint256,address,address)" \
  50000000000000000 \
  $YOUR_ADDRESS \
  $YOUR_ADDRESS \
  --rpc-url https://sepolia.base.org \
  --private-key $PRIVATE_KEY \
  --gas-limit 500000
```

### 4. Harvest Yield

```bash
# Simulate harvest (no transaction)
cast call 0x28ac6D6505E2875FFF9E13d1B788A8d4740a7278 \
  "harvest()" \
  --rpc-url https://sepolia.base.org

# Execute harvest
cast send 0x28ac6D6505E2875FFF9E13d1B788A8d4740a7278 \
  "harvest()" \
  --rpc-url https://sepolia.base.org \
  --private-key $PRIVATE_KEY \
  --gas-limit 800000
```

**Complete operations guide:** See `docs/TESTNET_OPERATIONS_GUIDE.md` for 100+ sections

---

## 📊 Gas Costs Reference

| Operation | Gas Used | Cost @ 1 gwei | Notes |
|-----------|----------|---------------|-------|
| Wrap ETH → WETH | ~44,000 | 0.000044 ETH | Standard ERC20 deposit |
| Approve WETH | ~46,000 | 0.000046 ETH | First-time approval |
| Deposit to Vault | ~320,000 | 0.00032 ETH | Includes adapter investment |
| Withdraw from Vault | ~138,000 | 0.000138 ETH | Includes adapter divest |
| Harvest Yield | ~490,000 | 0.00049 ETH | Includes distribution |
| Create Campaign Vault | ~800,000 | 0.0008 ETH | EIP-1167 clone deployment |

**Note:** Base Sepolia gas prices typically 0.001 gwei (very cheap!)

---

## ✅ Tested Operations

All operations verified on Base Sepolia:

✅ **Wrapped 0.1 ETH → WETH** (44k gas)  
✅ **Approved vault** to spend WETH (46k gas)  
✅ **Deposited 0.1 WETH** → Received 0.1 shares (320k gas)
   - Adapter received 0.099 WETH (99% deployment)
   - Vault kept 0.001 WETH (1% cash buffer)  
✅ **Withdrew 0.05 WETH** → Burned 0.05 shares (138k gas)  
✅ **Simulated yield** → Sent 0.01 WETH to adapter  
✅ **Harvest (simulation)** → Returned (0.01 profit, 0 loss)

---

## 🔧 Frontend Integration

### Contract Addresses Config

**File:** `apps/web/src/config/addresses.ts`

```typescript
export const ADDRESSES: Record<number, ProtocolAddresses> = {
  84532: { // Base Sepolia
    aclManager: '0xC6454Ec62f53823692f426F1fb4Daa57c184A36A',
    giveProtocolCore: '0xB73B90207D6Fe0e44A090002bf4e2e9aA37564D9',
    campaignRegistry: '0x51929ec1C089463fBeF6148B86F34117D9CCF816',
    strategyRegistry: '0xA31D2D9dc6E58568B65AA3643B1076C6a48De6FC',
    payoutRouter: '0xe1BD0BA2e0891c95Bd02eA248f8115E7c7DC37c5',
    campaignVaultFactory: '0x2ff82c02775550e038787E4403687e1Fe24E2B44',
    giveWethVault: '0x28ac6D6505E2875FFF9E13d1B788A8d4740a7278',
    mockYieldAdapter: '0x31fAf52536FC9c4DaA224fb8AB76868DE4731A0E',
    weth: '0x4200000000000000000000000000000000000006',
  }
}
```

### Sync ABIs

```bash
cd /home/give-protocol-v0
pnpm sync-abis
```

### Start Frontend

```bash
cd apps/web
pnpm dev
```

Visit: http://localhost:3000

---

## 🔗 Basescan Links

### Proxies (User-Facing)
- **ACL Manager**: https://sepolia.basescan.org/address/0xC6454Ec62f53823692f426F1fb4Daa57c184A36A
- **Protocol Core**: https://sepolia.basescan.org/address/0xB73B90207D6Fe0e44A090002bf4e2e9aA37564D9
- **Campaign Registry**: https://sepolia.basescan.org/address/0x51929ec1C089463fBeF6148B86F34117D9CCF816
- **Payout Router**: https://sepolia.basescan.org/address/0xe1BD0BA2e0891c95Bd02eA248f8115E7c7DC37c5
- **WETH Vault**: https://sepolia.basescan.org/address/0x28ac6D6505E2875FFF9E13d1B788A8d4740a7278

### Implementations (For Reference)
- **ACL Impl**: https://sepolia.basescan.org/address/0xbfCC744Ae49D487aC7b949d9388D254C53d403ca
- **Core Impl**: https://sepolia.basescan.org/address/0x67aE0bcD1AfAb2f590B91c5fE8fa0102E689862a
- **Factory Impl**: https://sepolia.basescan.org/address/0x2D49bf849B71a5e2Baa3F0336FC0f2c8FEB216c7
- **Vault Impl**: https://sepolia.basescan.org/address/0x9db2a61a2Ea9Eb4bb52AE9c5135BB7264bD29615

---

## 🚨 Issues Resolved During Deployment

1. **Contract Size Limit** ✅
   - **Problem:** CampaignVaultFactory was 26,252 bytes (over 24KB limit)
   - **Solution:** EIP-1167 minimal proxies with CREATE2
   - **Result:** Factory reduced to 5,168 bytes (80% reduction)

2. **Errors Library Conflict** ✅
   - **Problem:** Custom `Errors.sol` conflicted with OpenZeppelin
   - **Solution:** Renamed to `GiveErrors.sol`, updated 158+ files
   - **Result:** Clean compilation

3. **Clone Admin Role Setup** ✅
   - **Problem:** Cloned vaults missing `DEFAULT_ADMIN_ROLE`
   - **Solution:** `initializeCampaign()` grants admin during initialization
   - **Result:** Factory can configure clones properly

4. **Script address(this) Error** ✅
   - **Problem:** Foundry doesn't allow `address(this)` in broadcast scripts
   - **Solution:** Changed to `msg.sender` (deployer wallet)
   - **Result:** Bootstrap script executed successfully

---

## 📚 Additional Documentation

- **`docs/TESTNET_OPERATIONS_GUIDE.md`** - Complete user guide (100+ sections)
- **`docs/ARCHITECTURE.md`** - System design and data flows
- **`docs/EMERGENCY_PROCEDURES.md`** - Incident response procedures
- **`.github/copilot-instructions.md`** - Development context

---

## 🆘 Troubleshooting

### "Insufficient allowance"
```bash
# Check allowance
cast call 0x4200000000000000000000000000000000000006 \
  "allowance(address,address)(uint256)" \
  $YOUR_ADDRESS 0x28ac6D6505E2875FFF9E13d1B788A8d4740a7278 \
  --rpc-url https://sepolia.base.org

# Approve
cast send 0x4200000000000000000000000000000000000006 \
  "approve(address,uint256)" \
  0x28ac6D6505E2875FFF9E13d1B788A8d4740a7278 \
  115792089237316195423570985008687907853269984665640564039457584007913129639935 \
  --rpc-url https://sepolia.base.org --private-key $PRIVATE_KEY
```

### "Out of gas"
Add `--gas-limit 800000` to complex operations

### "Transaction reverted"
Use `cast call` (simulation) first to see revert reason

---

## 📞 Support

- **Base Sepolia Faucet:** https://www.coinbase.com/faucets/base-ethereum-sepolia-faucet
- **Testnet Explorer:** https://sepolia.basescan.org
- **Issues:** Open GitHub issue with transaction hash
- **Operations Guide:** `docs/TESTNET_OPERATIONS_GUIDE.md`

---

*Last Updated: October 24, 2025 | Deployment: Base Sepolia | Version: GIVE Protocol v0.5*
