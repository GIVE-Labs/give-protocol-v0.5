import { getDefaultConfig } from '@rainbow-me/rainbowkit';
import { sepolia, baseSepolia } from 'wagmi/chains';
import { ANVIL_CHAIN } from './local';

// Use a valid WalletConnect project ID for proper wallet icon loading
const projectId = import.meta.env.VITE_WALLETCONNECT_PROJECT_ID || '';

// Determine which chains to include based on environment
const useBaseSepolia = import.meta.env.VITE_USE_BASE_SEPOLIA !== 'false'; // Default to Base Sepolia

// Chain priority: Base Sepolia (default) > Sepolia > Anvil (only if explicitly enabled)
const useAnvil = import.meta.env.VITE_USE_ANVIL === 'true'; // Explicitly opt-in to Anvil

const chains = useAnvil
  ? [ANVIL_CHAIN, baseSepolia, sepolia] as const
  : useBaseSepolia
    ? [baseSepolia, sepolia] as const
    : [sepolia, baseSepolia] as const;

export const config = getDefaultConfig({
  appName: 'GIVE Protocol',
  projectId,
  chains,
  ssr: false,
});

// Export chains for direct reference
export const SEPOLIA = sepolia;
export const BASE_SEPOLIA = baseSepolia;
