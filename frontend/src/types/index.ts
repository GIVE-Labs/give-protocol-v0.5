export interface TokenInfo {
  address: string;
  symbol: string;
  decimals: number;
  name: string;
}

// Campaign types for v0.5
export interface Campaign {
  id: bigint;
  name: string;
  recipient: string;
  metadataHash: string;
  status: number; // 0=Pending, 1=Active, 2=Paused, 3=Completed
  totalReceived: bigint;
  checkpointCount: bigint;
}
