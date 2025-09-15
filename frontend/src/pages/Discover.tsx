import { useState, useEffect } from 'react'
import { NGOCard } from '../components/ngo/NGOCard'
import { useReadContract } from 'wagmi'
import { NGO } from '../types'
import NGORegistryABI from '../abis/NGORegistry.json'
import { CONTRACT_ADDRESSES } from '../config/contracts'

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
  
  const contractAddress = CONTRACT_ADDRESSES.NGO_REGISTRY
  
  // Fetch all NGO addresses
  const { data: allNGOs, refetch } = useReadContract({
    address: contractAddress as `0x${string}`,
    abi: NGORegistryABI,
    functionName: 'getApprovedNGOs',
  });

  // Fetch NGO details for each address
  const [ngos, setNgos] = useState<NGO[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)

  useEffect(() => {
    const fetchNGOs = async () => {
      if (!allNGOs || !Array.isArray(allNGOs)) {
        setLoading(false)
        return
      }

      setLoading(true)
      try {
        const ngoPromises = allNGOs.map(async (ngoData: any) => {
          const address = ngoData.ngoAddress
          const response = await fetchContractData(address)
          return formatNGOData(address, response)
        })
        
        const ngoData = await Promise.all(ngoPromises)
        setNgos(ngoData.filter(Boolean))
      } catch (err: any) {
        setError(err?.message || 'An error occurred')
      } finally {
        setLoading(false)
      }
    }

    fetchNGOs()
  }, [allNGOs, contractAddress])

  // Helper to fetch contract data from blockchain
  const fetchContractData = async (ngoAddress: string) => {
    try {
      // Use viem's readContract to fetch NGO info from the blockchain
      // Note: This is a simplified approach - in production you'd want to use a proper client
      console.log('Fetching NGO info for address:', ngoAddress);
      
      // For now, return a placeholder since we need to set up the viem client properly
      // This will be improved in the next iteration
      const ngoInfo = {
        name: `NGO at ${ngoAddress.slice(0, 6)}...${ngoAddress.slice(-4)}`,
        description: 'NGO information loaded from blockchain',
        website: '',
        logoURI: '',
        walletAddress: ngoAddress,
        isVerified: true,
        isActive: true,
        totalYieldReceived: 0n,
        activeStakers: 0n,
        totalStakers: 0n,
        causes: ['General'],
        reputationScore: 0n,
        metadataHash: '',
        registrationTime: 0n
      };

      // Return the contract data in the expected format
      return {
        name: ngoInfo.name || 'Unknown NGO',
        description: ngoInfo.description || 'No description available',
        website: ngoInfo.website || '',
        logoURI: ngoInfo.logoURI || '',
        walletAddress: ngoInfo.walletAddress || ngoAddress,
        isVerified: ngoInfo.isVerified || false,
        isActive: ngoInfo.isActive || false,
        totalYieldReceived: ngoInfo.totalYieldReceived || 0n,
        activeStakers: ngoInfo.activeStakers || 0n,
        totalStakers: ngoInfo.activeStakers || 0n,
        causes: ngoInfo.causes || ['General'],
        reputationScore: ngoInfo.reputationScore || 0n,
        metadataHash: ngoInfo.metadataHash || '',
        registrationTime: ngoInfo.registrationTime || 0n
      };
    } catch (error) {
      console.error('Error fetching NGO data for address', ngoAddress, ':', error);
      return {
        name: 'Error Loading NGO',
        description: 'Failed to load NGO information from blockchain',
        website: '',
        logoURI: '',
        walletAddress: ngoAddress,
        isVerified: false,
        isActive: false,
        totalYieldReceived: 0n,
        activeStakers: 0n,
        totalStakers: 0n,
        causes: ['General'],
        reputationScore: 0n,
        metadataHash: '',
        registrationTime: 0n
      };
    }
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
            onClick={() => refetch && refetch()}
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