import { useState } from 'react'
import { useAccount } from 'wagmi'
import { motion } from 'framer-motion'
import { ChevronDown, ChevronUp } from 'lucide-react'
import VaultStats from '../components/vault/VaultStats'
import VaultDepositForm from '../components/vault/VaultDepositForm'
import { usePayoutRouter } from '../hooks/v05'
import { BASE_SEPOLIA_ADDRESSES } from '../config/baseSepolia'

export default function Dashboard() {
  const { address } = useAccount()
  const [showDepositForm, setShowDepositForm] = useState(false)
  const { userPreference } = usePayoutRouter(address)

  if (!address) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-emerald-50 via-cyan-50 to-teal-50 relative overflow-hidden">
        <div className="absolute inset-0 overflow-hidden pointer-events-none">
          <div className="absolute top-20 left-10 w-32 h-32 bg-gradient-to-r from-emerald-200/30 to-cyan-200/30 rounded-full blur-xl" />
        </div>
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12 relative z-10">
          <div className="text-center">
            <h1 className="text-4xl font-bold text-gray-900 mb-4 font-unbounded">Connect Your Wallet</h1>
            <p className="text-xl text-gray-600 font-medium font-unbounded">Please connect your wallet to view your portfolio</p>
          </div>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-emerald-50 via-cyan-50 to-teal-50 relative overflow-hidden">
      {/* Animated Background Elements */}
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        <div className="absolute top-20 left-10 w-32 h-32 bg-gradient-to-r from-emerald-200/30 to-cyan-200/30 rounded-full blur-xl animate-pulse" />
        <div className="absolute top-40 right-20 w-24 h-24 bg-gradient-to-r from-teal-200/30 to-blue-200/30 rounded-full blur-xl animate-pulse" />
      </div>
      
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12 relative z-10 space-y-12">
        {/* Header */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5 }}
        >
          <h1 className="text-4xl font-bold text-gray-900 mb-4 font-unbounded">Portfolio Dashboard</h1>
          <p className="text-xl text-gray-600 font-medium font-unbounded">Track your WETH vault position and impact</p>
        </motion.div>

        {/* Vault Stats */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5, delay: 0.1 }}
        >
          <VaultStats vaultAddress={BASE_SEPOLIA_ADDRESSES.GIVE_WETH_VAULT as `0x${string}`} />
        </motion.div>

        {/* Deposit Section */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5, delay: 0.2 }}
          className="bg-white/60 backdrop-blur-xl border border-white/70 rounded-2xl shadow-lg p-8"
        >
          <button
            onClick={() => setShowDepositForm(!showDepositForm)}
            className="w-full flex items-center justify-between text-left group"
          >
            <div>
              <h2 className="text-2xl font-bold text-gray-900 mb-2 font-unbounded">Deposit More</h2>
              <p className="text-gray-600">Increase your vault position to generate more yield</p>
            </div>
            {showDepositForm ? (
              <ChevronUp className="w-6 h-6 text-gray-400 group-hover:text-brand-600 transition-colors" />
            ) : (
              <ChevronDown className="w-6 h-6 text-gray-400 group-hover:text-brand-600 transition-colors" />
            )}
          </button>

          {showDepositForm && (
            <motion.div
              initial={{ opacity: 0, height: 0 }}
              animate={{ opacity: 1, height: 'auto' }}
              exit={{ opacity: 0, height: 0 }}
              transition={{ duration: 0.3 }}
              className="mt-6"
            >
              <VaultDepositForm vaultAddress={BASE_SEPOLIA_ADDRESSES.GIVE_WETH_VAULT as `0x${string}`} />
            </motion.div>
          )}
        </motion.div>

        {/* Yield Allocation */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5, delay: 0.3 }}
          className="bg-white/60 backdrop-blur-xl border border-white/70 rounded-2xl shadow-lg p-8"
        >
          <h2 className="text-2xl font-bold text-gray-900 mb-6 font-unbounded">My Yield Allocation</h2>
          
          {!userPreference ? (
            <div className="text-center py-8">
              <div className="animate-spin rounded-full h-12 w-12 border-4 border-brand-600 border-t-transparent mx-auto" />
              <p className="text-gray-600 mt-4">Loading preferences...</p>
            </div>
          ) : userPreference.campaignId ? (
            <div className="space-y-4">
              <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                <div className="bg-gradient-to-br from-emerald-50 to-teal-50 rounded-xl p-6 border border-emerald-200/50">
                  <p className="text-sm text-gray-600 mb-1">Campaign ID</p>
                  <p className="text-2xl font-bold text-gray-900">#{userPreference.campaignId.toString()}</p>
                </div>
                <div className="bg-gradient-to-br from-cyan-50 to-blue-50 rounded-xl p-6 border border-cyan-200/50">
                  <p className="text-sm text-gray-600 mb-1">Beneficiary</p>
                  <p className="text-lg font-bold text-gray-900 truncate">
                    {userPreference.beneficiary === address ? 'You' : `${userPreference.beneficiary.slice(0, 6)}...${userPreference.beneficiary.slice(-4)}`}
                  </p>
                </div>
                <div className="bg-gradient-to-br from-teal-50 to-emerald-50 rounded-xl p-6 border border-teal-200/50">
                  <p className="text-sm text-gray-600 mb-1">Allocation</p>
                  <p className="text-2xl font-bold text-gray-900">{Number(userPreference.allocationBps) / 100}%</p>
                </div>
              </div>
              <p className="text-sm text-gray-600 mt-4">
                💚 Your yield is being directed to Campaign #{userPreference.campaignId.toString()} with {Number(userPreference.allocationBps) / 100}% allocation
              </p>
            </div>
          ) : (
            <div className="text-center py-8">
              <div className="bg-gradient-to-br from-gray-50 to-gray-100 rounded-xl p-8 border border-gray-200">
                <p className="text-gray-600 mb-4">You haven't set a yield allocation yet</p>
                <a
                  href="/campaigns"
                  className="inline-flex items-center bg-gradient-to-r from-emerald-600 to-cyan-600 text-white px-6 py-3 rounded-xl font-semibold hover:from-emerald-700 hover:to-cyan-700 transition-all duration-300 shadow-lg hover:shadow-xl"
                >
                  Browse Campaigns
                </a>
              </div>
            </div>
          )}
        </motion.div>
      </div>
    </div>
  )
}