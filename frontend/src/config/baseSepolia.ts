/**
 * Base Sepolia Testnet Configuration
 * GIVE Protocol v0.5 Deployment
 * Deployed: October 24, 2025
 */

export const BASE_SEPOLIA_ADDRESSES = {
  // ===== Core Governance =====
  ACL_MANAGER: '0xC6454Ec62f53823692f426F1fb4Daa57c184A36A',
  GIVE_PROTOCOL_CORE: '0xB73B90207D6Fe0e44A090002bf4e2e9aA37564D9',
  
  // ===== Registries =====
  CAMPAIGN_REGISTRY: '0x51929ec1C089463fBeF6148B86F34117D9CCF816',
  STRATEGY_REGISTRY: '0xA31D2D9dc6E58568B65AA3643B1076C6a48De6FC',
  
  // ===== Payout & Factory =====
  PAYOUT_ROUTER: '0xe1BD0BA2e0891c95Bd02eA248f8115E7c7DC37c5',
  CAMPAIGN_VAULT_FACTORY: '0x2ff82c02775550e038787E4403687e1Fe24E2B44',
  
  // ===== Vaults =====
  GIVE_WETH_VAULT: '0x28ac6D6505E2875FFF9E13d1B788A8d4740a7278',
  CAMPAIGN_VAULT_IMPL: '0x9db2a61a2Ea9Eb4bb52AE9c5135BB7264bD29615',
  
  // ===== Adapters =====
  MOCK_YIELD_ADAPTER: '0x31fAf52536FC9c4DaA224fb8AB76868DE4731A0E',
  
  // ===== Tokens =====
  WETH: '0x4200000000000000000000000000000000000006', // Canonical Base WETH
  
  // ===== Legacy (Deprecated - not deployed on Base Sepolia) =====
  NGO_REGISTRY: '0x0000000000000000000000000000000000000000',
  DONATION_ROUTER: '0x0000000000000000000000000000000000000000', // Replaced by PayoutRouter
  STRATEGY_MANAGER: '0x0000000000000000000000000000000000000000', // Merged into StrategyRegistry
  AAVE_ADAPTER: '0x0000000000000000000000000000000000000000', // Using MockYieldAdapter
  VAULT: '0x28ac6D6505E2875FFF9E13d1B788A8d4740a7278', // Alias to GIVE_WETH_VAULT for compatibility
} as const;

export const BASE_SEPOLIA_CONFIG = {
  chainId: 84532,
  name: 'Base Sepolia',
  rpcUrl: 'https://base-sepolia.g.alchemy.com/v2/',
  blockExplorer: 'https://sepolia.basescan.org',
  nativeCurrency: {
    name: 'Ether',
    symbol: 'ETH',
    decimals: 18,
  },
  contracts: BASE_SEPOLIA_ADDRESSES,
  testnet: true,
} as const;

// Helper to get contract addresses
export function getBaseSepoliaAddress(contract: keyof typeof BASE_SEPOLIA_ADDRESSES): `0x${string}` {
  return BASE_SEPOLIA_ADDRESSES[contract] as `0x${string}`;
}

// Helper to check if address is deployed
export function isContractDeployed(address: string): boolean {
  return address !== '0x0000000000000000000000000000000000000000';
}

// Export for external links
export const BASESCAN_URL = BASE_SEPOLIA_CONFIG.blockExplorer;
export function getBasescanLink(address: string, type: 'address' | 'tx' = 'address'): string {
  return `${BASESCAN_URL}/${type}/${address}`;
}
