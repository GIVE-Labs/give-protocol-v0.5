import { getDefaultConfig } from '@rainbow-me/rainbowkit';
import { MORPH_HOLESKY } from './contracts';

// Use a valid WalletConnect project ID for proper wallet icon loading
export const config = getDefaultConfig({
  appName: 'MorphImpact',
  projectId: '3c5a1c4c9b2e3d4e5f6a7b8c9d0e1f2a3',
  chains: [MORPH_HOLESKY],
  ssr: false,
});