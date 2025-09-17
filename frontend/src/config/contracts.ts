import { LOCAL_CONTRACT_ADDRESSES } from './local';

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
    contracts: {
      // Deployed contract addresses
      NGO_REGISTRY: '0xeFBC3D84420D848A8b6F5FD614E5740279D834Fa',
      VAULT: '0x330EC5985f4a8A03ac148a4fa12d4c45120e73bB',
      STRATEGY_MANAGER: '0xDd7800b4871816Ccc4E185A101055Ea47a73b32d',
      AAVE_ADAPTER: '0x284Ac57242f5657Cb2E45157D80068639EBac026',
      DONATION_ROUTER: '0xcA3826a36f1B82121c18F35d218e7163aFF904a4',

      // Token addresses for Sepolia
      TOKENS: {
        ETH: '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2', // Native ETH placeholder
        USDC: '0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8',
        WETH: '0xC558DBdd856501FCd9aaF1E62eae57A9F0629a3c',
      }
    }
  }
} as const;

// Contract addresses (Sepolia) - deployed addresses
const SEPOLIA_CONTRACT_ADDRESSES = NETWORK_CONFIG.SEPOLIA.contracts;

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
  : (CONTRACT_ADDRESSES as typeof SEPOLIA_CONTRACT_ADDRESSES).TOKENS.WETH;
export const MOCK_USDC = isDevelopment 
  ? (CONTRACT_ADDRESSES as typeof LOCAL_CONTRACT_ADDRESSES).USDC 
  : (CONTRACT_ADDRESSES as typeof SEPOLIA_CONTRACT_ADDRESSES).TOKENS.USDC;
export const MOCK_ETH = isDevelopment 
  ? (CONTRACT_ADDRESSES as typeof LOCAL_CONTRACT_ADDRESSES).ETH 
  : (CONTRACT_ADDRESSES as typeof SEPOLIA_CONTRACT_ADDRESSES).TOKENS.ETH;
export const NGO_REGISTRY = CONTRACT_ADDRESSES.NGO_REGISTRY;
export const VAULT = CONTRACT_ADDRESSES.VAULT;
export const ETH_VAULT = isDevelopment ? (CONTRACT_ADDRESSES as typeof LOCAL_CONTRACT_ADDRESSES).ETH_VAULT : undefined;
export const ETH_VAULT_MANAGER = isDevelopment ? (CONTRACT_ADDRESSES as typeof LOCAL_CONTRACT_ADDRESSES).ETH_VAULT_MANAGER : undefined;
export const ETH_VAULT_ADAPTER = isDevelopment ? (CONTRACT_ADDRESSES as typeof LOCAL_CONTRACT_ADDRESSES).ETH_VAULT_ADAPTER : undefined;
export const STRATEGY_MANAGER = CONTRACT_ADDRESSES.STRATEGY_MANAGER;
export const AAVE_ADAPTER = CONTRACT_ADDRESSES.AAVE_ADAPTER;
export const DONATION_ROUTER = CONTRACT_ADDRESSES.DONATION_ROUTER;
