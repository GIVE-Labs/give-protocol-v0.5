# GIVE Protocol - Contract Deployment

**Network:** Base Sepolia (Chain ID: 84532)  
**Deployed:** October 24, 2025  
**Status:** ✅ Fully Deployed & Verified

---

## 📊 Deployment Summary

- **Gas Used:** 41,526,167  
- **Total Cost:** 0.0000415 ETH
- **Deployer:** `0xe45d65267F0DDA5e6163ED6D476F72049972ce3b`  
- **Tests:** 116/116 passing ✅  
- **Verified:** 9/9 contracts on Basescan ✅

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
| **MockYieldAdapter** | `0x31fAf52536FC9c4DaA224fb8AB76868DE4731A0E` | Test Adapter | ✅ |

### External Contracts

| Contract | Address | Notes |
|----------|---------|-------|
| **WETH** | `0x4200000000000000000000000000000000000006` | Base Sepolia native WETH |
| **Aave V3 Pool** | `0x8bAB6d1b75f19e9eD9fCe8b9BD338844fF79aE27` | For AaveAdapter |

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
- Proxy addresses are ERC-1967 proxies delegating to implementations
- Basescan automatically detects proxies and shows implementation ABI
- All implementations verified on Basescan ✅

---

## 🔗 Basescan Links

### Core Contracts
- [ACLManager](https://sepolia.basescan.org/address/0xC6454Ec62f53823692f426F1fb4Daa57c184A36A)
- [CampaignRegistry](https://sepolia.basescan.org/address/0x51929ec1C089463fBeF6148B86F34117D9CCF816)
- [PayoutRouter](https://sepolia.basescan.org/address/0xe1BD0BA2e0891c95Bd02eA248f8115E7c7DC37c5)
- [GIVE WETH Vault](https://sepolia.basescan.org/address/0x28ac6D6505E2875FFF9E13d1B788A8d4740a7278)

### Implementations
- [CampaignVault4626](https://sepolia.basescan.org/address/0x9db2a61a2Ea9Eb4bb52AE9c5135BB7264bD29615)
- [MockYieldAdapter](https://sepolia.basescan.org/address/0x31fAf52536FC9c4DaA224fb8AB76868DE4731A0E)

---

## 💰 Quick Operations

### Wrap ETH to WETH
```bash
cast send 0x4200000000000000000000000000000000000006 \
  "deposit()" --value 0.1ether \
  --rpc-url https://sepolia.base.org \
  --private-key $PRIVATE_KEY
```

### Deposit to Vault
```bash
# Approve
cast send 0x4200000000000000000000000000000000000006 \
  "approve(address,uint256)" \
  0x28ac6D6505E2875FFF9E13d1B788A8d4740a7278 \
  100000000000000000 \
  --rpc-url https://sepolia.base.org \
  --private-key $PRIVATE_KEY

# Deposit
cast send 0x28ac6D6505E2875FFF9E13d1B788A8d4740a7278 \
  "deposit(uint256,address)" \
  100000000000000000 \
  $YOUR_ADDRESS \
  --rpc-url https://sepolia.base.org \
  --private-key $PRIVATE_KEY
```

### Check Vault Balance
```bash
cast call 0x28ac6D6505E2875FFF9E13d1B788A8d4740a7278 \
  "balanceOf(address)" $YOUR_ADDRESS \
  --rpc-url https://sepolia.base.org
```

---

## 📚 Additional Resources

- **Frontend Config:** `frontend/src/config/addresses.ts`
- **Deployment Script:** `backend/script/Bootstrap.s.sol`
- **Architecture Docs:** `docs/ARCHITECTURE.md`
- **Operations Guide:** `docs/TESTNET_OPERATIONS_GUIDE.md`

---

*Last Updated: October 27, 2025*
