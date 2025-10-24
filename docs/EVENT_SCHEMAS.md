# Event Schemas for Indexers

**Version:** 0.5.0  
**Last Updated:** October 24, 2025  
**Purpose:** Canonical event definitions for subgraph/indexer integration

---

## Table of Contents

1. [Overview](#overview)
2. [Campaign Events](#campaign-events)
3. [Vault Events](#vault-events)
4. [Payout Events](#payout-events)
5. [Strategy Events](#strategy-events)
6. [Checkpoint Events](#checkpoint-events)
7. [Emergency Events](#emergency-events)
8. [Governance Events](#governance-events)
9. [Integration Examples](#integration-examples)

---

## Overview

### Event Naming Convention

```
{Action}{Entity}
```

Examples:
- `CampaignApproved`
- `VaultDeployed`
- `CheckpointScheduled`
- `YieldHarvested`

### Indexing Priority

| Priority | Events | Use Case |
|----------|--------|----------|
| **P0 - Critical** | Emergency, Checkpoint, Payout | Real-time alerts, fund safety |
| **P1 - High** | Campaign, Vault, Strategy | User dashboards, analytics |
| **P2 - Medium** | Governance, Access Control | Admin tools, auditing |
| **P3 - Low** | Config changes | Historical records |

---

## Campaign Events

### CampaignSubmitted

**Emitted When:** New campaign is submitted for approval

```solidity
event CampaignSubmitted(
    bytes32 indexed campaignId,
    address indexed proposer,
    address payoutRecipient,
    bytes32 indexed strategyId,
    string metadataHash,
    uint256 targetStake,
    uint256 minStake,
    uint256 fundraisingStart,
    uint256 fundraisingEnd,
    uint256 timestamp
);
```

**Indexer Schema:**
```graphql
type Campaign @entity {
  id: ID!                           # campaignId
  proposer: Bytes!                   # proposer address
  payoutRecipient: Bytes!            # recipient address
  strategyId: Bytes!                 # linked strategy
  metadataHash: String!              # IPFS/Arweave hash
  targetStake: BigInt!               # target funding goal
  minStake: BigInt!                  # minimum to activate
  fundraisingStart: BigInt!          # unix timestamp
  fundraisingEnd: BigInt!            # unix timestamp
  status: CampaignStatus!            # enum: Submitted
  submittedAt: BigInt!               # block timestamp
  submittedBlock: BigInt!            # block number
  submittedTx: Bytes!                # transaction hash
}
```

**Example Query:**
```graphql
{
  campaigns(
    where: { status: Submitted }
    orderBy: submittedAt
    orderDirection: desc
  ) {
    id
    proposer
    metadataHash
    targetStake
    fundraisingStart
  }
}
```

### CampaignApproved

**Emitted When:** Campaign is approved by approver role

```solidity
event CampaignApproved(
    bytes32 indexed campaignId,
    address indexed approver,
    address indexed curator,
    uint256 timestamp
);
```

**Indexer Updates:**
```graphql
# Update existing Campaign entity
campaign.status = "Approved"
campaign.curator = event.params.curator
campaign.approvedBy = event.params.approver
campaign.approvedAt = event.block.timestamp
campaign.approvedBlock = event.block.number
```

### CampaignActivated

**Emitted When:** Campaign reaches min stake and becomes active

```solidity
event CampaignActivated(
    bytes32 indexed campaignId,
    address indexed vault,
    uint256 initialStake,
    uint256 timestamp
);
```

**Indexer Updates:**
```graphql
campaign.status = "Active"
campaign.vault = event.params.vault
campaign.activatedAt = event.block.timestamp
campaign.totalStaked = event.params.initialStake
```

### CampaignPaused

**Emitted When:** Campaign is paused (halts payouts)

```solidity
event CampaignPaused(
    bytes32 indexed campaignId,
    address indexed pausedBy,
    string reason,
    uint256 timestamp
);
```

### CampaignResumed

**Emitted When:** Paused campaign is resumed

```solidity
event CampaignResumed(
    bytes32 indexed campaignId,
    address indexed resumedBy,
    uint256 timestamp
);
```

### CampaignCompleted

**Emitted When:** Campaign successfully completes

```solidity
event CampaignCompleted(
    bytes32 indexed campaignId,
    uint256 totalRaised,
    uint256 totalYieldReceived,
    uint256 timestamp
);
```

### CampaignCancelled

**Emitted When:** Campaign is cancelled

```solidity
event CampaignCancelled(
    bytes32 indexed campaignId,
    address indexed cancelledBy,
    string reason,
    uint256 timestamp
);
```

---

## Vault Events

### VaultDeployed

**Emitted When:** Factory deploys new campaign vault

```solidity
event VaultDeployed(
    address indexed vault,
    bytes32 indexed campaignId,
    bytes32 indexed strategyId,
    address asset,
    address deployer,
    uint256 timestamp
);
```

**Indexer Schema:**
```graphql
type Vault @entity {
  id: ID!                           # vault address
  campaign: Campaign!                # linked campaign
  strategy: Strategy!                # linked strategy
  asset: Bytes!                      # underlying asset
  deployer: Bytes!                   # deployer address
  totalDeposits: BigInt!             # cumulative deposits
  totalWithdrawals: BigInt!          # cumulative withdrawals
  totalYield: BigInt!                # cumulative yield harvested
  totalShares: BigInt!               # total shares outstanding
  adapterAddress: Bytes              # current adapter
  emergencyShutdown: Boolean!        # emergency state
  deployedAt: BigInt!                # block timestamp
  deployedBlock: BigInt!             # block number
  
  # Relationships
  deposits: [Deposit!]! @derivedFrom(field: "vault")
  withdrawals: [Withdrawal!]! @derivedFrom(field: "vault")
  harvests: [Harvest!]! @derivedFrom(field: "vault")
}
```

### Deposit (ERC4626 Standard)

**Emitted When:** User deposits assets into vault

```solidity
event Deposit(
    address indexed sender,
    address indexed owner,
    uint256 assets,
    uint256 shares
);
```

**Indexer Schema:**
```graphql
type Deposit @entity {
  id: ID!                           # tx-hash-log-index
  vault: Vault!                      # vault address
  sender: Bytes!                     # msg.sender
  owner: Bytes!                      # share recipient
  assets: BigInt!                    # assets deposited
  shares: BigInt!                    # shares minted
  timestamp: BigInt!                 # block timestamp
  blockNumber: BigInt!               # block number
  transactionHash: Bytes!            # tx hash
}
```

**Aggregate Updates:**
```typescript
// Update vault totals
vault.totalDeposits = vault.totalDeposits.plus(event.params.assets)
vault.totalShares = vault.totalShares.plus(event.params.shares)

// Update user position
let userPosition = UserVaultPosition.load(owner + "-" + vaultAddress)
if (!userPosition) {
  userPosition = new UserVaultPosition(owner + "-" + vaultAddress)
  userPosition.user = owner
  userPosition.vault = vaultAddress
  userPosition.shares = BigInt.fromI32(0)
  userPosition.totalDeposited = BigInt.fromI32(0)
}
userPosition.shares = userPosition.shares.plus(event.params.shares)
userPosition.totalDeposited = userPosition.totalDeposited.plus(event.params.assets)
userPosition.save()
```

### Withdraw (ERC4626 Standard)

**Emitted When:** User withdraws assets from vault

```solidity
event Withdraw(
    address indexed sender,
    address indexed receiver,
    address indexed owner,
    uint256 assets,
    uint256 shares
);
```

### YieldHarvested

**Emitted When:** Vault harvests yield from adapter

```solidity
event YieldHarvested(
    address indexed vault,
    address indexed adapter,
    uint256 yieldAmount,
    uint256 protocolFee,
    uint256 netYield,
    uint256 timestamp
);
```

**Indexer Schema:**
```graphql
type Harvest @entity {
  id: ID!                           # tx-hash-log-index
  vault: Vault!                      # vault address
  adapter: Bytes!                    # adapter address
  yieldAmount: BigInt!               # gross yield
  protocolFee: BigInt!               # fee amount
  netYield: BigInt!                  # yield after fees
  timestamp: BigInt!                 # block timestamp
  blockNumber: BigInt!               # block number
  transactionHash: Bytes!            # tx hash
}
```

**Analytics:**
```typescript
// Calculate APY
let daysSinceLastHarvest = (currentTimestamp - lastHarvestTimestamp) / 86400
let dailyYield = yieldAmount / daysSinceLastHarvest
let annualizedYield = dailyYield * 365
let apy = (annualizedYield / vault.totalAssets) * 100

// Update vault metrics
vault.totalYield = vault.totalYield.plus(netYield)
vault.lastHarvestAt = timestamp
vault.averageAPY = calculateMovingAverage(vault, apy)
```

### AdapterConfigured

**Emitted When:** Vault's yield adapter is configured/changed

```solidity
event AdapterConfigured(
    address indexed vault,
    address indexed oldAdapter,
    address indexed newAdapter,
    uint256 timestamp
);
```

---

## Payout Events

### YieldPreferenceUpdated

**Emitted When:** Supporter sets/updates payout preferences

```solidity
event YieldPreferenceUpdated(
    address indexed supporter,
    address indexed vault,
    bytes32 indexed campaignId,
    address beneficiary,
    uint256 campaignBps,
    uint256 timestamp
);
```

**Indexer Schema:**
```graphql
type YieldPreference @entity {
  id: ID!                           # supporter-vault
  supporter: Bytes!                  # supporter address
  vault: Vault!                      # vault address
  campaign: Campaign!                # target campaign
  beneficiary: Bytes!                # beneficiary address
  campaignBps: Int!                  # campaign allocation (bps)
  beneficiaryBps: Int!               # beneficiary allocation (computed)
  updatedAt: BigInt!                 # last update timestamp
  updatedBlock: BigInt!              # last update block
}
```

**Computed Fields:**
```typescript
preference.beneficiaryBps = 10000 - preference.campaignBps
```

### CampaignPayoutExecuted

**Emitted When:** Yield is distributed to campaign

```solidity
event CampaignPayoutExecuted(
    bytes32 indexed campaignId,
    address indexed vault,
    address indexed recipient,
    uint256 amount,
    uint256 timestamp
);
```

**Indexer Schema:**
```graphql
type CampaignPayout @entity {
  id: ID!                           # tx-hash-log-index
  campaign: Campaign!                # campaign entity
  vault: Vault!                      # source vault
  recipient: Bytes!                  # payout recipient
  amount: BigInt!                    # payout amount
  timestamp: BigInt!                 # block timestamp
  blockNumber: BigInt!               # block number
  transactionHash: Bytes!            # tx hash
}
```

**Aggregate Updates:**
```typescript
// Update campaign totals
campaign.totalYieldReceived = campaign.totalYieldReceived.plus(amount)
campaign.lastPayoutAt = timestamp
campaign.payoutCount = campaign.payoutCount + 1

// Calculate campaign APY (yield / staked TVL)
campaign.effectiveAPY = (campaign.totalYieldReceived / campaign.totalStaked) * (365 / campaignAgeDays) * 100
```

### BeneficiaryPayoutExecuted

**Emitted When:** Yield is distributed to supporter's beneficiary

```solidity
event BeneficiaryPayoutExecuted(
    address indexed supporter,
    address indexed beneficiary,
    address indexed vault,
    uint256 amount,
    uint256 timestamp
);
```

### PayoutHalted

**Emitted When:** Campaign payouts are halted (checkpoint failure)

```solidity
event PayoutHalted(
    bytes32 indexed campaignId,
    string reason,
    uint256 timestamp
);
```

### PayoutResumed

**Emitted When:** Halted payouts are resumed

```solidity
event PayoutResumed(
    bytes32 indexed campaignId,
    uint256 timestamp
);
```

---

## Strategy Events

### StrategyRegistered

**Emitted When:** New strategy is registered

```solidity
event StrategyRegistered(
    bytes32 indexed strategyId,
    string name,
    RiskTier riskTier,
    uint256 maxTVL,
    uint256 timestamp
);
```

**Indexer Schema:**
```graphql
type Strategy @entity {
  id: ID!                           # strategyId
  name: String!                      # strategy name
  riskTier: RiskTier!                # enum: Conservative/Moderate/Aggressive
  maxTVL: BigInt!                    # TVL cap
  currentTVL: BigInt!                # current TVL across all vaults
  status: StrategyStatus!            # enum: Active/FadingOut/Deprecated
  adapters: [Bytes!]!                # whitelisted adapters
  campaigns: [Campaign!]! @derivedFrom(field: "strategy")
  registeredAt: BigInt!              # block timestamp
  registeredBlock: BigInt!           # block number
}

enum RiskTier {
  Conservative
  Moderate
  Aggressive
}

enum StrategyStatus {
  Active
  FadingOut
  Deprecated
}
```

### AdapterBoundToStrategy

**Emitted When:** Adapter is whitelisted for strategy

```solidity
event AdapterBoundToStrategy(
    bytes32 indexed strategyId,
    address indexed adapter,
    uint256 timestamp
);
```

### StrategyDeprecated

**Emitted When:** Strategy is deprecated (no new campaigns)

```solidity
event StrategyDeprecated(
    bytes32 indexed strategyId,
    string reason,
    uint256 timestamp
);
```

---

## Checkpoint Events

### CheckpointScheduled

**Emitted When:** Campaign curator schedules milestone checkpoint

```solidity
event CheckpointScheduled(
    bytes32 indexed campaignId,
    bytes32 indexed checkpointId,
    uint256 voteDeadline,
    uint256 quorum,
    uint256 snapshotBlock,
    uint256 timestamp
);
```

**Indexer Schema:**
```graphql
type Checkpoint @entity {
  id: ID!                           # checkpointId
  campaign: Campaign!                # linked campaign
  voteDeadline: BigInt!              # voting end timestamp
  quorum: BigInt!                    # required voting power (bps)
  snapshotBlock: BigInt!             # voting power snapshot block
  votesFor: BigInt!                  # total votes in favor
  votesAgainst: BigInt!              # total votes against
  totalVotingPower: BigInt!          # total eligible voting power
  status: CheckpointStatus!          # Pending/Passed/Failed
  votes: [CheckpointVote!]! @derivedFrom(field: "checkpoint")
  scheduledAt: BigInt!               # block timestamp
  finalizedAt: BigInt                # finalization timestamp (if finalized)
}

enum CheckpointStatus {
  Pending
  Passed
  Failed
}
```

### CheckpointVoteCast

**Emitted When:** Supporter votes on checkpoint

```solidity
event CheckpointVoteCast(
    bytes32 indexed checkpointId,
    bytes32 indexed campaignId,
    address indexed voter,
    bool support,
    uint256 votingPower,
    uint256 timestamp
);
```

**Indexer Schema:**
```graphql
type CheckpointVote @entity {
  id: ID!                           # checkpointId-voter
  checkpoint: Checkpoint!            # linked checkpoint
  voter: Bytes!                      # voter address
  support: Boolean!                  # true = for, false = against
  votingPower: BigInt!               # snapshot-based power
  timestamp: BigInt!                 # vote timestamp
  blockNumber: BigInt!               # block number
  transactionHash: Bytes!            # tx hash
}
```

**Aggregate Updates:**
```typescript
// Update checkpoint totals
if (event.params.support) {
  checkpoint.votesFor = checkpoint.votesFor.plus(event.params.votingPower)
} else {
  checkpoint.votesAgainst = checkpoint.votesAgainst.plus(event.params.votingPower)
}

// Calculate participation
let totalVotes = checkpoint.votesFor.plus(checkpoint.votesAgainst)
checkpoint.participationRate = (totalVotes / checkpoint.totalVotingPower) * 10000 // bps
```

### CheckpointFinalized

**Emitted When:** Checkpoint voting period ends and result is finalized

```solidity
event CheckpointFinalized(
    bytes32 indexed checkpointId,
    bytes32 indexed campaignId,
    bool passed,
    uint256 votesFor,
    uint256 votesAgainst,
    uint256 timestamp
);
```

**Indexer Updates:**
```typescript
checkpoint.status = event.params.passed ? "Passed" : "Failed"
checkpoint.finalizedAt = event.block.timestamp

if (!event.params.passed) {
  // Update campaign
  campaign.payoutsHalted = true
  campaign.status = "Paused"
}
```

---

## Emergency Events

### EmergencyPaused

**Emitted When:** Emergency shutdown is activated

```solidity
event EmergencyPaused(
    address indexed vault,
    address indexed triggeredBy,
    string reason,
    uint256 gracePeriodEnd,
    uint256 timestamp
);
```

**Indexer Schema:**
```graphql
type EmergencyEvent @entity {
  id: ID!                           # tx-hash-log-index
  vault: Vault!                      # affected vault
  eventType: EmergencyEventType!     # enum: Paused/Shutdown/Withdrawal
  triggeredBy: Bytes!                # triggerer address
  reason: String!                    # human-readable reason
  gracePeriodEnd: BigInt             # grace period expiry (if shutdown)
  timestamp: BigInt!                 # block timestamp
  blockNumber: BigInt!               # block number
  transactionHash: Bytes!            # tx hash
}

enum EmergencyEventType {
  Paused
  Shutdown
  Withdrawal
}
```

**Alert Trigger:**
```typescript
// Send high-priority alert to monitoring system
alert.trigger({
  severity: "CRITICAL",
  title: "Emergency Shutdown Activated",
  vault: event.params.vault,
  reason: event.params.reason,
  gracePeriodEnd: event.params.gracePeriodEnd
})
```

### EmergencyWithdrawal

**Emitted When:** User withdraws during emergency period

```solidity
event EmergencyWithdrawal(
    address indexed vault,
    address indexed user,
    uint256 assets,
    uint256 shares,
    uint256 timestamp
);
```

### EmergencyUnpaused

**Emitted When:** Emergency pause is lifted (Level 1 only)

```solidity
event EmergencyUnpaused(
    address indexed vault,
    address indexed triggeredBy,
    uint256 timestamp
);
```

---

## Governance Events

### RoleGranted

**Emitted When:** ACL role is granted to account

```solidity
event RoleGranted(
    bytes32 indexed roleId,
    address indexed account,
    address indexed grantedBy,
    uint256 timestamp
);
```

**Indexer Schema:**
```graphql
type RoleGrant @entity {
  id: ID!                           # roleId-account
  roleId: Bytes!                     # role identifier
  roleName: String!                  # human-readable role name
  account: Bytes!                    # account with role
  grantedBy: Bytes!                  # granter address
  grantedAt: BigInt!                 # block timestamp
  revokedAt: BigInt                  # revocation timestamp (if revoked)
  active: Boolean!                   # current status
}
```

### RoleRevoked

**Emitted When:** ACL role is revoked from account

```solidity
event RoleRevoked(
    bytes32 indexed roleId,
    address indexed account,
    address indexed revokedBy,
    uint256 timestamp
);
```

### FeeChangeProposed

**Emitted When:** Protocol fee change is proposed (enters timelock)

```solidity
event FeeChangeProposed(
    uint256 oldFeeBps,
    uint256 newFeeBps,
    uint256 effectiveAt,
    address indexed proposedBy,
    uint256 timestamp
);
```

**Indexer Schema:**
```graphql
type FeeChange @entity {
  id: ID!                           # timestamp-nonce
  oldFeeBps: Int!                    # old fee (basis points)
  newFeeBps: Int!                    # new fee (basis points)
  changeAmount: Int!                 # delta (can be negative)
  effectiveAt: BigInt!               # timelock expiry
  proposedBy: Bytes!                 # proposer address
  status: FeeChangeStatus!           # Pending/Applied/Cancelled
  proposedAt: BigInt!                # proposal timestamp
  appliedAt: BigInt                  # application timestamp
}

enum FeeChangeStatus {
  Pending
  Applied
  Cancelled
}
```

### FeeChangeApplied

**Emitted When:** Fee change timelock expires and fee is applied

```solidity
event FeeChangeApplied(
    uint256 oldFeeBps,
    uint256 newFeeBps,
    uint256 timestamp
);
```

### ProtocolUpgraded

**Emitted When:** UUPS proxy is upgraded to new implementation

```solidity
event ProtocolUpgraded(
    address indexed proxy,
    address indexed oldImplementation,
    address indexed newImplementation,
    address upgradedBy,
    uint256 timestamp
);
```

**Indexer Schema:**
```graphql
type Upgrade @entity {
  id: ID!                           # tx-hash
  proxy: Bytes!                      # proxy address
  oldImplementation: Bytes!          # old impl address
  newImplementation: Bytes!          # new impl address
  upgradedBy: Bytes!                 # upgrader address
  timestamp: BigInt!                 # block timestamp
  blockNumber: BigInt!               # block number
  transactionHash: Bytes!            # tx hash
}
```

---

## Integration Examples

### The Graph Subgraph

**subgraph.yaml:**
```yaml
specVersion: 0.0.5
schema:
  file: ./schema.graphql
dataSources:
  - kind: ethereum/contract
    name: CampaignRegistry
    network: mainnet
    source:
      address: "0x..." # CampaignRegistry address
      abi: CampaignRegistry
      startBlock: 12345678
    mapping:
      kind: ethereum/events
      apiVersion: 0.0.7
      language: wasm/assemblyscript
      entities:
        - Campaign
        - Checkpoint
        - CheckpointVote
      abis:
        - name: CampaignRegistry
          file: ./abis/CampaignRegistry.json
      eventHandlers:
        - event: CampaignSubmitted(bytes32,address,address,bytes32,string,uint256,uint256,uint256,uint256,uint256)
          handler: handleCampaignSubmitted
        - event: CampaignApproved(bytes32,address,address,uint256)
          handler: handleCampaignApproved
        - event: CheckpointScheduled(bytes32,bytes32,uint256,uint256,uint256,uint256)
          handler: handleCheckpointScheduled
        - event: CheckpointVoteCast(bytes32,bytes32,address,bool,uint256,uint256)
          handler: handleCheckpointVoteCast
        - event: CheckpointFinalized(bytes32,bytes32,bool,uint256,uint256,uint256)
          handler: handleCheckpointFinalized
      file: ./src/campaign-registry.ts
  
  - kind: ethereum/contract
    name: GiveVault4626
    network: mainnet
    source:
      abi: GiveVault4626
      startBlock: 12345678
    mapping:
      kind: ethereum/events
      apiVersion: 0.0.7
      language: wasm/assemblyscript
      entities:
        - Vault
        - Deposit
        - Withdrawal
        - Harvest
      abis:
        - name: GiveVault4626
          file: ./abis/GiveVault4626.json
      eventHandlers:
        - event: Deposit(indexed address,indexed address,uint256,uint256)
          handler: handleDeposit
        - event: Withdraw(indexed address,indexed address,indexed address,uint256,uint256)
          handler: handleWithdraw
        - event: YieldHarvested(indexed address,indexed address,uint256,uint256,uint256,uint256)
          handler: handleYieldHarvested
      file: ./src/vault.ts
```

**Mapping Example (src/campaign-registry.ts):**
```typescript
import { Campaign } from "../generated/schema"
import { CampaignSubmitted, CampaignApproved } from "../generated/CampaignRegistry/CampaignRegistry"

export function handleCampaignSubmitted(event: CampaignSubmitted): void {
  let campaign = new Campaign(event.params.campaignId.toHex())
  
  campaign.proposer = event.params.proposer
  campaign.payoutRecipient = event.params.payoutRecipient
  campaign.strategyId = event.params.strategyId
  campaign.metadataHash = event.params.metadataHash
  campaign.targetStake = event.params.targetStake
  campaign.minStake = event.params.minStake
  campaign.fundraisingStart = event.params.fundraisingStart
  campaign.fundraisingEnd = event.params.fundraisingEnd
  campaign.status = "Submitted"
  campaign.submittedAt = event.block.timestamp
  campaign.submittedBlock = event.block.number
  campaign.submittedTx = event.transaction.hash
  
  campaign.save()
}

export function handleCampaignApproved(event: CampaignApproved): void {
  let campaign = Campaign.load(event.params.campaignId.toHex())
  if (campaign == null) {
    return // Should never happen
  }
  
  campaign.status = "Approved"
  campaign.curator = event.params.curator
  campaign.approvedBy = event.params.approver
  campaign.approvedAt = event.block.timestamp
  campaign.approvedBlock = event.block.number
  
  campaign.save()
}
```

### Goldsky Integration

**goldsky.json:**
```json
{
  "version": "1",
  "name": "give-protocol-v05",
  "chain": "mainnet",
  "abis": {
    "CampaignRegistry": "./abis/CampaignRegistry.json",
    "GiveVault4626": "./abis/GiveVault4626.json",
    "PayoutRouter": "./abis/PayoutRouter.json"
  },
  "events": [
    {
      "name": "CampaignSubmitted",
      "address": "${CAMPAIGN_REGISTRY_ADDRESS}",
      "topic0": "0x..."
    },
    {
      "name": "CheckpointScheduled",
      "address": "${CAMPAIGN_REGISTRY_ADDRESS}",
      "topic0": "0x..."
    },
    {
      "name": "Deposit",
      "addresses": ["${VAULT_1}", "${VAULT_2}", ...],
      "topic0": "0x..."
    }
  ],
  "webhooks": [
    {
      "url": "https://api.giveprotocol.org/webhooks/goldsky",
      "events": ["EmergencyPaused", "CheckpointFinalized"],
      "secret": "${WEBHOOK_SECRET}"
    }
  ]
}
```

### Alchemy Notify

**Webhook Configuration:**
```typescript
// POST https://dashboard.alchemy.com/api/v1/webhooks
{
  "webhook_type": "ADDRESS_ACTIVITY",
  "addresses": [
    "0x...", // CampaignRegistry
    "0x...", // PayoutRouter
    // ... all vault addresses
  ],
  "webhook_url": "https://api.giveprotocol.org/webhooks/alchemy",
  "network": "ETH_MAINNET",
  "app_id": "your-app-id"
}
```

**Handler Example:**
```typescript
// api/webhooks/alchemy.ts
export async function POST(request: Request) {
  const payload = await request.json()
  
  for (const activity of payload.event.activity) {
    const logs = activity.log
    
    // Decode emergency events
    if (logs.topics[0] === EMERGENCY_PAUSED_TOPIC) {
      const decoded = decodeEventLog({
        abi: VAULT_ABI,
        data: logs.data,
        topics: logs.topics
      })
      
      // Send urgent alert
      await sendPagerDutyAlert({
        severity: "critical",
        summary: "Emergency Shutdown Activated",
        vault: decoded.vault,
        reason: decoded.reason
      })
    }
    
    // Decode checkpoint events
    if (logs.topics[0] === CHECKPOINT_FINALIZED_TOPIC) {
      const decoded = decodeEventLog({
        abi: CAMPAIGN_REGISTRY_ABI,
        data: logs.data,
        topics: logs.topics
      })
      
      if (!decoded.passed) {
        // Alert on failed checkpoint
        await sendDiscordNotification({
          channel: "campaign-alerts",
          message: `⚠️ Checkpoint failed for campaign ${decoded.campaignId}`
        })
      }
    }
  }
  
  return new Response("OK", { status: 200 })
}
```

---

## Testing Events

### Foundry Test Pattern

```solidity
// test/events/CampaignEvents.t.sol
contract CampaignEventsTest is BaseProtocolTest {
    function testCampaignSubmittedEvent() public {
        // Setup
        bytes32 strategyId = createTestStrategy();
        
        // Expect event
        vm.expectEmit(true, true, true, true);
        emit CampaignSubmitted(
            expectedCampaignId,
            proposer,
            recipient,
            strategyId,
            "ipfs://metadata",
            1000e6,
            100e6,
            block.timestamp + 1 days,
            block.timestamp + 30 days,
            block.timestamp
        );
        
        // Execute
        vm.prank(proposer);
        bytes32 campaignId = campaignRegistry.submitCampaign(
            proposer,
            recipient,
            strategyId,
            "ipfs://metadata",
            1000e6,
            100e6,
            block.timestamp + 1 days,
            block.timestamp + 30 days
        );
        
        // Assert
        assertEq(campaignId, expectedCampaignId);
    }
}
```

---

## Event Topics Reference

**Calculate Topic0 (event signature hash):**
```bash
cast keccak "CampaignSubmitted(bytes32,address,address,bytes32,string,uint256,uint256,uint256,uint256,uint256)"
# Output: 0x...
```

**Common Topics:**
```
CampaignSubmitted:      0x...
CampaignApproved:       0x...
CheckpointScheduled:    0x...
CheckpointVoteCast:     0x...
Deposit (ERC4626):      0xdcbc1c05240f31ff3ad067ef1ee35ce4997762752e3a095284754544f4c709d7
Withdraw (ERC4626):     0xfbde797d201c681b91056529119e0b02407c7bb96a4a2c75c01fc9667232c8db
EmergencyPaused:        0x...
```

---

**Document Owner:** Backend Team  
**Maintained By:** Indexer Working Group  
**Last Updated:** October 24, 2025  
**Version:** 0.5.0

**For Indexer Support:**  
📧 indexers@giveprotocol.org  
💬 Discord #indexer-support  
📚 Subgraph Repo: github.com/GIVE-Labs/give-subgraph
