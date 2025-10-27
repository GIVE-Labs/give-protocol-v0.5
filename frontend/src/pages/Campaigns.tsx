import { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import { Search, Heart } from 'lucide-react';
import { useAccount, useReadContract } from 'wagmi';
import { useCampaignRegistry } from '../hooks/v05';
import CampaignCard from '../components/campaign/CampaignCard';
import CampaignAdminControls from '../components/campaign/CampaignAdminControls.tsx';

const categories = [
  { id: 'all', label: 'All Causes', icon: '🌍' },
  { id: 'climate', label: 'Climate Action', icon: '🌱' },
  { id: 'education', label: 'Education', icon: '📚' },
  { id: 'healthcare', label: 'Healthcare', icon: '🏥' },
  { id: 'poverty', label: 'Poverty Relief', icon: '🤝' },
  { id: 'emergency', label: 'Emergency', icon: '🚨' },
];

const statusFilters = [
  { id: 'all', label: 'All Campaigns', icon: '📋' },
  { id: 'submitted', label: 'Pending Approval', icon: '⏳', status: 1 },
  { id: 'approved', label: 'Approved', icon: '✅', status: 2 },
  { id: 'active', label: 'Active', icon: '🚀', status: 3 },
  { id: 'paused', label: 'Paused', icon: '⏸️', status: 4 },
  { id: 'completed', label: 'Completed', icon: '🎯', status: 5 },
  { id: 'cancelled', label: 'Cancelled', icon: '❌', status: 6 },
];

export default function Campaigns() {
  const { address: userAddress } = useAccount();
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedCategory, setSelectedCategory] = useState('all');
  const [selectedStatus, setSelectedStatus] = useState('all');
  const [showAdminView, setShowAdminView] = useState(false);
  
  const { activeCampaigns } = useCampaignRegistry();
  const isLoading = false; // Hook doesn't expose loading state

  // Check if user has campaign admin role
  const ACL_MANAGER_ADDRESS = '0xC6454Ec62f53823692f426F1fb4Daa57c184A36A';
  const CAMPAIGN_ADMIN_ROLE = '0xd3e32b3a2fa74f439ab3adcee4a4d8e75b9e2708f2f9a4ddeb9808e95755fbdf'; // keccak256("ROLE_CAMPAIGN_ADMIN")
  
  const { data: hasAdminRole } = useReadContract({
    address: ACL_MANAGER_ADDRESS as `0x${string}`,
    abi: [
      {
        "inputs": [{"name": "roleId", "type": "bytes32"}, {"name": "account", "type": "address"}],
        "name": "hasRole",
        "outputs": [{"name": "", "type": "bool"}],
        "stateMutability": "view",
        "type": "function"
      }
    ],
    functionName: 'hasRole',
    args: [CAMPAIGN_ADMIN_ROLE as `0x${string}`, userAddress as `0x${string}`],
    query: { enabled: !!userAddress }
  });
  
  const isCampaignAdmin = hasAdminRole === true;

  // Auto-show admin view if user has admin role
  useEffect(() => {
    if (isCampaignAdmin) {
      setShowAdminView(true);
    }
  }, [isCampaignAdmin]);

  const filteredCampaignIds = activeCampaigns || [];

  return (
    <div className="min-h-screen bg-gradient-to-br from-emerald-50 via-cyan-50 to-teal-50 relative overflow-hidden">
      {/* Animated Background Elements */}
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        <div className="absolute top-20 left-10 w-72 h-72 bg-gradient-to-r from-emerald-200/20 to-cyan-200/20 rounded-full blur-3xl animate-pulse" />
        <div className="absolute bottom-20 right-10 w-96 h-96 bg-gradient-to-r from-teal-200/20 to-blue-200/20 rounded-full blur-3xl animate-pulse" />
        <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-64 h-64 bg-gradient-to-r from-cyan-200/10 to-emerald-200/10 rounded-full blur-3xl" />
      </div>

      <div className="container mx-auto px-4 py-12 relative z-10">
        {/* Hero Section */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6 }}
          className="text-center mb-12"
        >
          <div className="flex items-center justify-center gap-4 mb-6">
            <h1 className="text-5xl md:text-6xl font-bold font-unbounded bg-gradient-to-r from-emerald-600 via-cyan-600 to-teal-600 bg-clip-text text-transparent">
              {showAdminView ? 'Campaign Management' : 'Support Impact Campaigns'}
            </h1>
            {isCampaignAdmin && (
              <button
                onClick={() => setShowAdminView(!showAdminView)}
                className="px-4 py-2 bg-gradient-to-r from-purple-500 to-indigo-500 text-white rounded-lg font-semibold text-sm hover:from-purple-600 hover:to-indigo-600 transition-all shadow-lg"
              >
                {showAdminView ? '👤 Public View' : '⚙️ Admin View'}
              </button>
            )}
          </div>
          <p className="text-xl text-gray-700 max-w-2xl mx-auto mb-8">
            {showAdminView 
              ? 'Review, approve, and manage campaign lifecycle from submission to completion'
              : 'Deposit principal, keep it safe, and direct 100% of the yield to causes you care about'}
          </p>

          {/* Search Bar */}
          <motion.div
            initial={{ opacity: 0, scale: 0.95 }}
            animate={{ opacity: 1, scale: 1 }}
            transition={{ delay: 0.2 }}
            className="max-w-2xl mx-auto"
          >
            <div className="relative">
              <Search className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" />
              <input
                type="text"
                placeholder="Search campaigns by name or description..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="w-full pl-12 pr-4 py-4 bg-white/80 backdrop-blur-sm border border-gray-200 rounded-2xl shadow-lg focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all"
              />
            </div>
          </motion.div>
        </motion.div>

        {/* Admin Status Filters */}
        {showAdminView && (
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.25 }}
            className="mb-8"
          >
            <div className="bg-gradient-to-r from-purple-100 to-indigo-100 rounded-2xl p-6 border border-purple-200">
              <h3 className="text-lg font-semibold text-gray-900 mb-4 font-unbounded">Campaign Status</h3>
              <div className="flex flex-wrap gap-3">
                {statusFilters.map((filter, index) => (
                  <motion.button
                    key={filter.id}
                    initial={{ opacity: 0, scale: 0.9 }}
                    animate={{ opacity: 1, scale: 1 }}
                    transition={{ delay: 0.3 + index * 0.05 }}
                    whileHover={{ scale: 1.05 }}
                    whileTap={{ scale: 0.95 }}
                    onClick={() => setSelectedStatus(filter.id)}
                    className={`px-4 py-2 rounded-full font-medium text-sm transition-all duration-300 ${
                      selectedStatus === filter.id
                        ? 'bg-gradient-to-r from-purple-500 to-indigo-500 text-white shadow-lg'
                        : 'bg-white text-gray-700 hover:bg-gray-50 hover:shadow-md'
                    }`}
                  >
                    <span className="mr-2">{filter.icon}</span>
                    {filter.label}
                  </motion.button>
                ))}
              </div>
            </div>
          </motion.div>
        )}

        {/* Category Filters */}
        {!showAdminView && (
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.3 }}
            className="mb-12"
          >
            <div className="flex flex-wrap justify-center gap-3">
              {categories.map((category, index) => (
                <motion.button
                  key={category.id}
                  initial={{ opacity: 0, scale: 0.9 }}
                  animate={{ opacity: 1, scale: 1 }}
                  transition={{ delay: 0.4 + index * 0.05 }}
                  whileHover={{ scale: 1.05 }}
                  whileTap={{ scale: 0.95 }}
                  onClick={() => setSelectedCategory(category.id)}
                  className={`px-6 py-3 rounded-full font-medium transition-all duration-300 ${
                    selectedCategory === category.id
                      ? 'bg-gradient-to-r from-emerald-500 to-teal-500 text-white shadow-lg'
                      : 'bg-white/80 backdrop-blur-sm text-gray-700 hover:bg-white hover:shadow-md'
                  }`}
                >
                  <span className="mr-2">{category.icon}</span>
                  {category.label}
                </motion.button>
              ))}
            </div>
          </motion.div>
        )}

        {/* Campaign Grid */}
        {isLoading ? (
          <div className="flex justify-center items-center py-20">
            <div className="text-center">
              <div className="w-16 h-16 border-4 border-emerald-500 border-t-transparent rounded-full animate-spin mx-auto mb-4" />
              <p className="text-gray-600">Loading campaigns...</p>
            </div>
          </div>
        ) : filteredCampaignIds.length === 0 ? (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            className="text-center py-20"
          >
            <div className="w-24 h-24 bg-gradient-to-r from-emerald-100 to-teal-100 rounded-full flex items-center justify-center mx-auto mb-6">
              <Heart className="w-12 h-12 text-emerald-600" />
            </div>
            <h3 className="text-2xl font-bold text-gray-900 mb-4 font-unbounded">No Campaigns Found</h3>
            <p className="text-gray-600 max-w-md mx-auto">
              {searchQuery
                ? "Try adjusting your search or filter criteria"
                : "No campaigns have been created yet. Be the first to make a difference!"}
            </p>
          </motion.div>
        ) : showAdminView ? (
          <div className="space-y-4">
            {filteredCampaignIds.map((campaignId: `0x${string}`, index: number) => (
              <CampaignAdminControls 
                key={campaignId} 
                campaignId={campaignId} 
                index={index}
                statusFilter={selectedStatus}
              />
            ))}
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {filteredCampaignIds.map((campaignId: `0x${string}`, index: number) => (
              <CampaignCard key={campaignId} campaignId={campaignId} index={index} />
            ))}
          </div>
        )}

        {/* Stats Bar */}
        {/* <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.5 }}
          className="mt-16 bg-white/60 backdrop-blur-xl rounded-2xl shadow-lg p-8"
        >
          <div className="grid grid-cols-1 md:grid-cols-3 gap-8 text-center">
            <div>
              <div className="text-4xl font-bold bg-gradient-to-r from-emerald-600 to-teal-600 bg-clip-text text-transparent mb-2 font-unbounded">
                {filteredCampaignIds.length}
              </div>
              <div className="text-gray-600 font-medium">Active Campaigns</div>
            </div>
            <div>
              <div className="text-4xl font-bold bg-gradient-to-r from-cyan-600 to-blue-600 bg-clip-text text-transparent mb-2 font-unbounded">
                100%
              </div>
              <div className="text-gray-600 font-medium">Yield to Impact</div>
            </div>
            <div>
              <div className="text-4xl font-bold bg-gradient-to-r from-teal-600 to-emerald-600 bg-clip-text text-transparent mb-2 font-unbounded">
                0%
              </div>
              <div className="text-gray-600 font-medium">Principal Risk</div>
            </div>
          </div>
        </motion.div> */}
      </div>
    </div>
  );
}
