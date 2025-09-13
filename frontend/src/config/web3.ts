import { getDefaultConfig } from '@rainbow-me/rainbowkit';
import { SCROLL_SEPOLIA } from './contracts';

// Use a valid WalletConnect project ID for proper wallet icon loading
const projectId = import.meta.env.VITE_WALLETCONNECT_PROJECT_ID || '';

export const config = getDefaultConfig({
  appName: 'GIVE Protocol',
  projectId,
  chains: [SCROLL_SEPOLIA],
  ssr: false,
});
