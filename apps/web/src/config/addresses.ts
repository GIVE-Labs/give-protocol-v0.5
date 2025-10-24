/**
 * GIVE Protocol v0.5 - Contract Addresses
 * Deployed: October 24, 2025
 * Network: Base Sepolia (Chain ID: 84532)
 */

export type ProtocolAddresses = {
  // Core Protocol
  aclManager: `0x${string}`;
  giveProtocolCore: `0x${string}`;
  
  // Registries
  campaignRegistry: `0x${string}`;
  strategyRegistry: `0x${string}`;
  
  // Payout & Factory
  payoutRouter: `0x${string}`;
  campaignVaultFactory: `0x${string}`;
  
  // Vaults
  giveWethVault: `0x${string}`;
  
  // Adapters
  mockYieldAdapter?: `0x${string}`;
  aaveAdapter?: `0x${string}`;
  
  // Assets
  weth: `0x${string}`;
  usdc?: `0x${string}`;
  dai?: `0x${string}`;
};

export const ADDRESSES: Record<number, ProtocolAddresses> = {
  // Anvil (localhost)
  31337: {
    aclManager: '0x0000000000000000000000000000000000000000',
    giveProtocolCore: '0x0000000000000000000000000000000000000000',
    campaignRegistry: '0x0000000000000000000000000000000000000000',
    strategyRegistry: '0x0000000000000000000000000000000000000000',
    payoutRouter: '0x0000000000000000000000000000000000000000',
    campaignVaultFactory: '0x0000000000000000000000000000000000000000',
    giveWethVault: '0x0000000000000000000000000000000000000000',
    weth: '0x0000000000000000000000000000000000000000',
  },
  
  // Base Sepolia (DEPLOYED ✅)
  84532: {
    // Core Protocol
    aclManager: '0xC6454Ec62f53823692f426F1fb4Daa57c184A36A',
    giveProtocolCore: '0xB73B90207D6Fe0e44A090002bf4e2e9aA37564D9',
    
    // Registries
    campaignRegistry: '0x51929ec1C089463fBeF6148B86F34117D9CCF816',
    strategyRegistry: '0xA31D2D9dc6E58568B65AA3643B1076C6a48De6FC',
    
    // Payout & Factory
    payoutRouter: '0xe1BD0BA2e0891c95Bd02eA248f8115E7c7DC37c5',
    campaignVaultFactory: '0x2ff82c02775550e038787E4403687e1Fe24E2B44',
    
    // Vaults
    giveWethVault: '0x28ac6D6505E2875FFF9E13d1B788A8d4740a7278',
    
    // Adapters
    mockYieldAdapter: '0x31fAf52536FC9c4DaA224fb8AB76868DE4731A0E',
    
    // Assets
    weth: '0x4200000000000000000000000000000000000006', // Base Sepolia WETH
  },
  
  // Base Mainnet (TODO)
  8453: {
    aclManager: '0x0000000000000000000000000000000000000000',
    giveProtocolCore: '0x0000000000000000000000000000000000000000',
    campaignRegistry: '0x0000000000000000000000000000000000000000',
    strategyRegistry: '0x0000000000000000000000000000000000000000',
    payoutRouter: '0x0000000000000000000000000000000000000000',
    campaignVaultFactory: '0x0000000000000000000000000000000000000000',
    giveWethVault: '0x0000000000000000000000000000000000000000',
    weth: '0x4200000000000000000000000000000000000006', // Base Mainnet WETH
  }
};

/**
 * Get contract addresses for a specific chain
 */
export function getAddresses(chainId: number): ProtocolAddresses {
  const addresses = ADDRESSES[chainId];
  if (!addresses) {
    throw new Error(`No contract addresses configured for chain ID: ${chainId}`);
  }
  return addresses;
}

/**
 * Check if a chain is supported
 */
export function isChainSupported(chainId: number): boolean {
  return chainId in ADDRESSES;
}

/**
 * Supported chain IDs
 */
export const SUPPORTED_CHAINS = Object.keys(ADDRESSES).map(Number);

