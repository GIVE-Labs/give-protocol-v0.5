// Sepolia Testnet configuration
import { sepolia } from 'viem/chains';

// Real Sepolia addresses for tokens and protocols
export const SEPOLIA_TOKEN_ADDRESSES = {
  // Native ETH
  ETH: '0x0000000000000000000000000000000000000000',
  
  // Sepolia WETH (Aave compatible)
  WETH: '0xC558DBdd856501FCd9aaF1E62eae57A9F0629a3c',
  
  // Sepolia USDC (Aave compatible)
  USDC: '0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8',
  
  // Mock WBTC for Sepolia
  WBTC: '0x29f2D40B0605204364af54EC677bD022dA425d03',
} as const;

// Sepolia protocol addresses
export const SEPOLIA_PROTOCOL_ADDRESSES = {
  // Aave Sepolia Pool
  AAVE_POOL: '0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951',
  
  // Chainlink Price Feeds
  ETH_USD_PRICE_FEED: '0x694AA1769357215DE4FAC081bf1f309aDC325306',
  BTC_USD_PRICE_FEED: '0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43',
} as const;

// Contract addresses from deployment (updated September 18, 2025)
export const SEPOLIA_CONTRACT_ADDRESSES = {
  // Core contracts (USDC Vault deployment)
  VAULT: '0x9816de1f27c15AAe597548f09E2188d16752C4C8', // GIVE Vault USDC
  ETH_VAULT: '', // Update after deploying ETH vault
  STRATEGY_MANAGER: '0x42cB507dfe0f7D8a01c9ad9e1b18B84CCf0A41B9', // StrategyManager
  ETH_VAULT_MANAGER: '', // Update after deployment
  AAVE_ADAPTER: '0xFc03875B2B2a84D9D1Bd24E41281fF371b3A1948', // AaveAdapter
  ETH_VAULT_ADAPTER: '', // Update after deployment
  NGO_REGISTRY: '0x77182f2C8E86233D3B0095446Da20ecDecF96Cc2', // NGORegistry
  DONATION_ROUTER: '0x33952be800FbBc7f8198A0efD489204720f64A4C', // DonationRouter
  
  // Token addresses
  ...SEPOLIA_TOKEN_ADDRESSES,
} as const;

// Sepolia chain configuration
export const SEPOLIA_CHAIN = {
  ...sepolia,
  rpcUrls: {
    default: { 
      http: [
        'https://ethereum-sepolia-rpc.publicnode.com',
        'https://sepolia.infura.io/v3/YOUR_INFURA_KEY', // Replace with your Infura key
        'https://eth-sepolia.g.alchemy.com/v2/YOUR_ALCHEMY_KEY' // Replace with your Alchemy key
      ] 
    },
  },
  blockExplorers: {
    default: { name: 'Etherscan', url: 'https://sepolia.etherscan.io' },
  },
} as const;

// Export individual addresses for convenience
export const {
  VAULT: SEPOLIA_VAULT,
  ETH_VAULT: SEPOLIA_ETH_VAULT,
  STRATEGY_MANAGER: SEPOLIA_STRATEGY_MANAGER,
  ETH_VAULT_MANAGER: SEPOLIA_ETH_VAULT_MANAGER,
  AAVE_ADAPTER: SEPOLIA_AAVE_ADAPTER,
  ETH_VAULT_ADAPTER: SEPOLIA_ETH_VAULT_ADAPTER,
  NGO_REGISTRY: SEPOLIA_NGO_REGISTRY,
  DONATION_ROUTER: SEPOLIA_DONATION_ROUTER,
  ETH: SEPOLIA_ETH,
  WETH: SEPOLIA_WETH,
  USDC: SEPOLIA_USDC,
  WBTC: SEPOLIA_WBTC,
} = SEPOLIA_CONTRACT_ADDRESSES;