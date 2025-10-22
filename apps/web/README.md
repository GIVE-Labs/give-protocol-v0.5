# GIVE Protocol — Dapp (MVP)

A simple, professional Next.js + Wagmi + RainbowKit frontend for the three fixed-split GIVE ERC-4626 vaults.

Features
- Connect wallet via RainbowKit (Reown/WalletConnect Cloud)
- Supports Anvil (31337), Base Sepolia (84532), Base Mainnet (8453)
- Shows vault TVL, share price, split and fee, current NGO
- Deposit with ERC20 approval flow; Withdraw; Permissionless Harvest
- Environment-driven addresses per chain

Prereqs
- Node.js LTS and pnpm or npm
- Reown Cloud Project ID (formerly WalletConnect Cloud)

Setup
1) Copy env and fill addresses:
   cp .env.local.example .env.local
2) Set NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID from https://cloud.reown.com/
3) Fill contract addresses per chain for your deployments.

Dev
- pnpm i
- pnpm dev

Addresses
- Anvil/local: deploy your contracts with Foundry and paste addresses
- Base Sepolia/Mainnet: paste your deployed proxies (vaults x3, registry, payer, treasury)

Notes
- The harvest button calls vault.harvest(currentNGO) and will revert if currentNGO not set or not allowed.
- Deposits are disabled when the vault’s harvest window is open or deposits are paused by guardian; maxDeposit enforces cap.

Directory
- app/: App Router pages
- src/components/: UI components (vaults)
- src/config/: chain + address config
- src/contracts/abis/: minimal ABIs for reads/writes

