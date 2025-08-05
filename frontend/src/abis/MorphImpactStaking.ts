export const MORPH_IMPACT_STAKING_ABI = [
  {
    "type": "constructor",
    "inputs": [
      { "name": "_ngoRegistry", "type": "address", "internalType": "address" },
      { "name": "_yieldVault", "type": "address", "internalType": "address" }
    ],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "stake",
    "inputs": [
      { "name": "_ngo", "type": "address", "internalType": "address" },
      { "name": "_token", "type": "address", "internalType": "address" },
      { "name": "_amount", "type": "uint256", "internalType": "uint256" },
      { "name": "_lockPeriod", "type": "uint256", "internalType": "uint256" },
      { "name": "_yieldContributionRate", "type": "uint256", "internalType": "uint256" }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "unstake",
    "inputs": [
      { "name": "_ngo", "type": "address", "internalType": "address" },
      { "name": "_token", "type": "address", "internalType": "address" },
      { "name": "_amount", "type": "uint256", "internalType": "uint256" }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "claimYield",
    "inputs": [
      { "name": "_ngo", "type": "address", "internalType": "address" },
      { "name": "_token", "type": "address", "internalType": "address" }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "getUserStake",
    "inputs": [
      { "name": "_user", "type": "address", "internalType": "address" },
      { "name": "_ngo", "type": "address", "internalType": "address" },
      { "name": "_token", "type": "address", "internalType": "address" }
    ],
    "outputs": [
      {
        "name": "",
        "type": "tuple",
        "internalType": "struct MorphImpactStaking.StakeInfo",
        "components": [
          { "name": "amount", "type": "uint256", "internalType": "uint256" },
          { "name": "lockUntil", "type": "uint256", "internalType": "uint256" },
          { "name": "yieldContributionRate", "type": "uint256", "internalType": "uint256" },
          { "name": "totalYieldGenerated", "type": "uint256", "internalType": "uint256" },
          { "name": "totalYieldToNGO", "type": "uint256", "internalType": "uint256" },
          { "name": "isActive", "type": "bool", "internalType": "bool" },
          { "name": "stakeTime", "type": "uint256", "internalType": "uint256" },
          { "name": "lastYieldUpdate", "type": "uint256", "internalType": "uint256" }
        ]
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getUserStakedNGOs",
    "inputs": [
      { "name": "_user", "type": "address", "internalType": "address" },
      { "name": "_token", "type": "address", "internalType": "address" }
    ],
    "outputs": [{ "name": "", "type": "address[]", "internalType": "address[]" }],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getTotalStakedForNGO",
    "inputs": [
      { "name": "_ngo", "type": "address", "internalType": "address" },
      { "name": "_token", "type": "address", "internalType": "address" }
    ],
    "outputs": [{ "name": "", "type": "uint256", "internalType": "uint256" }],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getPendingYield",
    "inputs": [
      { "name": "_user", "type": "address", "internalType": "address" },
      { "name": "_ngo", "type": "address", "internalType": "address" },
      { "name": "_token", "type": "address", "internalType": "address" }
    ],
    "outputs": [
      { "name": "pendingYield", "type": "uint256", "internalType": "uint256" },
      { "name": "yieldToUser", "type": "uint256", "internalType": "uint256" },
      { "name": "yieldToNGO", "type": "uint256", "internalType": "uint256" }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "isSupportedToken",
    "inputs": [{ "name": "", "type": "address", "internalType": "address" }],
    "outputs": [{ "name": "", "type": "bool", "internalType": "bool" }],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getSupportedTokens",
    "inputs": [],
    "outputs": [{ "name": "", "type": "address[]", "internalType": "address[]" }],
    "stateMutability": "view"
  }
] as const;