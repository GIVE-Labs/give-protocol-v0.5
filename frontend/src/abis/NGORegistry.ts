export const NGO_REGISTRY_ABI = [
  {
    "type": "constructor",
    "inputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "NGO_ROLE",
    "inputs": [],
    "outputs": [{ "name": "", "type": "bytes32", "internalType": "bytes32" }],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "VERIFIER_ROLE",
    "inputs": [],
    "outputs": [{ "name": "", "type": "bytes32", "internalType": "bytes32" }],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getAllNGOs",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "tuple[]",
        "internalType": "struct NGORegistry.NGOInfo[]",
        "components": [
          { "name": "ngoAddress", "type": "address", "internalType": "address" },
          { "name": "name", "type": "string", "internalType": "string" },
          { "name": "description", "type": "string", "internalType": "string" },
          { "name": "website", "type": "string", "internalType": "string" },
          { "name": "logoURI", "type": "string", "internalType": "string" },
          { "name": "walletAddress", "type": "address", "internalType": "address" },
          { "name": "causes", "type": "string[]", "internalType": "string[]" },
          { "name": "metadataURI", "type": "string", "internalType": "string" },
          { "name": "isVerified", "type": "bool", "internalType": "bool" },
          { "name": "reputationScore", "type": "uint256", "internalType": "uint256" },
          { "name": "totalStakers", "type": "uint256", "internalType": "uint256" },
          { "name": "totalYieldReceived", "type": "uint256", "internalType": "uint256" }
        ]
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getNGO",
    "inputs": [{ "name": "_ngo", "type": "address", "internalType": "address" }],
    "outputs": [
      {
        "name": "",
        "type": "tuple",
        "internalType": "struct NGORegistry.NGOInfo",
        "components": [
          { "name": "ngoAddress", "type": "address", "internalType": "address" },
          { "name": "name", "type": "string", "internalType": "string" },
          { "name": "description", "type": "string", "internalType": "string" },
          { "name": "website", "type": "string", "internalType": "string" },
          { "name": "logoURI", "type": "string", "internalType": "string" },
          { "name": "walletAddress", "type": "address", "internalType": "address" },
          { "name": "causes", "type": "string[]", "internalType": "string[]" },
          { "name": "metadataURI", "type": "string", "internalType": "string" },
          { "name": "isVerified", "type": "bool", "internalType": "bool" },
          { "name": "reputationScore", "type": "uint256", "internalType": "uint256" },
          { "name": "totalStakers", "type": "uint256", "internalType": "uint256" },
          { "name": "totalYieldReceived", "type": "uint256", "internalType": "uint256" }
        ]
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getNGOsByVerification",
    "inputs": [{ "name": "_verified", "type": "bool", "internalType": "bool" }],
    "outputs": [{ "name": "", "type": "address[]", "internalType": "address[]" }],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "isVerifiedAndActive",
    "inputs": [{ "name": "_ngo", "type": "address", "internalType": "address" }],
    "outputs": [{ "name": "", "type": "bool", "internalType": "bool" }],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "registerNGO",
    "inputs": [
      { "name": "_name", "type": "string", "internalType": "string" },
      { "name": "_description", "type": "string", "internalType": "string" },
      { "name": "_website", "type": "string", "internalType": "string" },
      { "name": "_logoURI", "type": "string", "internalType": "string" },
      { "name": "_walletAddress", "type": "address", "internalType": "address" },
      { "name": "_causes", "type": "string[]", "internalType": "string[]" },
      { "name": "_metadataURI", "type": "string", "internalType": "string" }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "verifyNGO",
    "inputs": [{ "name": "_ngo", "type": "address", "internalType": "address" }],
    "outputs": [],
    "stateMutability": "nonpayable"
  }
] as const;