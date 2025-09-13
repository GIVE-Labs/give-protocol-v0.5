export const DonationRouterABI = [
  {
    "inputs": [
      {"internalType": "address", "name": "asset", "type": "address"},
      {"internalType": "uint256", "name": "amount", "type": "uint256"}
    ],
    "name": "distribute",
    "outputs": [
      {"internalType": "uint256", "name": "donated", "type": "uint256"},
      {"internalType": "uint256", "name": "fee", "type": "uint256"}
    ],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {"internalType": "address", "name": "asset", "type": "address"}
    ],
    "name": "getDistributionStats",
    "outputs": [
      {"internalType": "uint256", "name": "totalDonatedAmount", "type": "uint256"},
      {"internalType": "uint256", "name": "totalFeesCollected", "type": "uint256"},
      {"internalType": "address", "name": "currentNGO", "type": "address"},
      {"internalType": "uint256", "name": "currentFeeBps", "type": "uint256"}
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {"internalType": "uint256", "name": "amount", "type": "uint256"}
    ],
    "name": "calculateDistribution",
    "outputs": [
      {"internalType": "uint256", "name": "netDonation", "type": "uint256"},
      {"internalType": "uint256", "name": "feeAmount", "type": "uint256"}
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {"internalType": "address", "name": "caller", "type": "address"}
    ],
    "name": "isAuthorizedCaller",
    "outputs": [{"internalType": "bool", "name": "", "type": "bool"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "getFeeConfig",
    "outputs": [
      {"internalType": "address", "name": "recipient", "type": "address"},
      {"internalType": "uint256", "name": "bps", "type": "uint256"},
      {"internalType": "uint256", "name": "maxBps", "type": "uint256"}
    ],
    "stateMutability": "view",
    "type": "function"
  },
  // Events
  {
    "anonymous": false,
    "inputs": [
      {"indexed": true, "internalType": "address", "name": "asset", "type": "address"},
      {"indexed": true, "internalType": "address", "name": "ngo", "type": "address"},
      {"indexed": false, "internalType": "uint256", "name": "amount", "type": "uint256"},
      {"indexed": false, "internalType": "uint256", "name": "fee", "type": "uint256"}
    ],
    "name": "DonationDistributed",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [
      {"indexed": true, "internalType": "address", "name": "oldRecipient", "type": "address"},
      {"indexed": true, "internalType": "address", "name": "newRecipient", "type": "address"}
    ],
    "name": "FeeRecipientUpdated",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [
      {"indexed": false, "internalType": "uint256", "name": "oldBps", "type": "uint256"},
      {"indexed": false, "internalType": "uint256", "name": "newBps", "type": "uint256"}
    ],
    "name": "FeeUpdated",
    "type": "event"
  }
] as const;