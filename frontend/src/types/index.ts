export interface NGO {
  ngoAddress: string;
  name: string;
  description: string;
  website: string;
  logoURI: string;
  walletAddress: string;
  causes: string[];
  metadataURI: string;
  isVerified: boolean;
  reputationScore: bigint;
  totalStakers: bigint;
  totalYieldReceived: bigint;
}

export interface StakeInfo {
  amount: bigint;
  lockUntil: bigint;
  yieldContributionRate: bigint;
  totalYieldGenerated: bigint;
  totalYieldToNGO: bigint;
  isActive: boolean;
  stakeTime: bigint;
  lastYieldUpdate: bigint;
}

export interface PendingYield {
  pendingYield: bigint;
  yieldToUser: bigint;
  yieldToNGO: bigint;
}

export interface StakeData {
  ngoAddress: string;
  stakeInfo: StakeInfo;
  pendingYield: PendingYield;
}

export interface TokenInfo {
  address: string;
  symbol: string;
  decimals: number;
  name: string;
}