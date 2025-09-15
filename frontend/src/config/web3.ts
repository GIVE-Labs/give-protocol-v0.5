import { getDefaultConfig } from '@rainbow-me/rainbowkit';
import { sepolia } from 'wagmi/chains';
import { ANVIL_CHAIN } from './local';

// Use a valid WalletConnect project ID for proper wallet icon loading
const projectId = import.meta.env.VITE_WALLETCONNECT_PROJECT_ID || '';

// Determine which chains to include based on environment
const isDevelopment = import.meta.env.DEV;
const chains = isDevelopment ? [ANVIL_CHAIN, sepolia] as const : [sepolia] as const;

export const config = getDefaultConfig({
  appName: 'GIVE Protocol',
  projectId,
  chains,
  ssr: false,
});

// Export the Sepolia chain for backward compatibility
export const SEPOLIA = sepolia;
