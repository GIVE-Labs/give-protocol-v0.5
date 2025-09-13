// Contract addresses (Scroll Sepolia) - fill after deployments
export const CONTRACT_ADDRESSES = {
  // Scroll Sepolia Testnet addresses (TBD)
  NGO_REGISTRY: '0x0000000000000000000000000000000000000000',
  MOCK_YIELD_VAULT: '0x0000000000000000000000000000000000000000',
  MORPH_IMPACT_STAKING: '0x0000000000000000000000000000000000000000',
  YIELD_DISTRIBUTOR: '0x0000000000000000000000000000000000000000',

  // Token addresses for Scroll Sepolia (TBD or mocks)
  TOKENS: {
    ETH: '0x0000000000000000000000000000000000000000', // Native ETH placeholder
    USDC: '0x0000000000000000000000000000000000000000',
    WETH: '0x0000000000000000000000000000000000000000',
  }
} as const;

// Export individual token addresses for convenience
export const MOCK_WETH = CONTRACT_ADDRESSES.TOKENS.WETH;
export const MOCK_USDC = CONTRACT_ADDRESSES.TOKENS.USDC;
export const MORPH_IMPACT_STAKING = CONTRACT_ADDRESSES.MORPH_IMPACT_STAKING;
export const NGO_REGISTRY = CONTRACT_ADDRESSES.NGO_REGISTRY;
export const YIELD_DISTRIBUTOR = CONTRACT_ADDRESSES.YIELD_DISTRIBUTOR;

// Chain configuration
export const SCROLL_SEPOLIA = {
  id: 534351,
  name: 'Scroll Sepolia',
  nativeCurrency: {
    name: 'ETH',
    symbol: 'ETH',
    decimals: 18,
  },
  rpcUrls: {
    default: { http: [import.meta.env.VITE_SCROLL_SEPOLIA_RPC || 'https://sepolia-rpc.scroll.io'] },
  },
  blockExplorers: {
    default: { name: 'Scroll Sepolia Explorer', url: 'https://sepolia.scrollscan.com' },
  },
  testnet: true,
} as const;
