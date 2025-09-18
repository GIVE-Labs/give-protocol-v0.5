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
const isDevelopment = import.meta.env.DEV;
export const CONTRACT_ADDRESSES = isDevelopment 
  ? LOCAL_CONTRACT_ADDRESSES 
  : SEPOLIA_CONTRACT_ADDRESSES;

// Export current network config
export const CURRENT_NETWORK = isDevelopment 
  ? NETWORK_CONFIG.LOCAL 
  : NETWORK_CONFIG.SEPOLIA;

// Export SEPOLIA for chain configuration
export const SEPOLIA = SEPOLIA_CONTRACT_ADDRESSES;

// Export individual contract addresses for convenience
export const MOCK_WETH = isDevelopment 
  ? (CONTRACT_ADDRESSES as typeof LOCAL_CONTRACT_ADDRESSES).WETH 
  : (CONTRACT_ADDRESSES as typeof SEPOLIA_CONTRACT_ADDRESSES).WETH;
export const MOCK_USDC = isDevelopment 
  ? (CONTRACT_ADDRESSES as typeof LOCAL_CONTRACT_ADDRESSES).USDC 
  : (CONTRACT_ADDRESSES as typeof SEPOLIA_CONTRACT_ADDRESSES).USDC;
export const MOCK_ETH = isDevelopment 
  ? (CONTRACT_ADDRESSES as typeof LOCAL_CONTRACT_ADDRESSES).ETH 
  : (CONTRACT_ADDRESSES as typeof SEPOLIA_CONTRACT_ADDRESSES).ETH;
export const NGO_REGISTRY = CONTRACT_ADDRESSES.NGO_REGISTRY;
export const VAULT = CONTRACT_ADDRESSES.VAULT;
export const ETH_VAULT = isDevelopment ? (CONTRACT_ADDRESSES as typeof LOCAL_CONTRACT_ADDRESSES).ETH_VAULT : undefined;
export const ETH_VAULT_MANAGER = isDevelopment ? (CONTRACT_ADDRESSES as typeof LOCAL_CONTRACT_ADDRESSES).ETH_VAULT_MANAGER : undefined;
export const ETH_VAULT_ADAPTER = isDevelopment ? (CONTRACT_ADDRESSES as typeof LOCAL_CONTRACT_ADDRESSES).ETH_VAULT_ADAPTER : undefined;
export const STRATEGY_MANAGER = CONTRACT_ADDRESSES.STRATEGY_MANAGER;
export const AAVE_ADAPTER = CONTRACT_ADDRESSES.AAVE_ADAPTER;
export const DONATION_ROUTER = CONTRACT_ADDRESSES.DONATION_ROUTER;
