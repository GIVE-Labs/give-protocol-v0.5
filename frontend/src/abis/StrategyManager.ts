export const StrategyManagerABI = [
  {
    "inputs": [],
    "name": "harvest",
    "outputs": [
      {"internalType": "uint256", "name": "profit", "type": "uint256"},
      {"internalType": "uint256", "name": "loss", "type": "uint256"}
    ],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "rebalance",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "canRebalance",
    "outputs": [{"internalType": "bool", "name": "", "type": "bool"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "canHarvest",
    "outputs": [{"internalType": "bool", "name": "", "type": "bool"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "getActiveAdapter",
    "outputs": [{"internalType": "address", "name": "", "type": "address"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "getPerformanceMetrics",
    "outputs": [
      {"internalType": "uint256", "name": "totalProfit", "type": "uint256"},
      {"internalType": "uint256", "name": "totalLoss", "type": "uint256"},
      {"internalType": "uint256", "name": "lastHarvestTime", "type": "uint256"},
      {"internalType": "uint256", "name": "lastRebalanceTime", "type": "uint256"}
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {"internalType": "uint256", "name": "cashBufferBps", "type": "uint256"},
      {"internalType": "uint256", "name": "slippageBps", "type": "uint256"},
      {"internalType": "uint256", "name": "maxLossBps", "type": "uint256"}
    ],
    "name": "updateVaultParameters",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {"internalType": "address", "name": "router", "type": "address"}
    ],
    "name": "setDonationRouter",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {"internalType": "uint256", "name": "interval", "type": "uint256"}
    ],
    "name": "setRebalanceInterval",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {"internalType": "bool", "name": "enabled", "type": "bool"}
    ],
    "name": "setAutoRebalanceEnabled",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  // Events
  {
    "anonymous": false,
    "inputs": [
      {"indexed": false, "internalType": "uint256", "name": "profit", "type": "uint256"},
      {"indexed": false, "internalType": "uint256", "name": "loss", "type": "uint256"}
    ],
    "name": "Harvested",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [
      {"indexed": true, "internalType": "address", "name": "oldAdapter", "type": "address"},
      {"indexed": true, "internalType": "address", "name": "newAdapter", "type": "address"}
    ],
    "name": "Rebalanced",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [
      {"indexed": false, "internalType": "uint256", "name": "cashBufferBps", "type": "uint256"},
      {"indexed": false, "internalType": "uint256", "name": "slippageBps", "type": "uint256"},
      {"indexed": false, "internalType": "uint256", "name": "maxLossBps", "type": "uint256"}
    ],
    "name": "ParametersUpdated",
    "type": "event"
  }
] as const;