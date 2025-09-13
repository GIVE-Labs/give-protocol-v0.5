export const AaveAdapterABI = [
  {
    "inputs": [],
    "name": "asset",
    "outputs": [{"internalType": "contract IERC20", "name": "", "type": "address"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "vault",
    "outputs": [{"internalType": "address", "name": "", "type": "address"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "totalAssets",
    "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {"internalType": "uint256", "name": "assets", "type": "uint256"}
    ],
    "name": "invest",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {"internalType": "uint256", "name": "assets", "type": "uint256"}
    ],
    "name": "divest",
    "outputs": [{"internalType": "uint256", "name": "returned", "type": "uint256"}],
    "stateMutability": "nonpayable",
    "type": "function"
  },
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
    "name": "emergencyWithdraw",
    "outputs": [{"internalType": "uint256", "name": "returned", "type": "uint256"}],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "totalInvested",
    "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "totalHarvested",
    "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "lastHarvestTime",
    "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "cumulativeYield",
    "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "maxSlippageBps",
    "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "emergencyExitBps",
    "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "emergencyMode",
    "outputs": [{"internalType": "bool", "name": "", "type": "bool"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {"internalType": "uint256", "name": "_bps", "type": "uint256"}
    ],
    "name": "setMaxSlippageBps",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {"internalType": "uint256", "name": "_bps", "type": "uint256"}
    ],
    "name": "setEmergencyExitBps",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  // Events
  {
    "anonymous": false,
    "inputs": [
      {"indexed": false, "internalType": "uint256", "name": "assets", "type": "uint256"}
    ],
    "name": "Invested",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [
      {"indexed": false, "internalType": "uint256", "name": "requested", "type": "uint256"},
      {"indexed": false, "internalType": "uint256", "name": "returned", "type": "uint256"}
    ],
    "name": "Divested",
    "type": "event"
  },
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
      {"indexed": false, "internalType": "uint256", "name": "returned", "type": "uint256"}
    ],
    "name": "EmergencyWithdraw",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [
      {"indexed": false, "internalType": "uint256", "name": "amount", "type": "uint256"},
      {"indexed": false, "internalType": "uint256", "name": "newBalance", "type": "uint256"}
    ],
    "name": "YieldAccrued",
    "type": "event"
  }
] as const;