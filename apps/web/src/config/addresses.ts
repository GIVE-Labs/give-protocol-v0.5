export type VaultAddresses = {
  vault50?: `0x${string}`;
  vault75?: `0x${string}`;
  vault100?: `0x${string}`;
  ngoRegistry?: `0x${string}`;
  donationPayer?: `0x${string}`;
  treasury?: `0x${string}`;
};

export const ADDRESSES: Record<number, VaultAddresses> = {
  // Anvil (localhost)
  31337: {
    vault50: process.env.NEXT_PUBLIC_VAULT50_31337 as `0x${string}` | undefined,
    vault75: process.env.NEXT_PUBLIC_VAULT75_31337 as `0x${string}` | undefined,
    vault100: process.env.NEXT_PUBLIC_VAULT100_31337 as `0x${string}` | undefined,
    ngoRegistry: process.env.NEXT_PUBLIC_NGOREGISTRY_31337 as `0x${string}` | undefined,
    donationPayer: process.env.NEXT_PUBLIC_DONATION_PAYER_31337 as `0x${string}` | undefined,
    treasury: process.env.NEXT_PUBLIC_TREASURY_31337 as `0x${string}` | undefined
  },
  // Base Sepolia
  84532: {
    vault50: process.env.NEXT_PUBLIC_VAULT50_84532 as `0x${string}` | undefined,
    vault75: process.env.NEXT_PUBLIC_VAULT75_84532 as `0x${string}` | undefined,
    vault100: process.env.NEXT_PUBLIC_VAULT100_84532 as `0x${string}` | undefined,
    ngoRegistry: process.env.NEXT_PUBLIC_NGOREGISTRY_84532 as `0x${string}` | undefined,
    donationPayer: process.env.NEXT_PUBLIC_DONATION_PAYER_84532 as `0x${string}` | undefined,
    treasury: process.env.NEXT_PUBLIC_TREASURY_84532 as `0x${string}` | undefined
  },
  // Base mainnet
  8453: {
    vault50: process.env.NEXT_PUBLIC_VAULT50_8453 as `0x${string}` | undefined,
    vault75: process.env.NEXT_PUBLIC_VAULT75_8453 as `0x${string}` | undefined,
    vault100: process.env.NEXT_PUBLIC_VAULT100_8453 as `0x${string}` | undefined,
    ngoRegistry: process.env.NEXT_PUBLIC_NGOREGISTRY_8453 as `0x${string}` | undefined,
    donationPayer: process.env.NEXT_PUBLIC_DONATION_PAYER_8453 as `0x${string}` | undefined,
    treasury: process.env.NEXT_PUBLIC_TREASURY_8453 as `0x${string}` | undefined
  }
};

