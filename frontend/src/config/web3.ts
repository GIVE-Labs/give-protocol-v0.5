import { getDefaultConfig } from '@rainbow-me/rainbowkit';
import { MORPH_HOLESKY } from './contracts';

export const config = getDefaultConfig({
  appName: 'MorphImpact',
  projectId: 'YOUR_WALLETCONNECT_PROJECT_ID', // Replace with your WalletConnect Project ID
  chains: [MORPH_HOLESKY],
  ssr: false,
});