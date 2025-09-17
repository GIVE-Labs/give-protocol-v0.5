// Local Anvil configuration for development
import { localhost } from 'viem/chains';

// Contract addresses from local Anvil deployment
// These addresses are from the latest deployment to chain ID 31337
export const LOCAL_CONTRACT_ADDRESSES = {
  // Protocol contracts - USDC Vault
  VAULT: "0x610178dA211FEF7D417bC0e6FeD39F05609AD788",
  AAVE_ADAPTER: "0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0",
  STRATEGY_MANAGER: "0xB7f8BC63BbcaD18155201308C8f3540b07f84F5e",
  
  // ETH Vault contracts
  ETH_VAULT: "0x1613beB3B2C4f22Ee086B2b38C1476A3cE7f78E8",
  ETH_VAULT_MANAGER: "0xf5059a5D33d5853360D16C683c16e67980206f36",
  ETH_VAULT_ADAPTER: "0x95401dc811bb5740090279Ba06cfA8fcF6113778",
  
  // Shared contracts
  NGO_REGISTRY: "0x2279B7A0a67DB372996a5FaB50D91eAA73d2eBe6",
  DONATION_ROUTER: "0x8A791620dd6260079BF849Dc5567aDC3F2FdC318",
  
  // Mock tokens for local testing
  ETH: "0xe6e340d132b5f46d1e472debcd681b2abc16e57e",
  USDC: "0x9e545e3c0baab3e08cdfd552c960a1050f373042",
  WETH: "0x59b670e9fA9D0A427751Af201D676719a970857b",
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