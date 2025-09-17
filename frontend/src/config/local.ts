// Local Anvil configuration for development
import { localhost } from 'viem/chains';

// Contract addresses from local Anvil deployment
// These addresses are from the latest deployment to chain ID 31337
export const LOCAL_CONTRACT_ADDRESSES = {
  // USDC Vault System
  VAULT: '0x0ed64d01D0B4B655E410EF1441dD677B695639E7',
  AAVE_ADAPTER: '0x40a42Baf86Fc821f972Ad2aC878729063CeEF403',
  STRATEGY_MANAGER: '0x4bf010f1b9beDA5450a8dD702ED602A104ff65EE',
  
  // ETH Vault System  
  ETH_VAULT: '0x70bDA08DBe07363968e9EE53d899dFE48560605B',
  ETH_VAULT_MANAGER: '0xA56F946D6398Dd7d9D4D9B337Cf9E0F68982ca5B',
  ETH_VAULT_ADAPTER: '0x5D42EBdBBa61412295D7b0302d6F50aC449Ddb4F',
  
  // Shared Contracts
  NGO_REGISTRY: '0xa6e99A4ED7498b3cdDCBB61a6A607a4925Faa1B7',
  DONATION_ROUTER: '0x5302E909d1e93e30F05B5D6Eea766363D14F9892',
  
  // Mock Tokens
  ETH: '0x0000000000000000000000000000000000000000', // Native ETH
  USDC: '0x71089Ba41e478702e1904692385Be3972B2cBf9e',
  WETH: '0x821f3361D454cc98b7555221A06Be563a7E2E0A6',
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