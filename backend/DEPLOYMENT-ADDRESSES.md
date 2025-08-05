# MorphImpact Deployment Addresses

## Network: Morph Holesky Testnet
- **Chain ID**: 2810
- **RPC URL**: https://rpc-holesky.morphl2.io
- **Explorer**: https://explorer-holesky.morphl2.io

## Deployed Contracts

### Core Protocol Contracts
- **NGORegistry**: `0x724dc0c1AE0d8559C48D0325Ff4cC8F45FE703De`
- **MockYieldVault**: `0x13991842a2fB1139274A181c4e07210252B5D559`
- **MorphImpactStaking**: `0xE05473424Df537c9934748890d3D8A5b549da1C0`
- **YieldDistributor**: `0x26C19066b8492D642aDBaFD3C24f104fCeb14DA9`

### Mock Tokens (for testing)
- **MockUSDC**: `0x44F38B49ddaAE53751BEEb32Eb3b958d950B26e6`
- **MockWETH**: `0x81F5c69b5312aD339144489f2ea5129523437bdC`

## Registered NGOs

### Verified NGOs
1. **Education For All**
   - Address: `0x1234567890123456789012345678901234567890`
   - Description: Providing quality education to underprivileged children worldwide
   - Website: https://educationforall.org
   - Causes: Education, Technology, Children
   - Status: ✅ Verified

2. **Clean Water Initiative**
   - Address: `0x2345678901234567890123456789012345678901`
   - Description: Bringing clean water to communities in need
   - Website: https://cleanwaterinitiative.org
   - Causes: Environment, Health, Water
   - Status: ✅ Verified

3. **HealthCare Access**
   - Address: `0x3456789012345678901234567890123456789012`
   - Description: Ensuring equitable access to healthcare services
   - Website: https://healthcareaccess.org
   - Causes: Health, Technology, Community
   - Status: ✅ Verified

## Token Configuration

### Supported Tokens
- **USDC**: 10% APY
- **WETH**: 8% APY

### Initial Liquidity Setup
- **USDC**: 50,000 USDC in vault
- **WETH**: 50 WETH in vault

## Deployment Details
- **Deployer**: 0x1d152003e1d9b6419434a629fb86bb051a7157d27447e618a7a0f68cdbe22937
- **Gas Used**: 12,160,828 gas
- **Gas Price**: 0.002000001 gwei
- **Total Cost**: 0.000024321668160828 ETH
- **Block Explorer**: https://explorer-holesky.morphl2.io

## Next Steps
1. Update frontend contract addresses in `frontend/src/config/contracts.ts`
2. Test staking functionality with mock tokens
3. Verify all contracts work correctly with the deployed addresses
4. Ready for frontend integration

## Contract Verification
All contracts are automatically verified on the Morph Holesky explorer. You can view them at:
- https://explorer-holesky.morphl2.io/address/0xfC9572Cf3c528918dafbAa6F9b1D1E7dE62d0cBB
- https://explorer-holesky.morphl2.io/address/0x5368b928eFD703f060834252E8Dffe0Ad5151b7c
- https://explorer-holesky.morphl2.io/address/0xa2dCeE55cD951D809C0762574ed4016E31E18419
- https://explorer-holesky.morphl2.io/address/0x94117FD7961b2DDd56725DfD5Ba2FcCFc56F3282