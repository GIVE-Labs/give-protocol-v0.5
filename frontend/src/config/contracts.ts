import { LOCAL_CONTRACT_ADDRESSES } from './local';
import { SEPOLIA_CONTRACT_ADDRESSES } from './sepolia';

// Network configuration
export const NETWORK_CONFIG = {
  LOCAL: {
    chainId: 31337,
    name: 'Anvil Local',
    contracts: LOCAL_CONTRACT_ADDRESSES
  },
  SEPOLIA: {
    chainId: 11155111,
    name: 'Sepolia Testnet',
    contracts: SEPOLIA_CONTRACT_ADDRESSES
  }
} as const;

// Environment-based contract addresses
// Default to Sepolia unless explicitly set to use local
const useLocal = import.meta.env.VITE_USE_LOCAL === 'true';

export const CONTRACT_ADDRESSES = useLocal
  ? LOCAL_CONTRACT_ADDRESSES
  : SEPOLIA_CONTRACT_ADDRESSES;

// Export current network config
export const CURRENT_NETWORK = useLocal
  ? NETWORK_CONFIG.LOCAL
  : NETWORK_CONFIG.SEPOLIA;

// Export SEPOLIA for chain configuration
export const SEPOLIA = SEPOLIA_CONTRACT_ADDRESSES;

// Export individual contract addresses for convenience
export const MOCK_WETH = useLocal 
  ? (CONTRACT_ADDRESSES as typeof LOCAL_CONTRACT_ADDRESSES).WETH 
  : (CONTRACT_ADDRESSES as typeof SEPOLIA_CONTRACT_ADDRESSES).WETH;
export const MOCK_USDC = useLocal 
  ? (CONTRACT_ADDRESSES as typeof LOCAL_CONTRACT_ADDRESSES).USDC 
  : (CONTRACT_ADDRESSES as typeof SEPOLIA_CONTRACT_ADDRESSES).USDC;
export const MOCK_ETH = useLocal 
  ? (CONTRACT_ADDRESSES as typeof LOCAL_CONTRACT_ADDRESSES).ETH 
  : (CONTRACT_ADDRESSES as typeof SEPOLIA_CONTRACT_ADDRESSES).ETH;
export const NGO_REGISTRY = CONTRACT_ADDRESSES.NGO_REGISTRY;
export const VAULT = CONTRACT_ADDRESSES.VAULT;
export const ETH_VAULT = useLocal ? (CONTRACT_ADDRESSES as typeof LOCAL_CONTRACT_ADDRESSES).ETH_VAULT : undefined;
export const ETH_VAULT_MANAGER = useLocal ? (CONTRACT_ADDRESSES as typeof LOCAL_CONTRACT_ADDRESSES).ETH_VAULT_MANAGER : undefined;
export const ETH_VAULT_ADAPTER = useLocal ? (CONTRACT_ADDRESSES as typeof LOCAL_CONTRACT_ADDRESSES).ETH_VAULT_ADAPTER : undefined;
export const STRATEGY_MANAGER = CONTRACT_ADDRESSES.STRATEGY_MANAGER;
export const AAVE_ADAPTER = CONTRACT_ADDRESSES.AAVE_ADAPTER;
export const DONATION_ROUTER = CONTRACT_ADDRESSES.DONATION_ROUTER;
