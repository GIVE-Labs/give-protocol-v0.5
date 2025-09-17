# 🚀 GIVE Protocol - Deployment Address Guide

This guide explains exactly which contract addresses you need to update when deploying to different networks (Anvil local vs Sepolia testnet).

## 📍 Quick Reference

| Environment | Configuration File | Purpose |
|-------------|-------------------|---------|
| **Anvil (Local)** | `/frontend/src/config/local.ts` | Local development addresses |
| **Sepolia (Testnet)** | `/frontend/src/config/contracts.ts` | Testnet deployment addresses |

## 🔧 When to Update Addresses

### Scenario 1: Fresh Local Deployment (Anvil)
**When**: You run `make dev` or `make deploy-local` in the backend

**What to update**: `/frontend/src/config/local.ts`

### Scenario 2: Fresh Sepolia Deployment  
**When**: You run `make deploy-sepolia` in the backend

**What to update**: `/frontend/src/config/contracts.ts` (SEPOLIA section)

## 📋 Step-by-Step Address Update Process

### For Anvil (Local Development)

1. **Deploy contracts locally**:
   ```bash
   cd backend
   make dev  # or make deploy-local
   ```

2. **Copy the deployment output** - Look for lines like:
   ```
   NGO_REGISTRY: 0xc3e53F4d16Ae77Db1c982e75a937B9f60FE63690
   VAULT: 0x5b73C5498c1E3b4dbA84de0F1833c4a029d90519
   STRATEGY_MANAGER: 0xe45d65267F0DDA5e6163ED6D476F72049972ce3b
   AAVE_ADAPTER: 0x28c50Bcdb2288fCdcf84DF4198F06Df92Dad6DFc
   DONATION_ROUTER: 0x84eA74d481Ee0A5332c457a4d796187F6Ba67fEB
   ETH_VAULT: 0x1613beB3B2C4f22Ee086B2b38C1476A3cE7f78E8
   USDC: 0x7a2088a1bfc9d81c55368ae168c2c02570cb814f
   WETH: 0x09635F643e140090A9A8dcd712eD6285858cEbef
   ```

3. **Update `/frontend/src/config/local.ts`**:
   ```typescript
   export const LOCAL_CONTRACT_ADDRESSES = {
     // Protocol contracts - USDC Vault
     VAULT: "0x5b73C5498c1E3b4dbA84de0F1833c4a029d90519", // ← UPDATE THIS
     AAVE_ADAPTER: "0x28c50Bcdb2288fCdcf84DF4198F06Df92Dad6DFc", // ← UPDATE THIS
     STRATEGY_MANAGER: "0xe45d65267F0DDA5e6163ED6D476F72049972ce3b", // ← UPDATE THIS
     
     // ETH Vault contracts
     ETH_VAULT: "0x1613beB3B2C4f22Ee086B2b38C1476A3cE7f78E8", // ← UPDATE THIS
     ETH_VAULT_MANAGER: "0xf5059a5D33d5853360D16C683c16e67980206f36", // ← UPDATE THIS
     ETH_VAULT_ADAPTER: "0x95401dc811bb5740090279Ba06cfA8fcF6113778", // ← UPDATE THIS
     
     // Shared contracts
     NGO_REGISTRY: "0xc3e53F4d16Ae77Db1c982e75a937B9f60FE63690", // ← UPDATE THIS
     DONATION_ROUTER: "0x84eA74d481Ee0A5332c457a4d796187F6Ba67fEB", // ← UPDATE THIS
     
     // Mock tokens for local testing
     ETH: "0xa85233C63b9Ee964Add6F2cffe00Fd84eb32338f", // ← UPDATE THIS
     USDC: "0x7a2088a1bfc9d81c55368ae168c2c02570cb814f", // ← UPDATE THIS
     WETH: "0x09635F643e140090A9A8dcd712eD6285858cEbef", // ← UPDATE THIS
   } as const;
   ```

### For Sepolia (Testnet)

1. **Deploy contracts to Sepolia**:
   ```bash
   cd backend
   # Make sure ETHERSCAN_API_KEY is set in .env
   make deploy-sepolia
   ```

2. **Copy the deployment output** - Look for the contract addresses in the deployment logs

3. **Update `/frontend/src/config/contracts.ts`**:
   ```typescript
   SEPOLIA: {
     chainId: 11155111,
     name: 'Sepolia Testnet',
     contracts: {
       // Deployed contract addresses - UPDATE THESE
       NGO_REGISTRY: '0xeFBC3D84420D848A8b6F5FD614E5740279D834Fa', // ← UPDATE
       VAULT: '0x330EC5985f4a8A03ac148a4fa12d4c45120e73bB', // ← UPDATE
       STRATEGY_MANAGER: '0xDd7800b4871816Ccc4E185A101055Ea47a73b32d', // ← UPDATE
       AAVE_ADAPTER: '0x284Ac57242f5657Cb2E45157D80068639EBac026', // ← UPDATE
       DONATION_ROUTER: '0xcA3826a36f1B82121c18F35d218e7163aFF904a4', // ← UPDATE

       // Token addresses for Sepolia - VERIFY THESE
       TOKENS: {
         ETH: '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2', // Native ETH
         USDC: '0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8', // ← VERIFY/UPDATE
         WETH: '0xC558DBdd856501FCd9aaF1E62eae57A9F0629a3c', // ← VERIFY/UPDATE
       }
     }
   }
   ```

## 🎯 Contract Address Mapping

### Core Protocol Contracts
| Contract | Purpose | Update Priority |
|----------|---------|----------------|
| `NGO_REGISTRY` | Manages verified NGOs | 🔴 **CRITICAL** |
| `VAULT` | Main USDC vault (ERC-4626) | 🔴 **CRITICAL** |
| `STRATEGY_MANAGER` | Manages yield strategies | 🔴 **CRITICAL** |
| `AAVE_ADAPTER` | Aave yield integration | 🔴 **CRITICAL** |
| `DONATION_ROUTER` | Routes donations to NGOs | 🔴 **CRITICAL** |

### ETH Vault Contracts (Optional)
| Contract | Purpose | Update Priority |
|----------|---------|----------------|
| `ETH_VAULT` | ETH-specific vault | 🟡 **OPTIONAL** |
| `ETH_VAULT_MANAGER` | ETH vault management | 🟡 **OPTIONAL** |
| `ETH_VAULT_ADAPTER` | ETH yield adapter | 🟡 **OPTIONAL** |

### Token Contracts
| Contract | Purpose | Update Priority |
|----------|---------|----------------|
| `USDC` | USDC token contract | 🔴 **CRITICAL** |
| `WETH` | Wrapped ETH contract | 🟡 **OPTIONAL** |
| `ETH` | Native ETH placeholder | 🟢 **INFO ONLY** |

## 🔍 How to Find Contract Addresses

### From Deployment Logs
After running deployment commands, look for output like:
```bash
=== Deployment Summary ===
Deployer: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
NGO Registry: 0xc3e53F4d16Ae77Db1c982e75a937B9f60FE63690
Vault: 0x5b73C5498c1E3b4dbA84de0F1833c4a029d90519
Strategy Manager: 0xe45d65267F0DDA5e6163ED6D476F72049972ce3b
```

### From Etherscan (Sepolia)
1. Go to [sepolia.etherscan.io](https://sepolia.etherscan.io)
2. Search for your deployer address
3. Look at recent contract creation transactions
4. Copy the contract addresses from the "To" field

### From Foundry Broadcast Files
Check `/backend/broadcast/` directory for deployment artifacts:
```bash
ls backend/broadcast/Deploy.s.sol/11155111/  # Sepolia
ls backend/broadcast/DeployLocal.s.sol/31337/  # Anvil
```

## ⚠️ Important Notes

### Environment Detection
The frontend automatically detects the environment:
- **Development mode** (`npm run dev`): Uses `LOCAL_CONTRACT_ADDRESSES`
- **Production mode** (`npm run build`): Uses `SEPOLIA` addresses

### Address Validation
Always verify addresses are:
- ✅ **Valid checksummed addresses** (0x followed by 40 hex characters)
- ✅ **Deployed contracts** (not EOA addresses)
- ✅ **Correct network** (Anvil = 31337, Sepolia = 11155111)

### Common Mistakes
- ❌ **Wrong network**: Using Sepolia addresses in local config
- ❌ **Old addresses**: Using addresses from previous deployments
- ❌ **Missing addresses**: Forgetting to update all required contracts
- ❌ **Invalid format**: Using non-checksummed or invalid addresses

## 🧪 Testing After Address Updates

### 1. Start Frontend
```bash
cd frontend
pnpm dev
```

### 2. Check Console
Look for any contract interaction errors in browser console

### 3. Test Basic Functions
- Connect wallet
- Check USDC balance
- Try a small deposit/withdrawal

### 4. Verify Contract Calls
Use browser dev tools Network tab to verify contract calls are going to correct addresses

## 🚨 Troubleshooting

### "Contract not deployed" errors
- ✅ Verify addresses are correct
- ✅ Check you're on the right network
- ✅ Confirm contracts were actually deployed

### "Invalid address" errors  
- ✅ Ensure addresses are checksummed
- ✅ Verify 42-character format (0x + 40 hex)

### "Transaction reverted" errors
- ✅ Check contract is properly initialized
- ✅ Verify you have test tokens
- ✅ Confirm network gas settings

## 📞 Quick Help

**Need fresh local deployment?**
```bash
cd backend && make stop-dev && make dev
```

**Need to redeploy to Sepolia?**
```bash
cd backend && make deploy-sepolia
```

**Frontend not connecting?**
1. Check `/frontend/src/config/contracts.ts` addresses
2. Verify network in MetaMask
3. Clear browser cache and restart dev server

---

**💡 Pro Tip**: Keep a backup of working addresses in a separate file before updating, so you can quickly revert if something goes wrong!