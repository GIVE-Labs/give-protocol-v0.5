// Local Anvil configuration for development
import { localhost } from 'viem/chains';

// Contract addresses from local Anvil deployment
// These addresses are from the latest deployment to chain ID 31337
export const LOCAL_CONTRACT_ADDRESSES = {
  // Protocol contracts - USDC Vault
  VAULT: "0x95401dc811bb5740090279Ba06cfA8fcF6113778",
  AAVE_ADAPTER: "0x70e0bA845a1A0F2DA3359C97E0285013525FFC49",
  STRATEGY_MANAGER: "0x998abeb3E57409262aE5b751f60747921B33613E",
  
  // ETH Vault contracts
  ETH_VAULT: "0x1613beB3B2C4f22Ee086B2b38C1476A3cE7f78E8",
  ETH_VAULT_MANAGER: "0xf5059a5D33d5853360D16C683c16e67980206f36",
  ETH_VAULT_ADAPTER: "0x95401dc811bb5740090279Ba06cfA8fcF6113778",
  
  // Shared contracts
  NGO_REGISTRY: "0x851356ae760d987E095750cCeb3bC6014560891C",
  DONATION_ROUTER: "0xf5059a5D33d5853360D16C683c16e67980206f36",
  
  // Mock tokens for local testing
  ETH: "0xe6e340d132b5f46d1e472debcd681b2abc16e57e",
  USDC: "0xb7278A61aa25c888815aFC32Ad3cC52fF24fE575",
  WETH: "0x4c5859f0F772848b2D91F1D83E2Fe57935348029",
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