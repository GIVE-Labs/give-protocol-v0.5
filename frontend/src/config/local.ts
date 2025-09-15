// Local Anvil configuration for development
import { localhost } from 'viem/chains';

// Contract addresses from local Anvil deployment
// These addresses are from the latest deployment to chain ID 31337
export const LOCAL_CONTRACT_ADDRESSES = {
  // Main protocol contracts - update these with actual deployed addresses
  NGO_REGISTRY: '0x5FbDB2315678afecb367f032d93F642f64180aa3', // Update with actual address
  DONATION_ROUTER: '0x8A791620dd6260079BF849Dc5567aDC3F2FdC318', // From deployment logs
  VAULT: '0x0165878A594ca255338adfa4d48449f69242Eb8F', // Update with actual address
  STRATEGY_MANAGER: '0xb7f8bc63bbcad18155201308c8f3540b07f84f5e', // From deployment logs
  AAVE_ADAPTER: '0x5f3f1dBD7B74C6B46e8c44f98792A1dAf8d69154', // Mock yield adapter for local testing

  // Mock tokens for local testing
  TOKENS: {
    ETH: '0x0000000000000000000000000000000000000000', // Native ETH
    USDC: '0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512', // Mock USDC from deployment
    WETH: '0xcf7ed3AccA5a467e9e704C703E8D87F634fB0Fc9', // Mock WETH from deployment
  }
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
} = LOCAL_CONTRACT_ADDRESSES;

export const {
  USDC: LOCAL_USDC,
  WETH: LOCAL_WETH,
} = LOCAL_CONTRACT_ADDRESSES.TOKENS;