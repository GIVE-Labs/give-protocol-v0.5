// Contract addresses - Updated with deployed contracts
export const CONTRACT_ADDRESSES = {
  // Morph Holesky Testnet addresses
  NGO_REGISTRY: '0x724dc0c1AE0d8559C48D0325Ff4cC8F45FE703De',
  MOCK_YIELD_VAULT: '0x13991842a2fB1139274A181c4e07210252B5D559',
  MORPH_IMPACT_STAKING: '0xE05473424Df537c9934748890d3D8A5b549da1C0',
  YIELD_DISTRIBUTOR: '0x26C19066b8492D642aDBaFD3C24f104fCeb14DA9',
  
  // Token addresses for Morph Holesky Testnet
  TOKENS: {
    ETH: '0x0000000000000000000000000000000000000000', // Native ETH
    USDC: '0x44F38B49ddaAE53751BEEb32Eb3b958d950B26e6', // MockUSDC
    WETH: '0x81F5c69b5312aD339144489f2ea5129523437bdC', // MockWETH
  }
} as const;

// Chain configuration
export const MORPH_HOLESKY = {
  id: 2810,
  name: 'Morph Holesky',
  nativeCurrency: {
    name: 'ETH',
    symbol: 'ETH',
    decimals: 18,
  },
  rpcUrls: {
    default: { http: ['https://rpc-holesky.morphl2.io'] },
  },
  blockExplorers: {
    default: { name: 'Morph Holesky Explorer', url: 'https://explorer-holesky.morphl2.io' },
  },
  testnet: true,
} as const;