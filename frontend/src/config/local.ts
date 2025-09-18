// Local Anvil configuration for development
import { localhost } from 'viem/chains';

// Contract addresses from local Anvil deployment
// These addresses are from the latest deployment to chain ID 31337
export const LOCAL_CONTRACT_ADDRESSES = {
  // USDC Vault System
  VAULT: '0x610178dA211FEF7D417bC0e6FeD39F05609AD788',
  AAVE_ADAPTER: '0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0',
  STRATEGY_MANAGER: '0xB7f8BC63BbcaD18155201308C8f3540b07f84F5e',
  
  // ETH Vault System  
  ETH_VAULT: '0xc5a5C42992dECbae36851359345FE25997F5C42d',
  ETH_VAULT_MANAGER: '0xE6E340D132b5f46d1e472DebcD681B2aBc16e57E',
  ETH_VAULT_ADAPTER: '0xc3e53F4d16Ae77Db1c982e75a937B9f60FE63690',
  
  // Shared Contracts
  NGO_REGISTRY: '0x2279B7A0a67DB372996a5FaB50D91eAA73d2eBe6',
  DONATION_ROUTER: '0x8A791620dd6260079BF849Dc5567aDC3F2FdC318',
  
  // Mock Tokens
  ETH: '0x0000000000000000000000000000000000000000', // Native ETH
  USDC: '0x0E801D84Fa97b50751Dbf25036d067dCf18858bF',
  WETH: '0x70e0bA845a1A0F2DA3359C97E0285013525FFC49',
} as const;

// Local Anvil chain configuration
export const ANVIL_CHAIN = {
  ...localhost,
  id: 31337,
  name: 'Anvil Local',
  nativeCurrency: {
    name: 'ETH',
    symbol: 'ETH',
    decimals: 18,
  },
  rpcUrls: {
    default: { http: ['http://localhost:8545'] },
  },
  blockExplorers: {
    default: { name: 'Local Explorer', url: 'http://localhost:8545' },
  },
  testnet: true,
} as const;

// Export individual contract addresses for convenience
export const {
  NGO_REGISTRY: LOCAL_NGO_REGISTRY,
  DONATION_ROUTER: LOCAL_DONATION_ROUTER,
  VAULT: LOCAL_VAULT,
  STRATEGY_MANAGER: LOCAL_STRATEGY_MANAGER,
  AAVE_ADAPTER: LOCAL_AAVE_ADAPTER,
  ETH_VAULT: LOCAL_ETH_VAULT,
  ETH_VAULT_MANAGER: LOCAL_ETH_VAULT_MANAGER,
  ETH_VAULT_ADAPTER: LOCAL_ETH_VAULT_ADAPTER,
  ETH: LOCAL_ETH,
  USDC: LOCAL_USDC,
  WETH: LOCAL_WETH,
} = LOCAL_CONTRACT_ADDRESSES;