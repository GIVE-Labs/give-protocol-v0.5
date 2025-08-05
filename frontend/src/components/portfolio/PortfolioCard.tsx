import { formatEther } from 'viem'
import { Clock, DollarSign, Heart } from 'lucide-react'
import { StakeData } from '../../types'

interface PortfolioCardProps {
  stake: StakeData
  ngoName: string
  ngoLogo: string
}

export default function PortfolioCard({ stake, ngoName, ngoLogo }: PortfolioCardProps) {
  const lockUntil = new Date(Number(stake.stakeInfo.lockUntil) * 1000)
  const isLocked = lockUntil > new Date()
  const daysUntilUnlock = Math.ceil((lockUntil.getTime() - Date.now()) / (1000 * 60 * 60 * 24))

  const contributionRate = Number(stake.stakeInfo.yieldContributionRate) / 100
  const totalYield = formatEther(stake.stakeInfo.totalYieldGenerated)
  const yieldToNGO = formatEther(stake.stakeInfo.totalYieldToNGO)
  const yieldToUser = (parseFloat(totalYield) - parseFloat(yieldToNGO)).toFixed(4)

  return (
    <div className="bg-white rounded-lg shadow-md p-6 hover:shadow-lg transition-shadow">
      <div className="flex items-start justify-between mb-4">
        <div className="flex items-center">
          <img
            src={ngoLogo}
            alt={ngoName}
            className="w-12 h-12 rounded-full mr-4"
          />
          <div>
            <h3 className="font-semibold text-gray-900">{ngoName}</h3>
            <p className="text-sm text-gray-600">{contributionRate}% yield contribution</p>
          </div>
        </div>
        <div className={`px-2 py-1 rounded-full text-xs font-medium ${
          isLocked ? 'bg-red-100 text-red-800' : 'bg-green-100 text-green-800'
        }`}>
          {isLocked ? `Locked (${daysUntilUnlock} days)` : 'Unlocked'}
        </div>
      </div>

      <div className="grid grid-cols-3 gap-4 mb-4">
        <div className="text-center">
          <div className="text-2xl font-bold text-blue-600">{formatEther(stake.stakeInfo.amount)} ETH</div>
          <div className="text-sm text-gray-600">Staked Amount</div>
        </div>
        <div className="text-center">
          <div className="text-2xl font-bold text-green-600">${totalYield}</div>
          <div className="text-sm text-gray-600">Total Yield</div>
        </div>
        <div className="text-center">
          <div className="text-2xl font-bold text-purple-600">${yieldToUser}</div>
          <div className="text-sm text-gray-600">Your Yield</div>
        </div>
      </div>

      <div className="flex items-center justify-between text-sm">
        <div className="flex items-center text-gray-600">
          <Heart className="w-4 h-4 mr-1 text-red-500" />
          <span>${yieldToNGO} donated to NGO</span>
        </div>
        <div className="flex items-center text-gray-600">
          <Clock className="w-4 h-4 mr-1" />
          <span>{lockUntil.toLocaleDateString()}</span>
        </div>
      </div>
    </div>
  )
}