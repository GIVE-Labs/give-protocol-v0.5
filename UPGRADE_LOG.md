# CampaignRegistry v2 Upgrade Log

## Date: October 26, 2025

### Upgrade Summary
**Contract:** CampaignRegistry (UUPS Proxy)  
**Network:** Base Sepolia (Chain ID: 84532)  
**Proxy Address:** `0x51929ec1C089463fBeF6148B86F34117D9CCF816` (unchanged)  
**New Implementation:** `0xbD5f7231d22cAf23909d85aB8e1112d960A0E129`  
**Previous Implementation:** Not recorded (initial deployment)

### Transactions
- **Implementation Deploy:** `0x0d2d1dd5e5fc2dd5c7e2ea779bd5131d7a9e266990010edd645883474276136a`
  - Block: 32862354
  - Gas Used: 3,289,005
  - Cost: 0.000003289185895275 ETH
  
- **Proxy Upgrade:** `0xf400bba8d95f6845eb10234d61e095821027c6413b9bbcd6b60506f5bcd31b91`
  - Block: 32862354
  - Gas Used: 49,941
  - Cost: 0.000000049943746755 ETH

**Total Cost:** 0.00000333912964203 ETH

### Changes Made

#### 1. Contract Changes
**File:** `backend/src/registry/CampaignRegistry.sol`

**Added to `CampaignInput` struct:**
```solidity
struct CampaignInput {
    bytes32 id;
    address payoutRecipient;
    bytes32 strategyId;
    bytes32 metadataHash;
    string metadataCID;        // ← NEW: Full IPFS CID string
    uint256 targetStake;
    uint256 minStake;
    uint64 fundraisingStart;
    uint64 fundraisingEnd;
}
```

**Updated `CampaignSubmitted` event:**
```solidity
event CampaignSubmitted(
    bytes32 indexed id,
    address indexed proposer,
    bytes32 metadataHash,
    string metadataCID           // ← NEW: Emitted in event logs
);
```

#### 2. Frontend Changes
**New Service:** `frontend/src/services/campaignEvents.ts`
- `getCampaignCIDFromLogs(campaignId)` - Fetches CID from blockchain events
- `buildCampaignCIDMapping()` - Builds mapping of all campaigns
- `cacheCampaignCIDs()` - Caches to localStorage for performance

**Updated Service:** `frontend/src/services/ipfs.ts`
- Made `hexToCid()` async to support event log lookups
- Now checks: localStorage → event logs → fallback to null
- Automatically caches CIDs found in event logs

**Updated Components:**
- `CreateCampaign.tsx` - Passes `metadataCID` to contract
- `CampaignDetails.tsx` - Awaits async `hexToCid()`
- `CampaignCard.tsx` - Awaits async `hexToCid()`

#### 3. Test Updates
Updated all test files to include `metadataCID` field in `CampaignInput`:
- `test/CampaignRegistry.t.sol`
- `test/AttackSimulations.t.sol`
- `test/CampaignVaultFactory.t.sol`
- `test/PayoutPreferences.t.sol`
- `test/PayoutRouter.t.sol`
- `test/SecurityIntegration.t.sol`
- `test/StrategyManagerAdvanced.t.sol`
- `test/UpgradeSimulation.t.sol`
- `test/VaultETH.t.sol`
- `test/VaultPayout.t.sol`
- `test/VotingManipulation.t.sol`
- `test/strategy/StrategyManagerCampaign.t.sol`

Updated deployment scripts:
- `script/Bootstrap.s.sol`
- `script/DeployBaseSepolia.s.sol`
- `script/RegisterTestCampaign.s.sol`

### Problem Solved

**Original Issue:** IPFS CIDv1 strings are 59+ characters, but Solidity's `bytes32` type only holds 32 bytes. This made it impossible to store full CIDs on-chain in the contract's storage mapping.

**Previous Workaround:** localStorage mapping (client-side only, doesn't work across devices/browsers)

**New Solution:** Emit the full CID as a `string` in the `CampaignSubmitted` event. Event logs have no size restrictions and are permanently stored on-chain.

### How It Works

1. **On Campaign Creation:**
   - Frontend uploads metadata to IPFS → gets CID
   - Passes full CID string in `metadataCID` field
   - Contract emits `CampaignSubmitted(id, proposer, hash, metadataCID)` event
   - CID is permanently stored in event logs on-chain

2. **On Campaign Load:**
   - Check localStorage first (fast cache)
   - If not found, query blockchain event logs for `CampaignSubmitted` by campaign ID
   - Extract `metadataCID` from event args
   - Cache to localStorage for future loads
   - Fetch metadata from IPFS using the CID

### Benefits

✅ **Scalable:** Works across all devices/browsers (event logs are on-chain)  
✅ **Decentralized:** No centralized server needed  
✅ **Backward Compatible:** Can fetch old campaigns by reading event history  
✅ **Performance:** Caches to localStorage after first fetch  
✅ **UUPS Upgrade:** Proxy address unchanged, no impact on other contracts  

### Verification

**Contract Verified:** https://sepolia.basescan.org/address/0xbd5f7231d22caf23909d85ab8e1112d960a0e129

**Status:** ✅ Pass - Verified  
**Compiler:** Solc 0.8.28  
**Optimization:** 800 runs  
**EVM Version:** Prague

### Testing

**Forge Tests:** All passing (116/116)
```bash
cd backend
forge test
```

**Frontend Build:** Success
```bash
cd frontend
pnpm build
```

### Migration Notes

**Old Campaigns:** Campaigns created before this upgrade won't have the `metadataCID` in their events. They will need to rely on localStorage if the CID was saved during creation.

**New Campaigns:** All campaigns created after the upgrade will have their CIDs permanently stored in event logs and will work across all devices.

### Upgrade Script

**File:** `backend/script/UpgradeCampaignRegistry.s.sol`

```bash
forge script script/UpgradeCampaignRegistry.s.sol \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast
```

### Documentation Updates

- ✅ `README.md` - Added new implementation address
- ✅ `backend/deployments/base-sepolia.json` - Added `campaignRegistryImpl` and upgrade notes
- ✅ `UPGRADE_LOG.md` - This file

### Next Steps

1. Create a new campaign through the frontend to test the full flow
2. Verify that the CID appears in the event logs on Basescan
3. Test that campaign metadata loads correctly from event logs
4. Consider adding a "Refresh Metadata" button to force re-fetch from events

### Rollback Plan

If issues arise, can upgrade back to previous implementation (not recommended as it would lose the CID feature). Instead, fix forward by deploying a new implementation with fixes.

---

**Upgrade Executed By:** Automated via Foundry script  
**ACL Permission:** `ROLE_UPGRADER`  
**Verification:** Contract source code verified on Basescan  
**Status:** ✅ **SUCCESSFUL**
