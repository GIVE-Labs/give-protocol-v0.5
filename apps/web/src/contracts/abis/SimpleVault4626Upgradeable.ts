export const SimpleVault4626UpgradeableAbi = [
  // Views
  { "type": "function", "name": "asset", "stateMutability": "view", "inputs": [], "outputs": [{ "name": "", "type": "address" }] },
  { "type": "function", "name": "name", "stateMutability": "view", "inputs": [], "outputs": [{ "name": "", "type": "string" }] },
  { "type": "function", "name": "symbol", "stateMutability": "view", "inputs": [], "outputs": [{ "name": "", "type": "string" }] },
  { "type": "function", "name": "decimals", "stateMutability": "view", "inputs": [], "outputs": [{ "name": "", "type": "uint8" }] },
  { "type": "function", "name": "totalAssets", "stateMutability": "view", "inputs": [], "outputs": [{ "name": "", "type": "uint256" }] },
  { "type": "function", "name": "totalSupply", "stateMutability": "view", "inputs": [], "outputs": [{ "name": "", "type": "uint256" }] },
  { "type": "function", "name": "donationPercentBps", "stateMutability": "view", "inputs": [], "outputs": [{ "name": "", "type": "uint16" }] },
  { "type": "function", "name": "protocolFeeBps", "stateMutability": "view", "inputs": [], "outputs": [{ "name": "", "type": "uint16" }] },
  { "type": "function", "name": "currentNGO", "stateMutability": "view", "inputs": [], "outputs": [{ "name": "", "type": "address" }] },
  { "type": "function", "name": "maxDeposit", "stateMutability": "view", "inputs": [{ "name": "", "type": "address" }], "outputs": [{ "name": "", "type": "uint256" }] },
  { "type": "function", "name": "convertToShares", "stateMutability": "view", "inputs": [{ "name": "assets", "type": "uint256" }], "outputs": [{ "name": "", "type": "uint256" }] },
  { "type": "function", "name": "convertToAssets", "stateMutability": "view", "inputs": [{ "name": "shares", "type": "uint256" }], "outputs": [{ "name": "", "type": "uint256" }] },
  { "type": "function", "name": "balanceOf", "stateMutability": "view", "inputs": [{ "name": "", "type": "address" }], "outputs": [{ "name": "", "type": "uint256" }] },

  // Mutations
  { "type": "function", "name": "deposit", "stateMutability": "nonpayable", "inputs": [{ "name": "assets", "type": "uint256" }, { "name": "receiver", "type": "address" }], "outputs": [{ "name": "", "type": "uint256" }] },
  { "type": "function", "name": "mint", "stateMutability": "nonpayable", "inputs": [{ "name": "shares", "type": "uint256" }, { "name": "receiver", "type": "address" }], "outputs": [{ "name": "", "type": "uint256" }] },
  { "type": "function", "name": "withdraw", "stateMutability": "nonpayable", "inputs": [
    { "name": "assets", "type": "uint256" },
    { "name": "receiver", "type": "address" },
    { "name": "owner", "type": "address" }
  ], "outputs": [{ "name": "", "type": "uint256" }] },
  { "type": "function", "name": "redeem", "stateMutability": "nonpayable", "inputs": [
    { "name": "shares", "type": "uint256" },
    { "name": "receiver", "type": "address" },
    { "name": "owner", "type": "address" }
  ], "outputs": [{ "name": "", "type": "uint256" }] },
  { "type": "function", "name": "harvest", "stateMutability": "nonpayable", "inputs": [{ "name": "ngo", "type": "address" }], "outputs": [] }
];

export const ERC20Abi = [
  { "type": "function", "name": "decimals", "stateMutability": "view", "inputs": [], "outputs": [{ "type": "uint8" }] },
  { "type": "function", "name": "symbol", "stateMutability": "view", "inputs": [], "outputs": [{ "type": "string" }] },
  { "type": "function", "name": "balanceOf", "stateMutability": "view", "inputs": [{ "type": "address" }], "outputs": [{ "type": "uint256" }] },
  { "type": "function", "name": "allowance", "stateMutability": "view", "inputs": [{ "type": "address" }, { "type": "address" }], "outputs": [{ "type": "uint256" }] },
  { "type": "function", "name": "approve", "stateMutability": "nonpayable", "inputs": [{ "type": "address" }, { "type": "uint256" }], "outputs": [{ "type": "bool" }] }
];

