// Contract addresses (Sepolia) - deployed addresses
export const CONTRACT_ADDRESSES = {
  // Deployed contract addresses
  NGO_REGISTRY: '0x36Fb53A3d29d1822ec0bA73ae4658185C725F5CC',
  VAULT: '0x2b67de726Fc1Fdc1AE1d34aa89e1d1152C11fA52',
  STRATEGY_MANAGER: '0x4aE8717F12b1618Ff68c7de430E53735c4e48F1d',
  AAVE_ADAPTER: '0x8c6824E4d86fBF849157035407B2418F5f992dB7',
  DONATION_ROUTER: '0x2F86620b005b4Bc215ebeB5d8A9eDfE7eC4Ccfb7',


  // Token addresses for Sepolia
  TOKENS: {
    ETH: '0x0000000000000000000000000000000000000000', // Native ETH placeholder
    USDC: '0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8',
    WETH: '0xC558DBdd856501FCd9aaF1E62eae57A9F0629a3c',
  }
} as const;

// Export individual contract addresses for convenience
export const MOCK_WETH = CONTRACT_ADDRESSES.TOKENS.WETH;
export const MOCK_USDC = CONTRACT_ADDRESSES.TOKENS.USDC;
export const NGO_REGISTRY = CONTRACT_ADDRESSES.NGO_REGISTRY;
export const VAULT = CONTRACT_ADDRESSES.VAULT;
export const STRATEGY_MANAGER = CONTRACT_ADDRESSES.STRATEGY_MANAGER;
export const AAVE_ADAPTER = CONTRACT_ADDRESSES.AAVE_ADAPTER;
export const DONATION_ROUTER = CONTRACT_ADDRESSES.DONATION_ROUTER;


// Chain configuration
export const SEPOLIA = {
  id: 11155111,
  name: 'Sepolia',
  nativeCurrency: {
    name: 'ETH',
    symbol: 'ETH',
    decimals: 18,
  },
  rpcUrls: {
    default: { http: [import.meta.env.VITE_SEPOLIA_RPC || 'https://rpc.sepolia.org'] },
  },
  blockExplorers: {
    default: { name: 'Sepolia Explorer', url: 'https://sepolia.etherscan.io' },
  },
  testnet: true,
} as const;
