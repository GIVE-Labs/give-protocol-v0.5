import { useState, useEffect } from 'react'
import { NGOCard } from '../components/ngo/NGOCard'
import { useNGORegistry } from '../hooks/useNGORegistry'
import { useActiveChain } from '@thirdweb-dev/react'

export default function Discover() {
  const [selectedCause, setSelectedCause] = useState<string>('All')
  const [searchQuery, setSearchQuery] = useState('')
  const activeChain = useActiveChain()
  
  const contractAddress = activeChain?.chainId === 2810 
    ? '0x1234567890123456789012345678901234567890' // Morph mainnet
    : '0x1234567890123456789012345678901234567890' // Morph testnet
  
  const { ngos: contractNGOs, loading, error, refetch } = useNGORegistry(contractAddress)

  // Get unique causes from real NGO data
  const causes = Array.from(
    new Set(contractNGOs.flatMap(ngo => ngo.causes))
  ).sort()

  const filteredNGOs = contractNGOs.filter(ngo => {
    const matchesCause = selectedCause === 'All' || ngo.causes.includes(selectedCause)
    const matchesSearch = ngo.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
                         ngo.description.toLowerCase().includes(searchQuery.toLowerCase())
    return matchesCause && matchesSearch
  })

  // Calculate stats from real data
  const verifiedNGOs = contractNGOs.filter(ngo => ngo.isVerified)
  const totalYieldDistributed = verifiedNGOs.reduce(
    (sum, ngo) => sum + Number(ngo.totalYieldReceived), 0
  )
  const totalStakers = verifiedNGOs.reduce(
    (sum, ngo) => sum + Number(ngo.totalStakers), 0
  )

  useEffect(() => {
    refetch()
  }, [contractAddress])

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
              <p className="text-3xl font-bold text-green-600">{totalYieldDistributed.toFixed(2)} ETH</p>
              <p className="text-gray-600">Yield Distributed</p>
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

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
        {filteredNGOs.map((ngo) => (
          <NGOCard key={ngo.ngoAddress} ngo={ngo} />
        ))}
      </div>

      {filteredNGOs.length === 0 && (
        <div className="text-center py-12">
          <p className="text-gray-500 text-lg">No NGOs found matching your criteria.</p>
        </div>
      )}
    </div>
  )
}