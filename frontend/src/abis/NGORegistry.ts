export const NGO_REGISTRY_ABI = [
  {
    type: 'function',
    name: 'addNGO',
    inputs: [
      { name: 'ngo', type: 'address' },
      { name: 'name', type: 'string' },
      { name: 'description', type: 'string' }
    ],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'removeNGO',
    inputs: [{ name: 'ngo', type: 'address' }],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'updateNGO',
    inputs: [
      { name: 'ngo', type: 'address' },
      { name: 'name', type: 'string' },
      { name: 'description', type: 'string' }
    ],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'setCurrentNGO',
    inputs: [{ name: 'ngo', type: 'address' }],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'isNGOApproved',
    inputs: [{ name: 'ngo', type: 'address' }],
    outputs: [{ name: '', type: 'bool' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'getCurrentNGO',
    inputs: [],
    outputs: [{ name: '', type: 'address' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'getApprovedNGOs',
    inputs: [],
    outputs: [{ name: '', type: 'address[]' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'getNGOInfo',
    inputs: [{ name: 'ngo', type: 'address' }],
    outputs: [
      {
        name: '',
        type: 'tuple',
        components: [
          { name: 'name', type: 'string' },
          { name: 'description', type: 'string' },
          { name: 'approvalTime', type: 'uint256' },
          { name: 'totalReceived', type: 'uint256' },
          { name: 'isActive', type: 'bool' }
        ]
      }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'getRegistryStats',
    inputs: [],
    outputs: [
      { name: 'totalApproved', type: 'uint256' },
      { name: 'currentNGOAddress', type: 'address' },
      { name: 'totalDonations', type: 'uint256' }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'hasRole',
    inputs: [
      { name: 'role', type: 'bytes32' },
      { name: 'account', type: 'address' },
    ],
    outputs: [{ name: '', type: 'bool' }],
    stateMutability: 'view'
  }
] as const;
