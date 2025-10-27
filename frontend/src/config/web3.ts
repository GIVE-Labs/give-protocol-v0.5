import { getDefaultConfig } from '@rainbow-me/rainbowkit';
import { sepolia, baseSepolia } from 'wagmi/chains';
import { http } from 'wagmi';
import { ANVIL_CHAIN } from './local';

// Use a valid WalletConnect project ID for proper wallet icon loading
const projectId = import.meta.env.VITE_WALLETCONNECT_PROJECT_ID || '';

// Custom RPC URLs from environment
const baseSepoliaRpcUrl = import.meta.env.VITE_BASE_SEPOLIA_RPC_URL || 'https://sepolia.base.org';

// Determine which chains to include based on environment
const useBaseSepolia = import.meta.env.VITE_USE_BASE_SEPOLIA !== 'false'; // Default to Base Sepolia

// Chain priority: Base Sepolia (default) > Sepolia > Anvil (only if explicitly enabled)
const useAnvil = import.meta.env.VITE_USE_ANVIL === 'true'; // Explicitly opt-in to Anvil

const chains = useAnvil
  ? [ANVIL_CHAIN, baseSepolia, sepolia] as const
  : useBaseSepolia
    ? [baseSepolia, sepolia] as const
    : [sepolia, baseSepolia] as const;

// Build transports object - explicitly typed for each scenario
const transports = (() => {
  const baseTransports = {
    [baseSepolia.id]: http(baseSepoliaRpcUrl),
    [sepolia.id]: http(),
  };
  
  if (useAnvil) {
    return {
      ...baseTransports,
      [ANVIL_CHAIN.id]: http(),
    };
  }
  
  return baseTransports;
})();

export const config = getDefaultConfig({
  appName: 'GIVE Protocol',
  projectId,
  chains,
  transports: transports as any, // Type assertion needed due to wagmi's strict typing
  ssr: false,
});

// Export chains for direct reference
export const SEPOLIA = sepolia;
export const BASE_SEPOLIA = baseSepolia;
