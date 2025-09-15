// Local Anvil configuration for development
import { localhost } from 'viem/chains';

// Contract addresses from local Anvil deployment
// These addresses are from the latest deployment to chain ID 31337
export const LOCAL_CONTRACT_ADDRESSES = {
  // Main protocol contracts - updated with latest deployment addresses
  NGO_REGISTRY: '0x2279B7A0a67DB372996a5FaB50D91eAA73d2eBe6', // Latest deployment
  DONATION_ROUTER: '0x67d269191c92Caf3cD7723F116c85e6E9bf55933', // Latest deployment
  VAULT: '0x610178dA211FEF7D417bC0e6FeD39F05609AD788', // Latest deployment
  STRATEGY_MANAGER: '0xB7f8BC63BbcaD18155201308C8f3540b07f84F5e', // Latest deployment
  AAVE_ADAPTER: '0xa85233C63b9Ee964Add6F2cffe00Fd84eb32338f', // Mock yield adapter for local testing

  // Mock tokens for local testing
  TOKENS: {
    ETH: '0x0000000000000000000000000000000000000000', // Native ETH
    USDC: '0x4ed7c70F96B99c776995fB64377f0d4aB3B0e1C1', // Mock USDC from latest deployment
    WETH: '0xc6e7DF5E7b4f2A278906862b61205850344D4e7d', // Mock WETH from latest deployment
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