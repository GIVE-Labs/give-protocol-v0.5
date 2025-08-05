import { useState } from 'react'
import { useAccount } from 'wagmi'
import DashboardStats from '../components/portfolio/DashboardStats'
import PortfolioCard from '../components/portfolio/PortfolioCard'
import { mockNGOs } from '../data/mockData'
import { StakeData } from '../types'

// Mock portfolio data - will be replaced with real contract data
const mockPortfolioData: StakeData[] = [
  {
    ngoAddress: '0x1234567890123456789012345678901234567890',
    stakeInfo: {
      amount: 2500000000000000000n, // 2.5 ETH
      lockUntil: 1735689600n, // Jan 1, 2025
      yieldContributionRate: 75n, // 75%
      totalYieldGenerated: 125000000000000000n, // 0.125 ETH
      totalYieldToNGO: 93750000000000000n, // 0.09375 ETH
      isActive: true,
      stakeTime: 1699056000n,
      lastYieldUpdate: 1706745600n,
    },
    pendingYield: {
      pendingYield: 25000000000000000n, // 0.025 ETH
      yieldToUser: 6250000000000000n, // 0.00625 ETH
      yieldToNGO: 18750000000000000n, // 0.01875 ETH
    },
  },
  {
    ngoAddress: '0x2345678901234567890123456789012345678901',
    stakeInfo: {
      amount: 1500000000000000000n, // 1.5 ETH
      lockUntil: 1743465600n, // April 1, 2025
      yieldContributionRate: 100n, // 100%
      totalYieldGenerated: 45000000000000000n, // 0.045 ETH
      totalYieldToNGO: 45000000000000000n, // 0.045 ETH
      isActive: true,
      stakeTime: 1704067200n,
      lastYieldUpdate: 1706745600n,
    },
    pendingYield: {
      pendingYield: 8000000000000000n, // 0.008 ETH
      yieldToUser: 0n,
      yieldToNGO: 8000000000000000n, // 0.008 ETH
    },
  },
]

export default function Dashboard() {
  const { address } = useAccount()
  const [portfolioData] = useState(mockPortfolioData)

  // Calculate totals
  const totalStaked = portfolioData.reduce(
    (sum, stake) => sum + Number(stake.stakeInfo.amount) / 1e18,
    0
  ).toFixed(2)

  const totalYield = portfolioData.reduce(
    (sum, stake) => sum + Number(stake.stakeInfo.totalYieldGenerated) / 1e18,
    0
  ).toFixed(2)

  const totalDonated = portfolioData.reduce(
    (sum, stake) => sum + Number(stake.stakeInfo.totalYieldToNGO) / 1e18,
    0
  ).toFixed(2)

  const activeNGOs = new Set(portfolioData.map(stake => stake.ngoAddress)).size

  if (!address) {
    return (
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        <div className="text-center">
          <h1 className="text-4xl font-bold text-gray-900 mb-4">Connect Your Wallet</h1>
          <p className="text-xl text-gray-600">Please connect your wallet to view your portfolio</p>
        </div>
      </div>
    )
  }

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
      <div className="mb-8">
        <h1 className="text-4xl font-bold text-gray-900 mb-4">Portfolio Dashboard</h1>
        <p className="text-xl text-gray-600">Track your staking positions and impact</p>
      </div>

      <DashboardStats
        totalStaked={`${totalStaked} ETH`}
        totalYield={`${totalYield} ETH`}
        activeNGOs={activeNGOs}
        totalDonated={`${totalDonated} ETH`}
      />

      <div className="mb-8">
        <h2 className="text-2xl font-bold text-gray-900 mb-6">Your Stakes</h2>
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {portfolioData.length > 0 ? (
            portfolioData.map((stake, index) => {
              const ngo = mockNGOs.find(n => n.ngoAddress === stake.ngoAddress)
              if (!ngo) return null
              
              return (
                <PortfolioCard
                  key={index}
                  stake={stake}
                  ngoName={ngo.name}
                  ngoLogo={ngo.logoURI}
                />
              )
            })
          ) : (
            <div className="col-span-2 text-center py-12">
              <div className="bg-white rounded-lg shadow-md p-8">
                <p className="text-gray-500 mb-4">You haven't made any stakes yet</p>
                <a
                  href="/discover"
                  className="inline-block bg-blue-600 text-white px-6 py-3 rounded-lg hover:bg-blue-700 transition-colors"
                >
                  Discover NGOs to Support
                </a>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}