# Manual Testing Guide - Frontend v0.5

## Prerequisites ✅
- ✅ Dev server running on `http://localhost:5173/`
- ✅ Test campaign deployed on Base Sepolia
- ✅ Code-splitting optimizations implemented

## Campaign Details

**Campaign ID**: `0xfc3499b4e524ba1ed95b187b35f60b06da3838953a7051b918b3fb77f3726416`

**Details:**
- Status: Approved (2)
- Recipient: `0x742D35CC6634c0532925A3b844BC9E7595F0BEb0`
- Target Stake: 10 ETH
- Min Stake: 0.01 ETH
- Fundraising: 90 days from creation

**Contract Addresses (Base Sepolia):**
- CampaignRegistry: `0x51929ec1C089463fBeF6148B86F34117D9CCF816`
- GiveVault4626: `0x28ac6D6505E2875FFF9E13d1B788A8d4740a7278`
- PayoutRouter: `0x1c63A5b47985e610aB2B04dCCea3C49d75F9b388`
- WETH: `0x4200000000000000000000000000000000000006`

---

## Test 1: Campaign Browsing (5 min)

### Steps:
1. Open browser: `http://localhost:5173/`
2. Navigate to **Campaigns** page (click nav link or visit `/campaigns`)
3. **Expected**: Campaign card should appear showing:
   - Title/metadata
   - Recipient address: `0x742D...BEb0`
   - Target stake: 10 ETH
   - Status: Approved
   - Allocation selector: 50% / 75% / 100% buttons
4. Test allocation selector interaction (buttons should highlight on click)
5. Check browser console for errors (F12 → Console tab)

### ✅ Pass Criteria:
- [ ] Campaign appears in list
- [ ] All campaign data displays correctly
- [ ] No console errors
- [ ] Allocation buttons are interactive

---

## Test 2: Wallet Connection (3 min)

### Steps:
1. Click **"Connect Wallet"** button in header
2. Select MetaMask/wallet of choice
3. **Important**: Switch to **Base Sepolia** network (Chain ID 84532)
4. Approve connection
5. **Expected**:
   - Wallet address displays in header
   - Balance shows in dashboard
   - Network indicator shows "Base Sepolia"

### ✅ Pass Criteria:
- [ ] Wallet connects successfully
- [ ] Address displays correctly
- [ ] Network is Base Sepolia
- [ ] No connection errors

---

## Test 3: Deposit Flow (15 min)

### Prerequisites:
Get Base Sepolia ETH from faucets:
- **Alchemy Faucet**: https://www.alchemy.com/faucets/base-sepolia
- **Coinbase Faucet**: https://www.coinbase.com/faucets/base-ethereum-sepolia-faucet
- Request ~0.1 ETH

### Steps:

#### 3.1 Navigate to Deposit
1. Go to **Dashboard** page
2. Click **"Deposit More"** button
3. Enter amount: `0.01` ETH

#### 3.2 Wrap ETH → WETH
1. Click **"Wrap ETH"** button
2. Confirm transaction in wallet
3. Wait for confirmation (~2 seconds)
4. **Expected**: WETH balance updates

#### 3.3 Approve WETH
1. Click **"Approve WETH"** button
2. Confirm approval transaction
3. Amount should be ≥ 0.01 WETH
4. **Expected**: Approval confirmed

#### 3.4 Deposit to Vault
1. Click **"Deposit"** button
2. Confirm deposit transaction
3. Wait for confirmation
4. **Expected**:
   - VaultStats updates
   - Your deposit balance increases
   - Total vault assets increases
   - Share balance > 0

### ✅ Pass Criteria:
- [ ] Wrap transaction succeeds
- [ ] Approve transaction succeeds
- [ ] Deposit transaction succeeds
- [ ] VaultStats shows updated balances
- [ ] No transaction errors

---

## Test 4: Payout Preferences (10 min)

### Prerequisites:
- Must have completed Test 3 (deposit flow)
- Must have vault shares > 0

### Steps:

#### 4.1 Set Preference
1. Go to **Campaigns** page
2. Find test campaign card
3. Select allocation: **75%** (or any preference)
4. Click **"Donate 75%"** button
5. Confirm transaction in wallet
6. Wait for confirmation

#### 4.2 Verify Preference
1. Go to **Dashboard** page
2. Find "Payout Preferences" section
3. **Expected**:
   - Campaign ID: `0xfc34...6416`
   - Allocation: 75%
   - Status: Active

### ✅ Pass Criteria:
- [ ] Preference transaction succeeds
- [ ] Dashboard shows preference correctly
- [ ] Campaign shows as "preferred" in list
- [ ] No errors in console

---

## Test 5: Mobile Responsiveness (10 min)

### Steps:

#### 5.1 Open DevTools
1. Press **F12** to open Chrome DevTools
2. Click **Toggle Device Toolbar** (Ctrl+Shift+M or icon)

#### 5.2 Test iPhone SE (375px)
1. Select "iPhone SE" preset
2. Navigate through all pages:
   - Home
   - Campaigns
   - Dashboard
3. **Expected**:
   - Campaign grid: 1 column
   - Cards stack vertically
   - Buttons remain tappable (min 44px height)
   - Wallet modal fits screen
   - No horizontal scroll

#### 5.3 Test iPad (768px)
1. Select "iPad" preset
2. Navigate through all pages
3. **Expected**:
   - Campaign grid: 2 columns
   - Layout adjusts gracefully
   - Touch targets remain large

#### 5.4 Test Desktop (1024px+)
1. Resize to desktop width
2. **Expected**:
   - Campaign grid: 3 columns
   - Full navigation visible
   - Optimal spacing

### ✅ Pass Criteria:
- [ ] Mobile layout (1 column) works
- [ ] Tablet layout (2 columns) works
- [ ] Desktop layout (3 columns) works
- [ ] No layout breaks
- [ ] All buttons remain accessible

---

## Test 6: Error Handling (5 min)

### Steps:

#### 6.1 Test Wrong Network
1. Switch wallet to Ethereum Mainnet (or any non-Base Sepolia)
2. Try to deposit
3. **Expected**: Error message or network switch prompt

#### 6.2 Test Insufficient Balance
1. Try to deposit more ETH than you have
2. **Expected**: Error message or disabled button

#### 6.3 Test Rejected Transaction
1. Start a deposit
2. Reject transaction in wallet
3. **Expected**: Error message, UI doesn't break

### ✅ Pass Criteria:
- [ ] Wrong network is handled gracefully
- [ ] Insufficient balance is handled
- [ ] Rejected transactions don't crash UI
- [ ] Error messages are user-friendly

---

## Common Issues & Fixes

### Issue: Campaign doesn't appear
- **Check**: Browser console for fetch errors
- **Fix**: Verify campaign contract address in `baseSepolia.ts`
- **Fix**: Clear browser cache and reload

### Issue: Wallet won't connect
- **Check**: MetaMask is unlocked
- **Check**: Base Sepolia network is added to wallet
- **Fix**: Add Base Sepolia manually:
  - RPC: `https://sepolia.base.org`
  - Chain ID: `84532`
  - Currency: `ETH`

### Issue: Transactions fail
- **Check**: Sufficient ETH for gas
- **Check**: Correct network (Base Sepolia)
- **Check**: Contract addresses are correct

### Issue: Code-splitting errors
- **Check**: Browser console for chunk load errors
- **Fix**: Rebuild: `cd frontend && pnpm build`
- **Fix**: Clear dist folder: `rm -rf frontend/dist`

---

## Completion Checklist

### Functionality Tests
- [ ] Test 1: Campaign browsing
- [ ] Test 2: Wallet connection
- [ ] Test 3: Deposit flow
- [ ] Test 4: Payout preferences
- [ ] Test 5: Mobile responsiveness
- [ ] Test 6: Error handling

### Technical Verification
- [ ] No console errors on any page
- [ ] No TypeScript errors: `pnpm tsc --noEmit`
- [ ] Production build succeeds: `pnpm build`
- [ ] Bundle size acceptable (<2MB main chunk)
- [ ] All routes load correctly
- [ ] Code-splitting works (separate chunks)

### User Experience
- [ ] Loading states appear during transactions
- [ ] Success messages confirm actions
- [ ] Error messages are clear
- [ ] UI is responsive on all screen sizes
- [ ] Wallet integration is smooth
- [ ] Transaction flow is intuitive

---

## Next Steps After Testing

Once all tests pass:

1. **Document any bugs** found
2. **Screenshot** any UI issues
3. **Note** any UX improvements
4. **Proceed to Phase 6**: Vercel Deployment
   - Run production build
   - Configure environment variables
   - Deploy to Vercel
   - Test live site

---

## Quick Commands Reference

```bash
# Start dev server
cd frontend && pnpm dev

# TypeScript check
cd frontend && pnpm tsc --noEmit

# Production build
cd frontend && pnpm build

# Preview production build
cd frontend && pnpm preview

# Check contract on Base Sepolia
cd backend && cast call 0x51929ec1C089463fBeF6148B86F34117D9CCF816 \
  "getCampaign(bytes32)" \
  0xfc3499b4e524ba1ed95b187b35f60b06da3838953a7051b918b3fb77f3726416 \
  --rpc-url base_sepolia
```

---

**Good luck with testing! 🚀**
