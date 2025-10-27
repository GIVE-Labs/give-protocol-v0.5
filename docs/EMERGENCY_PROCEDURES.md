# Emergency Procedures Runbook

**Version:** 0.5.0  
**Last Updated:** October 24, 2025  
**Status:** Active

---

## Table of Contents

1. [Emergency Overview](#emergency-overview)
2. [Incident Classification](#incident-classification)
3. [Response Team](#response-team)
4. [Emergency Contacts](#emergency-contacts)
5. [Level 1: Pause Procedures](#level-1-pause-procedures)
6. [Level 2: Emergency Shutdown](#level-2-emergency-shutdown)
7. [Level 3: Emergency Withdrawal](#level-3-emergency-withdrawal)
8. [Post-Incident Procedures](#post-incident-procedures)
9. [Communication Templates](#communication-templates)
10. [Recovery Procedures](#recovery-procedures)

---

## Emergency Overview

GIVE Protocol implements a **three-level emergency system** designed to protect user funds while minimizing disruption:

| Level | Reversible? | Auto-Divest? | Grace Period | Trigger |
|-------|-------------|--------------|--------------|---------|
| **1: Pause** | ✅ Yes | ❌ No | N/A | `ROLE_PAUSER` |
| **2: Emergency Shutdown** | ❌ No | ✅ Yes | 24 hours | `ROLE_EMERGENCY` |
| **3: Emergency Withdrawal** | N/A | Already divested | After 24hr | Any user |

**Key Principles:**
1. **User Funds First** - Principal protection is paramount
2. **Graduated Response** - Match severity to response level
3. **Transparency** - Communicate early and often
4. **Determinism** - Follow documented procedures

---

## Incident Classification

### Severity Matrix

| Severity | TVL at Risk | User Impact | Response Time | Example |
|----------|-------------|-------------|---------------|---------|
| **P0 - Critical** | >$1M or >50% | Complete loss risk | <15 minutes | Adapter exploit, reentrancy |
| **P1 - High** | $100K-$1M | Partial loss risk | <1 hour | Fee calculation bug |
| **P2 - Medium** | <$100K | Delayed access | <4 hours | Upgrade issue, UI bug |
| **P3 - Low** | None | Minor inconvenience | <24 hours | Documentation error |

### Incident Types

#### Protocol-Level Emergencies
- Smart contract vulnerability (reentrancy, overflow, etc.)
- Access control breach (unauthorized role grant)
- Oracle manipulation
- Flash loan attack
- Upgrade failure
- Storage corruption

#### Adapter-Level Emergencies
- External protocol exploit (Aave, Compound, etc.)
- Price oracle failure
- Liquidity crisis in yield source
- Adapter funds stuck
- Harvest revert loop

#### Campaign-Level Emergencies
- Checkpoint vote manipulation
- Curator malicious behavior
- Payout destination compromise
- Stake theft attempt

#### Infrastructure Emergencies
- RPC node failure
- Monitoring system down
- Multisig key compromise
- Frontend attack (phishing, DNS hijack)

---

## Response Team

### Roles & Responsibilities

#### Incident Commander (IC)
**Who:** On-call engineer (rotating weekly)  
**Responsibilities:**
- Declare incident severity
- Coordinate response team
- Make final decisions on emergency actions
- Communicate with stakeholders

**On-Call Schedule:** See internal Pagerduty

#### Security Lead
**Who:** Head of Security  
**Responsibilities:**
- Investigate root cause
- Assess exploit potential
- Recommend mitigation strategy
- Coordinate with auditors if needed

#### Operations Lead
**Who:** Protocol Engineer  
**Responsibilities:**
- Execute emergency transactions
- Monitor contract state
- Coordinate multisig signers
- Track user withdrawals

#### Communications Lead
**Who:** Community Manager  
**Responsibilities:**
- Draft user communications
- Update status page
- Manage Discord/Twitter announcements
- Coordinate press response (if needed)

---

## Emergency Contacts

### Internal Team

| Role | Primary | Backup | Phone | Signal |
|------|---------|--------|-------|--------|
| **Incident Commander** | @alice | @bob | +1-555-0100 | @alice_signal |
| **Security Lead** | @charlie | @david | +1-555-0101 | @charlie_signal |
| **Operations Lead** | @eve | @frank | +1-555-0102 | @eve_signal |
| **Communications** | @grace | @heidi | +1-555-0103 | @grace_signal |
| **CEO** | @ivan | - | +1-555-0104 | @ivan_signal |

### External Contacts

| Entity | Contact | Purpose |
|--------|---------|---------|
| **Multisig Signers** | See internal doc | Emergency transaction approval |
| **Auditor (On-Call)** | auditor@example.com | Emergency code review |
| **Infrastructure Provider** | support@alchemy.com | RPC issues |
| **Legal Counsel** | legal@firm.com | Regulatory/legal issues |

### Communication Channels

- **War Room:** Discord #incident-response (private)
- **Status Page:** status.giveprotocol.org
- **Public Announcements:** Twitter @GiveProtocol, Discord #announcements
- **User Support:** support@giveprotocol.org

---

## Level 1: Pause Procedures

### When to Use

- Suspicious activity detected (unusual deposit/withdrawal patterns)
- Non-critical bug discovered (fee calculation error)
- Planned maintenance requiring downtime
- External protocol under investigation

### Prerequisites

- Incident severity: P2 or P3
- No immediate fund loss risk
- Issue can be resolved within 24 hours

### Execution Steps

#### Step 1: Assess & Declare (IC)
```
1. Review monitoring alerts
2. Confirm issue severity
3. Declare "Level 1 Pause" in #incident-response
4. Assign roles (Security Lead, Ops Lead, Comms Lead)
```

#### Step 2: Execute Pause (Ops Lead)
```solidity
// Connect to multisig wallet (3/5 signers required)
// Navigate to GiveProtocolCore contract

// Option A: Pause specific vault
emergencyModule.pause(vaultId);

// Option B: Pause all vaults (extreme)
// Loop through all vaults and pause individually
```

**Gas Estimate:** ~150,000 per vault  
**Expected Confirmation:** 1-2 minutes on mainnet

#### Step 3: Verify Pause State (Ops Lead)
```bash
# Check vault state
cast call $VAULT_ADDRESS "paused()" --rpc-url $RPC_URL
# Should return: true (0x0000...0001)

# Verify deposits blocked
cast send $VAULT_ADDRESS "deposit(uint256,address)" 1000000 $USER --rpc-url $RPC_URL
# Should revert with "Pausable: paused"
```

#### Step 4: Communicate (Comms Lead)
```
1. Update status page (status.giveprotocol.org)
2. Post Discord announcement (see templates below)
3. Tweet incident summary
4. Email high-value users (>$10K deposited)
```

#### Step 5: Investigate & Fix (Security Lead)
```
1. Analyze root cause
2. Develop fix (if code change needed)
3. Test fix on fork
4. Prepare upgrade (if needed)
5. Document incident in #incident-log
```

#### Step 6: Unpause (IC Decision)
```solidity
// After issue resolved and fix verified
emergencyModule.unpause(vaultId);
```

**Post-Unpause:**
- Monitor for 1 hour
- Verify normal operations
- Close incident ticket
- Schedule post-mortem (within 48 hours)

### Rollback Procedure

If pause causes more issues than it solves:
```solidity
// Immediate unpause
emergencyModule.unpause(vaultId);

// Document reason in incident log
// Escalate to Level 2 if needed
```

---

## Level 2: Emergency Shutdown

### When to Use

- Critical vulnerability discovered (P0/P1 severity)
- Active exploit in progress
- External adapter compromised
- Immediate fund loss risk

### Prerequisites

- Incident severity: P0 or P1
- TVL at risk: >$100K or >10% of protocol
- No alternative mitigation available

### ⚠️ WARNING

**Emergency shutdown is IRREVERSIBLE without a contract upgrade.**  
Only use when user funds are in immediate danger.

### Execution Steps

#### Step 1: Declare Emergency (IC)
```
1. Assess severity (P0/P1 confirmed)
2. Get Security Lead approval
3. Declare "Level 2 Emergency Shutdown" in #incident-response
4. Page all multisig signers
5. Start 15-minute countdown timer
```

#### Step 2: Prepare Transaction (Ops Lead)
```solidity
// Prepare emergency shutdown transaction
// Target: GiveProtocolCore (via EmergencyModule)

bytes memory callData = abi.encodeWithSignature(
    "emergencyPause(bytes32)",
    vaultId
);

// Add to multisig queue
// Requires 3/5 signatures
// Gas limit: 500,000 (includes adapter divestment)
```

#### Step 3: Gather Signatures (Ops Lead)
```
1. Send multisig transaction link to signers
2. Track signatures in real-time:
   - Signer 1: ✅ Approved (Alice)
   - Signer 2: ✅ Approved (Bob)
   - Signer 3: ✅ Approved (Charlie)
   - Signer 4: ⏳ Pending (David)
   - Signer 5: ⏳ Pending (Eve)
3. Execute once 3/5 threshold met
```

#### Step 4: Execute Shutdown (Ops Lead)
```bash
# Execute multisig transaction
# This will:
# 1. Set vault.emergencyShutdown = true
# 2. Call adapter.divestAll() (auto-divest)
# 3. Start 24-hour grace period timer
# 4. Emit EmergencyShutdown(vaultId, timestamp) event

# Monitor transaction
cast tx $TX_HASH --rpc-url $RPC_URL

# Verify shutdown state
cast call $VAULT_ADDRESS "emergencyShutdown()(bool)" --rpc-url $RPC_URL
# Should return: true

# Verify adapter divested
cast call $ADAPTER_ADDRESS "totalAssets()(uint256)" --rpc-url $RPC_URL
# Should return: 0 or near-0
```

#### Step 5: Immediate Communication (Comms Lead)
**Within 5 minutes of shutdown:**

```
1. Status page: "EMERGENCY SHUTDOWN ACTIVE"
2. Discord pin: Emergency announcement (see templates)
3. Twitter thread: Incident summary + action steps
4. Email blast: All users with deposits in affected vault(s)
5. Update every 30 minutes during grace period
```

#### Step 6: Monitor Grace Period (Ops Lead)
```bash
# Track withdrawals during 24-hour grace period
cast logs --from-block $SHUTDOWN_BLOCK \
  --address $VAULT_ADDRESS \
  --event "Withdraw(address,address,address,uint256,uint256)" \
  --rpc-url $RPC_URL

# Calculate remaining TVL
cast call $VAULT_ADDRESS "totalAssets()(uint256)" --rpc-url $RPC_URL

# Monitor for stuck users (no withdrawal after 20 hours)
# Send targeted outreach
```

#### Step 7: Investigate Root Cause (Security Lead)
```
1. Analyze exploit (if ongoing)
2. Identify vulnerability
3. Assess damage
4. Calculate user impact
5. Develop fix strategy
6. Coordinate with auditor
7. Prepare incident report
```

#### Step 8: Prepare Recovery (All)
```
Security Lead:
- Code fix ready
- Audit review complete
- Test coverage updated

Ops Lead:
- Upgrade transaction prepared
- Multisig coordination scheduled
- Rollout plan documented

Comms Lead:
- User FAQ prepared
- Compensation plan (if needed)
- Press talking points
```

### Grace Period Expiration

**After 24 hours:**
- Level 3 (Emergency Withdrawal) automatically becomes available
- Normal withdrawals still work if liquidity available
- No new deposits allowed
- Harvesting disabled

---

## Level 3: Emergency Withdrawal

### When Available

- **Automatically** after 24-hour grace period expires post-shutdown
- Triggered by **any user** (no special permissions)
- Used when normal withdrawal fails (liquidity issues)

### User Instructions

#### For Users (Public Documentation)

**When to Use:**
- Vault is in emergency shutdown (>24 hours ago)
- Normal withdrawal fails or reverts
- You need immediate access to funds

**How to Withdraw:**

**Via Etherscan (Manual):**
```
1. Navigate to vault contract on Etherscan
2. Go to "Write Contract" tab
3. Connect wallet (MetaMask/WalletConnect)
4. Find "emergencyWithdrawUser" function
5. Enter parameters:
   - assets: Amount to withdraw (in wei, e.g., 1000000 for 1 USDC)
   - receiver: Your address (or beneficiary)
   - owner: Your address
6. Click "Write" and confirm transaction
7. Wait for confirmation (~1-2 minutes)
```

**Via Frontend (If Available):**
```
1. Go to app.giveprotocol.org
2. Connect wallet
3. Navigate to affected vault
4. Click "Emergency Withdraw" button
5. Enter amount
6. Confirm transaction
7. Funds arrive in ~1-2 minutes
```

#### For Operations Team

**Monitor Emergency Withdrawals:**
```bash
# Track emergency withdrawal events
cast logs --from-block $GRACE_EXPIRY_BLOCK \
  --address $VAULT_ADDRESS \
  --event "EmergencyWithdraw(address,address,uint256)" \
  --rpc-url $RPC_URL

# Calculate total withdrawn
cast call $VAULT_ADDRESS "totalEmergencyWithdrawn()(uint256)" --rpc-url $RPC_URL

# Identify users who haven't withdrawn
# Cross-reference with pre-shutdown snapshot
# Send targeted outreach after 48 hours
```

**Assist Stuck Users:**
```
1. User reports withdrawal issue
2. Verify vault state (emergency mode + grace expired)
3. Check user's share balance
4. Guide through manual withdrawal process
5. If still stuck, investigate:
   - Gas issues?
   - Slippage issues?
   - Contract bug?
6. Escalate to Security Lead if needed
```

---

## Post-Incident Procedures

### Immediate (Within 24 Hours)

#### 1. User Impact Assessment
```
- Total TVL at risk: $___________
- Total actual loss: $___________
- Users affected: ___________
- Users fully withdrawn: ___________
- Users pending withdrawal: ___________
```

#### 2. Root Cause Analysis (RCA)
```
Incident Title: ____________________
Severity: P0 / P1 / P2 / P3
Duration: ______ (from detection to resolution)

Timeline:
- [HH:MM] Event A
- [HH:MM] Event B
- [HH:MM] Event C

Root Cause:
- What happened: ____________________
- Why it happened: ____________________
- Why not detected sooner: ____________________

Impact:
- Financial: ____________________
- Reputational: ____________________
- Operational: ____________________
```

#### 3. Compensation Plan (If Needed)
```
Eligibility:
- Users with deposits at time T
- Users who suffered loss >$X

Compensation Amount:
- 100% principal restoration (always)
- Yield loss compensation: _____%
- Gas cost reimbursement: Yes/No

Distribution Method:
- Direct transfer
- Claim portal
- Airdrop

Timeline:
- Announcement: ____________________
- Claims open: ____________________
- Claims close: ____________________
```

### Short-Term (Within 1 Week)

#### 4. Post-Mortem Meeting
```
Attendees:
- Full response team
- CEO
- Auditor (if applicable)

Agenda:
1. Timeline review
2. What went well
3. What went poorly
4. Action items
5. Process improvements

Deliverable: Written post-mortem document
```

#### 5. Fix Deployment
```
1. Code fix implemented
2. Tests added (prevent regression)
3. Audit review complete
4. Staging deployment successful
5. Upgrade transaction prepared
6. Multisig coordination scheduled
7. User notification sent (24hr heads-up)
8. Upgrade executed
9. Post-upgrade verification
10. Monitor for 48 hours
```

#### 6. Process Improvements
```
Prevention:
- What controls failed? ____________________
- What tests missed this? ____________________
- What monitoring gap existed? ____________________

Detection:
- How was incident discovered? ____________________
- Could we have detected sooner? ____________________
- What alerts should be added? ____________________

Response:
- What went well? ____________________
- What was confusing? ____________________
- What took too long? ____________________
- Update runbook based on learnings
```

### Long-Term (Within 1 Month)

#### 7. Transparency Report (Public)
```
Title: [Date] Incident Report - [Brief Description]

Summary:
- What happened (user-friendly)
- Impact (TVL, users affected)
- Resolution (how we fixed it)
- Compensation (if applicable)

Technical Details:
- Root cause (detailed)
- Vulnerability description
- Fix implementation
- Security improvements

Lessons Learned:
- Process improvements
- Monitoring enhancements
- Testing gaps closed

Next Steps:
- External audit scheduled
- Bug bounty increased
- [Other improvements]
```

#### 8. Security Enhancements
```
- [ ] Add test cases for this scenario
- [ ] Implement additional monitoring
- [ ] Update documentation
- [ ] Train team on new procedures
- [ ] Schedule follow-up audit
- [ ] Review similar protocols for issues
- [ ] Consider insurance/coverage options
```

---

## Communication Templates

### Template 1: Level 1 Pause (Discord/Twitter)

```
🔴 PROTOCOL UPDATE - TEMPORARY PAUSE

We have temporarily paused deposits/withdrawals on [Vault Name] to investigate [brief issue description].

Status: 🟡 Investigating
Your Funds: ✅ Safe
Withdrawals: ⏸️ Paused (temporary)
ETA: [X] hours

What we're doing:
- Investigating root cause
- Preparing fix
- Testing solution

Updates every 30 minutes: status.giveprotocol.org

Questions? Reply here or support@giveprotocol.org
```

### Template 2: Level 2 Emergency Shutdown (Discord/Twitter)

```
🚨 EMERGENCY SHUTDOWN ACTIVATED

We have activated emergency shutdown on [Vault Name] due to [critical issue].

Status: 🔴 Emergency Mode
Your Funds: ✅ Secured (auto-divested from yield source)
Grace Period: ⏰ 24 hours for normal withdrawals
Your Action: Withdraw funds at your convenience

Timeline:
- Now: Adapters divested, funds secured
- Next 24hrs: Normal withdrawals available
- After 24hrs: Emergency withdrawals available (if needed)

How to withdraw:
1. Visit app.giveprotocol.org
2. Connect wallet
3. Click "Withdraw" on [Vault Name]
4. Confirm transaction

We are working on a fix and will provide updates every hour.

Details: [link to status page]
Support: support@giveprotocol.org
```

### Template 3: Grace Period Update (Email)

```
Subject: [Action Required] Emergency Withdrawal Period - GIVE Protocol

Dear GIVE Protocol User,

On [Date] at [Time], we activated emergency shutdown on [Vault Name] to protect user funds from [issue description].

YOUR FUNDS ARE SAFE. All assets have been divested from yield sources and secured in the vault contract.

WHAT YOU NEED TO DO:
1. Withdraw your funds within the next [X] hours
2. Visit app.giveprotocol.org or use Etherscan (guide: [link])
3. Your full principal is available ($_____ as of [timestamp])

TIMELINE:
- Grace Period Ends: [Date] at [Time] ([X] hours remaining)
- After Grace Period: Emergency withdrawal available (no time limit)

WHY THIS HAPPENED:
[Brief, honest explanation]

WHAT WE'RE DOING:
- Fixing root cause
- Preparing protocol upgrade
- Coordinating with auditors
- Preventing future issues

QUESTIONS?
- Status Page: status.giveprotocol.org
- Support Email: support@giveprotocol.org
- Discord: discord.gg/giveprotocol

We sincerely apologize for this disruption. Your trust is our priority.

The GIVE Protocol Team
```

### Template 4: All-Clear Announcement

```
✅ INCIDENT RESOLVED - OPERATIONS RESUMED

[Vault Name] has been restored to normal operations after [duration] of emergency mode.

Status: 🟢 Fully Operational
Issue: ✅ Fixed & Tested
Audit: ✅ Reviewed
Monitoring: ✅ Enhanced

What happened:
[Brief summary]

What we fixed:
[Technical fix description]

What we improved:
- [Improvement 1]
- [Improvement 2]
- [Improvement 3]

Compensation (if applicable):
[Details or link to claim portal]

Full post-mortem: [link]

Thank you for your patience and trust.
```

---

## Recovery Procedures

### Upgrade After Emergency

```bash
# 1. Prepare upgrade transaction
forge script script/UpgradeVault.s.sol \
  --rpc-url $RPC_URL \
  --private-key $DEPLOYER_KEY \
  --broadcast

# 2. Verify new implementation
forge verify-contract $NEW_IMPL_ADDRESS GiveVault4626 \
  --chain-id 1 \
  --etherscan-api-key $ETHERSCAN_KEY

# 3. Submit to multisig
# (Use Gnosis Safe UI)

# 4. Execute upgrade (after 3/5 sigs)
# Automatically calls upgradeToAndCall

# 5. Verify upgrade
cast call $VAULT_PROXY "implementation()(address)" --rpc-url $RPC_URL
# Should return new implementation address

# 6. Test basic operations
cast send $VAULT_PROXY "deposit(uint256,address)" 1000000 $TEST_USER \
  --rpc-url $RPC_URL \
  --private-key $TEST_KEY

# 7. Monitor for 48 hours
# Watch for anomalies, errors, reverts
```

### Re-enabling Adapters

```solidity
// After upgrade, re-configure adapters
vaultModule.configureAdapter(
    vaultId,
    newAdapterAddress,
    maxSlippage,
    healthCheckEnabled
);

// Verify adapter state
adapter.totalAssets(); // Should return 0 initially

// Resume auto-investment
vault.setInvestmentRatio(9900); // 99% back to adapter

// Monitor first harvest closely
```

### User Re-engagement

```
1. Announce "All Clear" (see template above)
2. Offer gas reimbursement for re-deposits (first 100 users)
3. Run AMA (Ask Me Anything) session on Discord
4. Publish detailed post-mortem
5. Highlight security improvements
6. Consider promotional campaign (bonus APY for X days)
7. Individual outreach to high-value users
```

---

## Appendix

### Emergency Transaction Templates

**Gnosis Safe Transaction Builder:**
```json
{
  "version": "1.0",
  "chainId": "1",
  "createdAt": 1234567890,
  "meta": {
    "name": "Emergency Shutdown - Vault XYZ",
    "description": "Level 2 emergency response",
    "txBuilderVersion": "1.16.5"
  },
  "transactions": [
    {
      "to": "0x... (GiveProtocolCore address)",
      "value": "0",
      "data": "0x... (emergencyPause calldata)",
      "contractMethod": {
        "name": "emergencyPause",
        "inputs": [
          {"name": "vaultId", "type": "bytes32", "value": "0x..."}
        ]
      }
    }
  ]
}
```

### Monitoring Alert Thresholds

```yaml
# /monitoring/alerts.yaml
alerts:
  - name: large_withdrawal
    condition: withdrawal_amount > $100,000
    severity: P2
    notify: [ops-team]
  
  - name: rapid_withdrawals
    condition: withdrawal_count > 50 in 10_minutes
    severity: P1
    notify: [ops-team, security-team]
  
  - name: failed_harvest
    condition: harvest_revert_count > 3
    severity: P1
    notify: [ops-team]
  
  - name: adapter_loss
    condition: adapter_tvl_delta < -5%
    severity: P0
    notify: [everyone, page-incident-commander]
  
  - name: emergency_shutdown_triggered
    condition: EmergencyShutdown event emitted
    severity: P0
    notify: [everyone, page-all]
```

### Testing Emergency Procedures

```bash
# Quarterly drill schedule
Q1: Level 1 Pause drill (staging environment)
Q2: Level 2 Shutdown drill (staging + response team coordination)
Q3: Level 1 Pause drill (production testnet)
Q4: Full incident simulation (tabletop exercise)

# Drill checklist
- [ ] All team members available?
- [ ] Communication channels working?
- [ ] Multisig signers responsive?
- [ ] Transactions execute successfully?
- [ ] Monitoring alerts triggered correctly?
- [ ] User communications clear?
- [ ] Post-drill debrief scheduled?
```

---

**Document Owner:** Security Team  
**Last Drill:** [Date]  
**Next Review:** [Date + 3 months]  
**Version:** 0.5.0

**For Emergencies:**  
📞 +1-555-GIVE-911  
📧 emergency@giveprotocol.org  
💬 Discord #incident-response
