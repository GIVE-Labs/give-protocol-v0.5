import { useState, useEffect } from 'react'
import { useParams } from 'react-router-dom'
import { Heart, MapPin, Globe, Users, Calendar } from 'lucide-react'
import StakeModal from '../components/staking/StakeModal'
import Button from '../components/ui/Button'
import { useNGORegistry } from '../hooks/useNGORegistry'
import { useActiveChain } from '@thirdweb-dev/react'
import { NGO } from '../types'

export default function NGODetails() {
  const { id } = useParams()
  const [isStakeModalOpen, setIsStakeModalOpen] = useState(false)
  const activeChain = useActiveChain()
  
  const contractAddress = activeChain?.chainId === 2810 
    ? '0x1234567890123456789012345678901234567890' // Morph mainnet
    : '0x1234567890123456789012345678901234567890' // Morph testnet
  
  const { fetchNGOByAddress } = useNGORegistry(contractAddress)
  const [ngo, setNgo] = useState<NGO | null>(null)
  const [loading, setLoading] = useState(true)
  
  useEffect(() => {
    const loadNGO = async () => {
      if (id) {
        setLoading(true)
        const ngoData = await fetchNGOByAddress(id)
        setNgo(ngoData)
        setLoading(false)
      }
    }
    loadNGO()
  }, [id, contractAddress])
  
  if (loading) {
    return (
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        <div className="text-center">
          <p className="text-xl text-gray-600">Loading NGO details...</p>
        </div>
      </div>
    )
  }
  
  if (!ngo) {
    return (
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        <div className="text-center">
          <h1 className="text-4xl font-bold text-gray-900 mb-4">NGO Not Found</h1>
          <p className="text-xl text-gray-600">The NGO you're looking for doesn't exist.</p>
        </div>
      </div>
    )
  }

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
      {/* NGO Header */}
      <div className="bg-white rounded-lg shadow-lg overflow-hidden">
        <div className="relative h-64 bg-gradient-to-r from-blue-600 to-purple-600">
          <div className="absolute inset-0 bg-black bg-opacity-30" />
          <div className="absolute bottom-0 left-0 right-0 p-8">
            <div className="flex items-end justify-between">
              <div>
                <h1 className="text-4xl font-bold text-white mb-2">{ngo.name}</h1>
                <p className="text-blue-100 text-lg">{ngo.description}</p>
              </div>
              <div className="flex items-center space-x-2">
                {ngo.isVerified && (
                  <span className="bg-green-500 text-white px-3 py-1 rounded-full text-sm font-medium">
                    Verified
                  </span>
                )}
                <span className="bg-white bg-opacity-20 text-white px-3 py-1 rounded-full text-sm">
                  {ngo.causes[0] || 'General'}
                </span>
              </div>
            </div>
          </div>
        </div>

        <div className="p-8">
          <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
            {/* Left Column - NGO Info */}
            <div className="lg:col-span-2 space-y-6">
              {/* About Section */}
              <div>
                <h2 className="text-2xl font-bold text-gray-900 mb-4">About {ngo.name}</h2>
                <p className="text-gray-700 leading-relaxed">
                  {ngo.name} is dedicated to making a positive impact in the world. 
                  Through innovative programs and dedicated volunteers, we work tirelessly 
                  to address critical issues and create lasting change in communities worldwide.
                </p>
              </div>

              {/* Impact Stats */}
              <div className="bg-gray-50 rounded-lg p-6">
                <h3 className="text-lg font-semibold text-gray-900 mb-4">Impact Statistics</h3>
                <div className="grid grid-cols-3 gap-4">
                  <div className="text-center">
                    <div className="text-2xl font-bold text-blue-600">{Number(ngo.totalStakers) * 0.5} ETH</div>
                    <div className="text-sm text-gray-600">Total Staked</div>
                  </div>
                  <div className="text-center">
                    <div className="text-2xl font-bold text-green-600">{Number(ngo.totalStakers)}</div>
                    <div className="text-sm text-gray-600">Active Stakers</div>
                  </div>
                  <div className="text-center">
                    <div className="text-2xl font-bold text-purple-600">{Number(ngo.reputationScore)}</div>
                    <div className="text-sm text-gray-600">Impact Score</div>
                  </div>
                </div>
              </div>

              {/* Programs */}
              <div>
                <h3 className="text-lg font-semibold text-gray-900 mb-4">Our Programs</h3>
                <div className="space-y-3">
                  <div className="border-l-4 border-blue-500 pl-4">
                    <h4 className="font-medium text-gray-900">Education Initiatives</h4>
                    <p className="text-sm text-gray-600">Providing quality education to underprivileged communities</p>
                  </div>
                  <div className="border-l-4 border-green-500 pl-4">
                    <h4 className="font-medium text-gray-900">Healthcare Access</h4>
                    <p className="text-sm text-gray-600">Improving healthcare infrastructure and access</p>
                  </div>
                  <div className="border-l-4 border-purple-500 pl-4">
                    <h4 className="font-medium text-gray-900">Community Development</h4>
                    <p className="text-sm text-gray-600">Building sustainable communities through various programs</p>
                  </div>
                </div>
              </div>
            </div>

            {/* Right Column - Staking Card */}
            <div className="lg:col-span-1">
              <div className="bg-gradient-to-br from-blue-50 to-purple-50 rounded-lg p-6 sticky top-8">
                <h3 className="text-xl font-bold text-gray-900 mb-4">Support This NGO</h3>
                
                <div className="space-y-4 mb-6">
                  <div className="flex items-center text-sm text-gray-600">
                    <MapPin className="w-4 h-4 mr-2" />
                    Global Operations
                  </div>
                  <div className="flex items-center text-sm text-gray-600">
                    <Globe className="w-4 h-4 mr-2" />
                    Global Operations
                  </div>
                  <div className="flex items-center text-sm text-gray-600">
                    <Users className="w-4 h-4 mr-2" />
                    {Number(ngo.totalStakers)} Active Stakers
                  </div>
                  <div className="flex items-center text-sm text-gray-600">
                    <Calendar className="w-4 h-4 mr-2" />
                    Operating since 2020
                  </div>
                </div>

                <div className="border-t pt-4 mb-6">
                  <div className="text-center">
                    <div className="text-3xl font-bold text-blue-600 mb-2">{Number(ngo.totalStakers) * 0.5} ETH</div>
                    <div className="text-sm text-gray-600">Currently Staked</div>
                  </div>
                </div>

                <Button
                  onClick={() => setIsStakeModalOpen(true)}
                  className="w-full flex items-center justify-center space-x-2"
                >
                  <Heart className="w-5 h-5" />
                  <span>Stake to Support</span>
                </Button>

                <p className="text-xs text-gray-600 text-center mt-3">
                  Your principal remains yours • Only yield goes to the NGO
                </p>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Stake Modal */}
      <StakeModal
        isOpen={isStakeModalOpen}
        onClose={() => setIsStakeModalOpen(false)}
        ngo={ngo}
      />
    </div>
  )
}