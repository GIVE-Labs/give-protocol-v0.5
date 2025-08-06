import { Link } from 'react-router-dom'
import { mockNGOs } from '../data/mockData'
import { NGOCard } from '../components/ngo/NGOCard'

export default function Home() {
  const featuredNGOs = mockNGOs.filter(ngo => ngo.isVerified).slice(0, 3)

  return (
    <div className="min-h-screen">
      {/* Hero Section */}
      <div className="bg-gradient-to-br from-purple-600 via-pink-500 to-red-500">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-24">
          <div className="text-center">
            <h1 className="text-5xl font-bold text-white mb-6">
              Reimagining Donations
              <span className="block text-3xl mt-2">Fueling Impact</span>
            </h1>
            <p className="text-xl text-purple-100 mb-8 max-w-2xl mx-auto">
              Revolutionary DeFi NGO fundraising. Stake your ETH/USDC on Morph Chain 
              to generate yield for verified NGOs while keeping your full principal.
            </p>
            <div className="mb-8">
              <div className="inline-flex items-center space-x-3 bg-white/10 backdrop-blur-sm rounded-lg px-4 py-2">
                <span className="text-white/90 text-sm font-medium">Powered by</span>
                <img 
                  src="/src/assets/morph-logo.png" 
                  alt="Morph" 
                  className="h-8"
                />
              </div>
            </div>
            <div className="flex flex-col sm:flex-row gap-4 justify-center">
              <Link
                to="/discover"
                className="bg-white text-purple-600 px-8 py-3 rounded-lg font-semibold hover:bg-gray-100 transition-colors"
              >
                Explore NGOs
              </Link>
              <Link
                to="/dashboard"
                className="border-2 border-white text-white px-8 py-3 rounded-lg font-semibold hover:bg-white hover:text-purple-600 transition-colors"
              >
                View Portfolio
              </Link>
            </div>
          </div>
        </div>
      </div>

      {/* How It Works */}
      <div className="py-20 bg-gray-50">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center mb-16">
            <h2 className="text-4xl font-bold text-gray-900 mb-4">How It Works</h2>
            <p className="text-xl text-gray-600 max-w-2xl mx-auto">
              Simple 4-step process to support NGOs while keeping your investment
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-4 gap-8">
            {[
              {
                step: 1,
                title: 'Connect Wallet',
                description: 'Connect your Web3 wallet to Morph Holesky Testnet'
              },
              {
                step: 2,
                title: 'Choose NGO',
                description: 'Select from verified NGOs making real impact'
              },
              {
                step: 3,
                title: 'Stake Crypto',
                description: 'Stake ETH/USDC with your chosen yield contribution'
              },
              {
                step: 4,
                title: 'Generate Impact',
                description: 'NGOs receive yield while you keep your principal'
              }
            ].map((item, index) => (
              <div key={item.step} className="text-center">
                <div className="bg-purple-100 w-16 h-16 rounded-full flex items-center justify-center mx-auto mb-4">
                  <span className="text-purple-600 font-bold text-xl">{item.step}</span>
                </div>
                <h3 className="text-xl font-semibold text-gray-900 mb-2">{item.title}</h3>
                <p className="text-gray-600">{item.description}</p>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Featured NGOs */}
      <div className="py-20">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center mb-12">
            <h2 className="text-4xl font-bold text-gray-900 mb-4">Featured NGOs</h2>
            <p className="text-xl text-gray-600">Start supporting these verified organizations</p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
            {featuredNGOs.map((ngo) => (
              <NGOCard key={ngo.ngoAddress} ngo={ngo} />
            ))}
          </div>

          <div className="text-center mt-12">
            <Link
              to="/discover"
              className="bg-purple-600 text-white px-8 py-3 rounded-lg font-semibold hover:bg-purple-700 transition-colors"
            >
              View All NGOs
            </Link>
          </div>
        </div>
      </div>

      {/* Stats */}
      <div className="py-20 bg-purple-600">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="grid grid-cols-1 md:grid-cols-4 gap-8 text-center">
            <div>
              <div className="text-4xl font-bold text-white mb-2">4</div>
              <div className="text-purple-200">Verified NGOs</div>
            </div>
            <div>
              <div className="text-4xl font-bold text-white mb-2">$8,300</div>
              <div className="text-purple-200">Yield Distributed</div>
            </div>
            <div>
              <div className="text-4xl font-bold text-white mb-2">414</div>
              <div className="text-purple-200">Active Stakers</div>
            </div>
            <div>
              <div className="text-4xl font-bold text-white mb-2">50,000</div>
              <div className="text-purple-200">Total Value Staked</div>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}