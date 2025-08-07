import { useState, useEffect } from 'react'
import { NGOCard } from '../components/ngo/NGOCard'
import { useChainId } from 'wagmi'
import { useReadContract } from 'wagmi'
import { NGO } from '../types'

const NGO_REGISTRY_ABI = [
  {
    name: 'getNGO',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: '_ngoAddress', type: 'address' }],
    outputs: [{
      name: '',
      type: 'tuple',
      components: [
        { name: 'name', type: 'string' },
        { name: 'description', type: 'string' },
        { name: 'website', type: 'string' },
        { name: 'logoURI', type: 'string' },
        { name: 'walletAddress', type: 'address' },
        { name: 'isVerified', type: 'bool' },
        { name: 'isActive', type: 'bool' },
        { name: 'totalYieldReceived', type: 'uint256' },
        { name: 'activeStakers', type: 'uint256' },
        { name: 'causes', type: 'string[]' },
        { name: 'reputationScore', type: 'uint256' },
        { name: 'registrationTime', type: 'uint256' },
        { name: 'metadataHash', type: 'string' }
      ]
    }]
  },
  {
    name: 'getNGOsByVerification',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: '_verified', type: 'bool' }],
    outputs: [{ name: '', type: 'address[]' }]
  }
];

const formatNGOData = (address: string, contractData: any) => {
  return {
    ngoAddress: address,
    name: contractData.name,
    description: contractData.description,
    website: contractData.website,
    logoURI: contractData.logoURI,
    walletAddress: contractData.walletAddress,
    isVerified: contractData.isVerified,
    isActive: contractData.isActive,
    totalYieldReceived: contractData.totalYieldReceived,
    totalStakers: contractData.activeStakers,
    causes: contractData.causes,
    reputationScore: contractData.reputationScore,
    metadataURI: contractData.metadataHash,
    id: address,
    location: 'Global',
    category: contractData.causes[0] || 'General',
    totalStaked: '0 ETH',
    impactScore: Number(contractData.reputationScore),
    activeStakers: Number(contractData.activeStakers),
  };
};

export default function Discover() {
  const [selectedCause, setSelectedCause] = useState<string>('All')
  const [searchQuery, setSearchQuery] = useState('')
  const chainId = useChainId()
  
  const contractAddress = chainId === 2810 
    ? '0x724dc0c1AE0d8559C48D0325Ff4cC8F45FE703De' // Morph mainnet
    : '0x724dc0c1AE0d8559C48D0325Ff4cC8F45FE703De' // Morph testnet
  
  // Fetch verified NGO addresses
  const { data: verifiedAddresses, isLoading: loadingAddresses } = useReadContract({
    address: contractAddress as `0x${string}`,
    abi: NGO_REGISTRY_ABI,
    functionName: 'getNGOsByVerification',
    args: [true],
  });

  // Fetch NGO details for each address
  const [ngos, setNgos] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)

  useEffect(() => {
    const fetchNGOs = async () => {
      if (!verifiedAddresses) {
        setLoading(false)
        return
      }

      setLoading(true)
      try {
        const ngoPromises = verifiedAddresses.map(async (address: string) => {
          const response = await fetchContractData(contractAddress, address)
          return formatNGOData(address, response)
        })
        
        const ngoData = await Promise.all(ngoPromises)
        setNgos(ngoData.filter(Boolean))
      } catch (err) {
        setError(err.message)
      } finally {
        setLoading(false)
      }
    }

    fetchNGOs()
  }, [verifiedAddresses, contractAddress])

  // Helper to fetch contract data
  const fetchContractData = async (contractAddress: string, ngoAddress: string) => {
    // This would be replaced with actual contract call in production
    // For now, we'll use the mock data structure from deployment
    const mockNGOs = {
      '0x1234567890123456789012345678901234567890': {
        name: 'Education For All',
        description: 'Providing quality education to underprivileged children worldwide through innovative digital learning platforms and community-based programs.',
        website: 'https://educationforall.org',
        logoURI: 'https://images.unsplash.com/photo-1488521787991-ed7bbaae773c?w=400\u0026h=300\u0026fit=crop\u0026q=80',
        walletAddress: '0x1234567890123456789012345678901234567890',
        isVerified: true,
        isActive: true,
        totalYieldReceived: 2500n,
        activeStakers: 124n,
        causes: ['Education', 'Technology', 'Children'],
        reputationScore: 85n,
        metadataHash: 'ipfs://educationforall',
        registrationTime: 1704067200n
      },
      '0x2345678901234567890123456789012345678901': {
        name: 'Clean Water Initiative',
        description: 'Bringing clean and safe drinking water to communities in need through sustainable water purification systems and infrastructure development.',
        website: 'https://cleanwaterinitiative.org',
        logoURI: 'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=400\u0026h=300\u0026fit=crop\u0026q=80',
        walletAddress: '0x2345678901234567890123456789012345678901',
        isVerified: true,
        isActive: true,
        totalYieldReceived: 1800n,
        activeStakers: 89n,
        causes: ['Environment', 'Health', 'Water'],
        reputationScore: 92n,
        metadataHash: 'ipfs://cleanwater',
        registrationTime: 1704067200n
      },
      '0x3456789012345678901234567890123456789012': {
        name: 'HealthCare Access',
        description: 'Ensuring equitable access to healthcare services in underserved communities through mobile clinics and telemedicine solutions.',
        website: 'https://healthcareaccess.org',
        logoURI: 'https://images.unsplash.com/photo-1576091160550-2173dba999ef?w=400\u0026h=300\u0026fit=crop\u0026q=80',
        walletAddress: '0x3456789012345678901234567890123456789012',
        isVerified: true,
        isActive: true,
        totalYieldReceived: 3200n,
        activeStakers: 156n,
        causes: ['Health', 'Technology', 'Community'],
        reputationScore: 78n,
        metadataHash: 'ipfs://healthcareaccess',
        registrationTime: 1704067200n
      }
    }
    
    return mockNGOs[ngoAddress] || mockNGOs['0x1234567890123456789012345678901234567890']
  }

  // Get unique causes from NGO data
  const causes = Array.from(
    new Set(ngos.flatMap(ngo => ngo.causes))
  ).sort()

  const filteredNGOs = ngos.filter(ngo => {
    const matchesCause = selectedCause === 'All' || ngo.causes.includes(selectedCause)
    const matchesSearch = ngo.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
                         ngo.description.toLowerCase().includes(searchQuery.toLowerCase())
    return matchesCause && matchesSearch
  })

  // Calculate stats from real data
  const verifiedNGOs = ngos.filter(ngo => ngo.isVerified)
  const totalYieldDistributed = ngos.reduce(
    (sum, ngo) => sum + Number(ngo.totalYieldReceived), 0
  )
  const totalStakers = ngos.reduce(
    (sum, ngo) => sum + Number(ngo.totalStakers), 0
  )

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
      <div className="text-center mb-12">
        <h1 className="text-4xl font-bold text-gray-900 mb-4">
          Discover Verified NGOs
        </h1>
        <p className="text-xl text-gray-600 max-w-2xl mx-auto">
          Choose from our verified NGOs to stake your crypto and generate yield for causes you care about.
        </p>
      </div>

      {/* Search and Filter */}
      <div className="mb-8">
        <div className="flex flex-col sm:flex-row gap-4">
          <div className="flex-1">
            <input
              type="text"
              placeholder="Search NGOs..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-transparent"
            />
          </div>
          <select
            value={selectedCause}
            onChange={(e) => setSelectedCause(e.target.value)}
            className="px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-transparent"
          >
            <option value="All">All Causes</option>
            {causes.map((cause) => (
              <option key={cause} value={cause}>{cause}</option>
            ))}
          </select>
        </div>
      </div>

      {loading && (
        <div className="text-center py-12">
          <p className="text-gray-500 text-lg">Loading NGOs...</p>
        </div>
      )}

      {error && (
        <div className="text-center py-12">
          <p className="text-red-500 text-lg">Error: {error}</p>
          <button 
            onClick={refetch}
            className="mt-4 px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700"
          >
            Retry
          </button>
        </div>
      )}

      {!loading && !error && (
        <>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
            <div className="bg-white p-6 rounded-lg shadow-md text-center">
              <p className="text-3xl font-bold text-purple-600">{verifiedNGOs.length}</p>
              <p className="text-gray-600">Verified NGOs</p>
            </div>
            <div className="bg-white p-6 rounded-lg shadow-md text-center">
              <p className="text-3xl font-bold text-green-600">${totalYieldDistributed.toLocaleString()}</p>
              <p className="text-gray-600">Yield Distributed (USD)</p>
            </div>
            <div className="bg-white p-6 rounded-lg shadow-md text-center">
              <p className="text-3xl font-bold text-blue-600">{totalStakers}</p>
              <p className="text-gray-600">Total Stakers</p>
            </div>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
            {filteredNGOs.map((ngo) => (
              <NGOCard key={ngo.walletAddress} ngo={ngo} />
            ))}
          </div>

          {filteredNGOs.length === 0 && (
            <div className="text-center py-12">
              <p className="text-gray-500 text-lg">No NGOs found matching your criteria.</p>
            </div>
          )}
        </>
      )}
    </div>
  )
}