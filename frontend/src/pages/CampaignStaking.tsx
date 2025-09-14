import { useState, useEffect, useMemo } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt, useBalance } from 'wagmi';
import { formatUnits, parseUnits } from 'viem';
import { motion } from 'framer-motion';
import { ArrowLeft, Heart, Share2, Twitter, Facebook, Linkedin, Info, Gift, ExternalLink, Award, ChevronDown } from 'lucide-react';
import { NGO_REGISTRY_ABI } from '../abis/NGORegistry';
import { GiveVault4626ABI } from '../abis/GiveVault4626';
import { erc20Abi } from '../abis/erc20';

import { CONTRACT_ADDRESSES } from '../config/contracts';
import { NGO } from '../types';
import Button from '../components/ui/Button';

export default function CampaignStaking() {
  const { ngoAddress } = useParams<{ ngoAddress: string }>();
  const navigate = useNavigate();
  const { address, isConnected, chain } = useAccount();
  
  // Network validation
  const isCorrectNetwork = chain?.id === 11155111; // Sepolia testnet
  const networkError = isConnected && !isCorrectNetwork ? 'Please switch to Sepolia testnet' : null;
  const [stakeAmount, setStakeAmount] = useState('0');
  const [lockPeriod, setLockPeriod] = useState(12);
  const [yieldSharingRatio, setYieldSharingRatio] = useState(75);
  const [selectedToken, setSelectedToken] = useState<string>(CONTRACT_ADDRESSES.TOKENS.USDC);
  const [activeTab, setActiveTab] = useState<'details' | 'donate'>('donate');
  const [isTokenDropdownOpen, setIsTokenDropdownOpen] = useState(false);
  const [showFullDescription, setShowFullDescription] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);

  // NOTE: The current vault is USDC-based (ERC20 with 6 decimals).
  // To avoid failed deposits and incorrect approvals, only USDC is enabled for staking.
  const tokens = [
    { symbol: 'USDC', address: CONTRACT_ADDRESSES.TOKENS.USDC, icon: '/src/assets/token/usd-coin-usdc-logo.svg', decimals: 6 },
    // Future support:
    // { symbol: 'ETH', address: CONTRACT_ADDRESSES.TOKENS.ETH, icon: '/src/assets/token/ethereum-eth-icon.svg', decimals: 18 },
    // { symbol: 'WETH', address: CONTRACT_ADDRESSES.TOKENS.WETH, icon: '/src/assets/token/weth-1671744457-logotic-brand.svg', decimals: 18 }
  ];

  const selectedTokenInfo = tokens.find(token => token.address === selectedToken) || tokens[0];

  // Fetch NGO information
  const { data: ngoInfo } = useReadContract({
    address: CONTRACT_ADDRESSES.NGO_REGISTRY,
    abi: NGO_REGISTRY_ABI,
    functionName: 'getNGO',
    args: [ngoAddress as `0x${string}`],
    query: {
      enabled: !!ngoAddress,
    },
  });

  // Get user's token balance
  const { data: tokenBalance } = useBalance({
    address: address,
    token: selectedToken === CONTRACT_ADDRESSES.TOKENS.ETH ? undefined : selectedToken as `0x${string}`,
    query: {
      enabled: !!address,
    },
  });

  // Get vault total assets for target calculation (optional)
  // Removed unused variable to satisfy TypeScript

  // Active strategies read removed (unused)

  // Real-time APY from Aave adapter unavailable; using estimated APY only

  // Contract interactions with enhanced error handling
  const { writeContract: approveToken, data: approveHash, isPending: isApproving, error: approveError } = useWriteContract();
  const { writeContract: depositToVault, data: depositHash, isPending: isDepositing, error: depositError } = useWriteContract();
  const { isLoading: isApprovingTx, isSuccess: isApprovalSuccess } = useWaitForTransactionReceipt({ hash: approveHash });
  const { isLoading: isDepositingTx, isSuccess: isDepositSuccess } = useWaitForTransactionReceipt({ hash: depositHash });

  // Input validation
  const validateStakeAmount = (amount: string): string | null => {
    if (!amount || parseFloat(amount) <= 0) {
      return 'Please enter a valid stake amount';
    }
    if (tokenBalance && parseFloat(amount) > parseFloat(formatUnits(tokenBalance.value, selectedTokenInfo.decimals))) {
      return 'Insufficient balance';
    }
    if (parseFloat(amount) < 0.000001) {
      return 'Minimum stake amount is 0.000001';
    }
    return null;
  };

  // Clear messages after timeout
  useEffect(() => {
    if (error || successMessage) {
      const timer = setTimeout(() => {
        setError(null);
        setSuccessMessage(null);
      }, 5000);
      return () => clearTimeout(timer);
    }
  }, [error, successMessage]);

  // Handle transaction success
  useEffect(() => {
    if (isDepositSuccess) {
      setSuccessMessage('Stake completed successfully!');
      setStakeAmount('');
    }
  }, [isDepositSuccess]);

  // Handle transaction errors
  useEffect(() => {
    if (approveError) {
      setError(approveError.message || 'Approval failed');
    }
    if (depositError) {
      setError(depositError.message || 'Deposit failed');
    }
  }, [approveError, depositError]);

  // Calculate values
  // Parse stake amount using the selected token decimals (USDC = 6)
  const stakeAmountUnits = useMemo(() => {
    try {
      return parseUnits(stakeAmount || '0', selectedTokenInfo.decimals);
    } catch {
      return 0n;
    }
  }, [stakeAmount, selectedTokenInfo.decimals]);
  // Removed unused mock values
  
  // Calculate APY based on lock period
  const calculateAPY = (lockPeriod: number) => {
    // Token-specific fallback rates based on typical DeFi yields
    const getTokenBaseRate = () => {
      switch (selectedToken) {
        case CONTRACT_ADDRESSES.TOKENS.USDC:
          return { base: 4, name: 'USDC' }; // Stable coin base rate
        case CONTRACT_ADDRESSES.TOKENS.ETH:
          return { base: 6, name: 'ETH' }; // ETH staking-like rate
        case CONTRACT_ADDRESSES.TOKENS.WETH:
          return { base: 5.5, name: 'WETH' }; // Slightly lower than ETH
        default:
          return { base: 4, name: 'Token' };
      }
    };
    
    const { base } = getTokenBaseRate();
    
    // Add lock period bonus to base rate
     switch (lockPeriod) {
       case 6:
         return base + 1; // +1% for 6 months
       case 12:
         return base + 2.5; // +2.5% for 12 months
       case 24:
         return base + 4; // +4% for 24 months
       default:
         return base + 1;
     }
  };
  
  const estimatedAPY = calculateAPY(lockPeriod);
  const totalYield = (parseFloat(stakeAmount || '0') * estimatedAPY / 100 * lockPeriod / 12);
  const ngoShare = totalYield * (yieldSharingRatio / 100);
  const userShare = totalYield * ((100 - yieldSharingRatio) / 100);
  const userGetBack = parseFloat(stakeAmount || '0') + userShare;
  
  // Dashboard metrics
  const totalStaked = 350000;
  const currentYield = 10.5;
  const totalStakers = 850;
  const avgLockPeriod = 14.3;

  const ngo: NGO = ngoInfo ? {
    ngoAddress: ngoAddress!,
    name: ngoInfo.name || 'Global Education Fund',
    description: ngoInfo.description || 'Empowering futures through accessible education',
    website: '',
    logoURI: '/api/placeholder/40/40',
    walletAddress: ngoAddress!,
    causes: ['Education'],
    metadataURI: '',
    isVerified: true,
    isActive: ngoInfo.isActive || true,
    reputationScore: BigInt(0),
    totalStakers: BigInt(850),
    totalYieldReceived: BigInt(0),
    id: ngoAddress!,
    location: '',
    category: 'Education',
    totalStaked: '3500000',
    activeStakers: 850,
    impactScore: 95
  } : {
    ngoAddress: ngoAddress!,
    name: 'Global Education Fund',
    description: 'Empowering futures through accessible education',
    website: '',
    logoURI: '/api/placeholder/40/40',
    walletAddress: ngoAddress!,
    causes: ['Education'],
    metadataURI: '',
    isVerified: true,
    isActive: true,
    reputationScore: BigInt(0),
    totalStakers: BigInt(850),
    totalYieldReceived: BigInt(0),
    id: ngoAddress!,
    location: '',
    category: 'Education',
    totalStaked: '3500000',
    activeStakers: 850,
    impactScore: 95
  };

  const handleStake = async () => {
    if (!address || !stakeAmount) return;

    // Clear previous messages
    setError(null);
    setSuccessMessage(null);

    // Validate network
    if (!isCorrectNetwork) {
      setError('Please switch to Sepolia testnet');
      return;
    }
    
    // Validate input
    const validationError = validateStakeAmount(stakeAmount);
    if (validationError) {
      setError(validationError);
      return;
    }

    // Enforce USDC-only staking while the vault asset is USDC
    if (selectedToken !== CONTRACT_ADDRESSES.TOKENS.USDC) {
      setError('Only USDC is supported for staking at the moment.');
      return;
    }

    try {
      // First approve the vault to spend tokens (exact amount, no infinite allowance)
      await approveToken({
        address: selectedToken as `0x${string}`,
        abi: erc20Abi,
        functionName: 'approve',
        args: [CONTRACT_ADDRESSES.VAULT, stakeAmountUnits],
      });
    } catch (error) {
      console.error('Approval failed:', error);
      setError('Failed to approve token spending');
    }
  };

  // Auto-deposit after approval
  useEffect(() => {
    if (isApprovalSuccess && !isDepositing && !isDepositingTx) {
      depositToVault({
        address: CONTRACT_ADDRESSES.VAULT,
        abi: GiveVault4626ABI,
        functionName: 'deposit',
        args: [stakeAmountUnits, address!],
      });
    }
  }, [isApprovalSuccess, isDepositing, isDepositingTx, depositToVault, stakeAmountUnits, address]);

  const isLoading = isApproving || isDepositing || isApprovingTx || isDepositingTx;

  return (
    <div className="min-h-screen bg-gradient-to-br from-emerald-50 via-cyan-50 to-teal-50 relative overflow-hidden">
      {/* Animated Background Elements */}
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        <motion.div 
          className="absolute top-20 left-10 w-32 h-32 bg-gradient-to-r from-emerald-200/30 to-cyan-200/30 rounded-full blur-xl"
          animate={{ 
            scale: [1, 1.2, 1],
            rotate: [0, 180, 360]
          }}
          transition={{
            duration: 20,
            repeat: Infinity,
            ease: "linear"
          }}
        />
        <motion.div 
          className="absolute top-40 right-20 w-24 h-24 bg-gradient-to-r from-teal-200/30 to-blue-200/30 rounded-full blur-xl"
          animate={{ 
            scale: [1.2, 1, 1.2],
            rotate: [360, 180, 0]
          }}
          transition={{
            duration: 15,
            repeat: Infinity,
            ease: "linear"
          }}
        />
        <motion.div 
          className="absolute bottom-20 left-1/3 w-40 h-40 bg-gradient-to-r from-cyan-200/20 to-emerald-200/20 rounded-full blur-2xl"
          animate={{ 
            scale: [1, 1.3, 1],
            x: [-20, 20, -20]
          }}
          transition={{
            duration: 25,
            repeat: Infinity,
            ease: "easeInOut"
          }}
        />
      </div>

      {/* Header */}
      <div className="bg-white/80 backdrop-blur-sm border-b border-white/50 relative z-10">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex items-center justify-between h-16">
            <motion.button
              onClick={() => navigate(-1)}
              className="flex items-center text-gray-600 hover:text-emerald-600 transition-colors"
              whileHover={{ x: -5 }}
              whileTap={{ scale: 0.95 }}
            >
              <ArrowLeft className="w-5 h-5 mr-2" />
              Back
            </motion.button>
          </div>
        </div>
      </div>

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8 relative z-10">
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
          {/* Left Column - Campaign Info */}
          <div className="lg:col-span-2 space-y-6">
            <motion.div 
              className="bg-white/80 backdrop-blur-xl rounded-3xl overflow-hidden shadow-xl border border-white/50"
              initial={{ opacity: 0, y: 30 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.6 }}
            >
              {/* Campaign Image */}
              <div className="relative h-80 overflow-hidden">
                <div className="absolute inset-0 bg-gradient-to-br from-emerald-500/10 via-cyan-500/10 to-teal-500/10"></div>
                <div className="absolute top-6 left-6 z-10">
                  <motion.span 
                    className="bg-white/90 backdrop-blur-sm text-emerald-700 px-4 py-2 rounded-full text-sm font-semibold shadow-lg border border-emerald-200"
                    whileHover={{ scale: 1.05 }}
                  >
                    {ngo.category}
                  </motion.span>
                </div>
                <div className="absolute top-6 right-6 flex space-x-2 z-10">
                  <motion.button 
                    className="p-2 bg-white/90 backdrop-blur-sm rounded-full text-emerald-600 hover:bg-white transition-all shadow-lg border border-emerald-200"
                    whileHover={{ scale: 1.1, y: -2 }}
                    whileTap={{ scale: 0.95 }}
                  >
                    <Heart className="w-4 h-4" />
                  </motion.button>
                  <motion.button 
                    className="p-2 bg-white/90 backdrop-blur-sm rounded-full text-emerald-600 hover:bg-white transition-all shadow-lg border border-emerald-200"
                    whileHover={{ scale: 1.1, y: -2 }}
                    whileTap={{ scale: 0.95 }}
                  >
                    <Share2 className="w-4 h-4" />
                  </motion.button>
                </div>
                <div className="absolute inset-0 bg-gradient-to-t from-black/40 via-transparent to-transparent"></div>
                <img 
                  src="/src/assets/IMG_4241.jpg" 
                  alt="Education Campaign" 
                  className="w-full h-full object-cover"
                />
              </div>

              {/* Campaign Details */}
              <div className="px-8 pt-8">
                <div className="flex items-center mb-6">
                  <motion.div 
                    className="relative mr-4"
                    whileHover={{ scale: 1.05 }}
                  >
                    <img 
                      src="/src/assets/IMG_5543.jpg" 
                      alt={ngo.name} 
                      className="w-16 h-16 rounded-full object-cover border-3 border-emerald-200 shadow-lg"
                    />
                    <div className="absolute -bottom-1 -right-1 w-6 h-6 bg-emerald-500 rounded-full flex items-center justify-center border-2 border-white">
                      <Award className="w-3 h-3 text-white" />
                    </div>
                  </motion.div>
                  <div>
                    <h3 className="text-2xl font-bold text-gray-900 font-unbounded mb-1">{ngo.name}</h3>
                    <div className="flex items-center justify-between">
                    <div className="flex items-center space-x-4 text-sm">
                      <p className="text-emerald-600 flex items-center font-medium">
                        <Award className="w-4 h-4 mr-1" />
                        Verified NGO
                      </p>
                    </div>
                    
                    {/* Clean Social Media Buttons */}
                    <div className="flex items-center space-x-2">
                      <motion.button 
                        className="p-2 text-gray-400 hover:text-blue-500 transition-colors"
                        whileHover={{ scale: 1.1, y: -1 }}
                        whileTap={{ scale: 0.95 }}
                      >
                        <Twitter className="w-4 h-4" />
                      </motion.button>
                      <motion.button 
                        className="p-2 text-gray-400 hover:text-blue-600 transition-colors"
                        whileHover={{ scale: 1.1, y: -1 }}
                        whileTap={{ scale: 0.95 }}
                      >
                        <Facebook className="w-4 h-4" />
                      </motion.button>
                      <motion.button 
                        className="p-2 text-gray-400 hover:text-blue-700 transition-colors"
                        whileHover={{ scale: 1.1, y: -1 }}
                        whileTap={{ scale: 0.95 }}
                      >
                        <Linkedin className="w-4 h-4" />
                      </motion.button>
                      <motion.button 
                        className="p-2 text-gray-400 hover:text-emerald-600 transition-colors"
                        whileHover={{ scale: 1.1, y: -1 }}
                        whileTap={{ scale: 0.95 }}
                      >
                        <ExternalLink className="w-4 h-4" />
                      </motion.button>
                    </div>
                  </div>
                  </div>
                </div>
                <div className="mb-8">
                  <p className="text-gray-700 text-md leading-relaxed text-justify">
                    {showFullDescription ? ngo.description : `${ngo.description.slice(0, 150)}...`}
                  </p>
                  <motion.button
                    onClick={() => setShowFullDescription(!showFullDescription)}
                    className="text-emerald-600 hover:text-emerald-700 text-sm font-medium mt-2 transition-colors"
                    whileHover={{ scale: 1.02 }}
                  >
                    {showFullDescription ? 'Show Less' : 'Read More'}
                  </motion.button>
                </div>

                {/* Campaign Stats */}
              </div>
            </motion.div>
          </div>

          {/* Right Column - Tabbed Sidebar */}
          <div className="lg:col-span-1">
            <motion.div 
              className="bg-white/80 backdrop-blur-xl rounded-3xl shadow-xl border border-white/50 sticky top-8 overflow-hidden"
              initial={{ opacity: 0, x: 30 }}
              animate={{ opacity: 1, x: 0 }}
              transition={{ duration: 0.6, delay: 0.3 }}
            >
              {/* Tab Navigation */}
              <div className="flex border-b border-gray-200">
                <button
                  onClick={() => setActiveTab('details')}
                  className={`flex-1 px-4 py-3 text-sm font-medium transition-colors ${
                    activeTab === 'details'
                      ? 'text-blue-600 border-b-2 border-blue-600 bg-blue-50'
                      : 'text-gray-500 hover:text-gray-700'
                  }`}
                >
                  <Info className="w-4 h-4 inline mr-2" />
                  Details
                </button>
                <button
                  onClick={() => setActiveTab('donate')}
                  className={`flex-1 px-4 py-3 text-sm font-medium transition-colors ${
                    activeTab === 'donate'
                      ? 'text-blue-600 border-b-2 border-blue-600 bg-blue-50'
                      : 'text-gray-500 hover:text-gray-700'
                  }`}
                >
                  <Gift className="w-4 h-4 inline mr-2" />
                  Donate
                </button>
              </div>

              {/* Tab Content */}
              <div className="p-6">
                {activeTab === 'details' && (
                  <motion.div
                    initial={{ opacity: 0, y: 10 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ duration: 0.3 }}
                    className="space-y-6"
                  >
                    {/* Error/Success Messages */}
                    {error && (
                      <motion.div
                        initial={{ opacity: 0, y: -10 }}
                        animate={{ opacity: 1, y: 0 }}
                        className="bg-red-50 border border-red-200 rounded-xl p-3 mb-4"
                      >
                        <p className="text-red-700 text-sm font-medium">❌ {error}</p>
                      </motion.div>
                    )}
                    
                    {successMessage && (
                      <motion.div
                        initial={{ opacity: 0, y: -10 }}
                        animate={{ opacity: 1, y: 0 }}
                        className="bg-green-50 border border-green-200 rounded-xl p-3 mb-4"
                      >
                        <p className="text-green-700 text-sm font-medium">✅ {successMessage}</p>
                      </motion.div>
                    )}

                    {/* Funding Target */}
                    <div className="bg-gradient-to-br from-emerald-50 via-green-50 to-emerald-100 rounded-2xl p-4 mb-6 border border-emerald-200/50">
                      <div className="flex items-center justify-between">
                        <div>
                          <h4 className="font-semibold font-unbounded text-gray-900 mb-1">Funding Target</h4>
                          <p className="text-xl font-bold bg-gradient-to-r from-emerald-500 to-cyan-500 bg-clip-text text-transparent">$2.5M USD</p>
                        </div>
                        <div className="text-right">
                          <p className="text-sm text-gray-600 font-unbounded mb-1">Progress</p>
                          <p className="text-lg font-bold text-gray-900">68%</p>
                        </div>
                      </div>
                      <div className="mt-3">
                        <div className="bg-white/60 rounded-full h-2 overflow-hidden">
                          <div className="h-full bg-gradient-to-r from-emerald-500 to-cyan-500 rounded-full" style={{width: '68%'}} />
                        </div>
                      </div>
                    </div>

                    {/* Dashboard Metrics */}
                    <div className="grid grid-cols-2 gap-4">
                      <div className="bg-gradient-to-br from-blue-50 via-blue-100 to-blue-200 p-3 rounded-xl border border-blue-300/50 shadow-sm">
                        <div className="text-base font-bold bg-gradient-to-r from-blue-700 to-blue-600 bg-clip-text text-transparent">${totalStaked.toFixed(2)}</div>
                        <div className="text-xs text-blue-800 font-medium">Total Staked</div>
                      </div>
                      <div className="bg-gradient-to-br from-sky-50 via-sky-100 to-cyan-100 p-3 rounded-xl border border-sky-300/50 shadow-sm">
                        <div className="text-base font-bold bg-gradient-to-r from-sky-700 to-cyan-600 bg-clip-text text-transparent">{currentYield.toFixed(1)}%</div>
                        <div className="text-xs text-sky-800 font-medium">Current APY</div>
                      </div>
                      <div className="bg-gradient-to-br from-teal-50 via-teal-100 to-emerald-100 p-3 rounded-xl border border-teal-300/50 shadow-sm">
                        <div className="text-base font-bold bg-gradient-to-r from-teal-700 to-emerald-600 bg-clip-text text-transparent">{totalStakers}</div>
                        <div className="text-xs text-teal-800 font-medium">Total Stakers</div>
                      </div>
                      <div className="bg-gradient-to-br from-emerald-50 via-green-100 to-green-200 p-3 rounded-xl border border-emerald-300/50 shadow-sm">
                        <div className="text-base font-bold bg-gradient-to-r from-emerald-700 to-green-600 bg-clip-text text-transparent">{avgLockPeriod} Months</div>
                        <div className="text-xs text-emerald-800 font-medium">Avg Lock Duration</div>
                      </div>
                    </div>

                    {/* Compact Asset Distribution */}
                    <div className="mt-6">
                      <h5 className="text-xs font-semibold text-gray-900 mb-4 text-center font-unbounded">Asset Distribution</h5>
                      <div className="flex items-center justify-center mb-12">
                        <div className="relative w-24 h-24">
                          <svg className="w-24 h-24 transform -rotate-90" viewBox="0 0 36 36">
                            <path
                              d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831"
                              fill="none"
                              stroke="#f3f4f6"
                              strokeWidth="3"
                            />
                            <path
                              d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831"
                              fill="none"
                              stroke="#10b981"
                              strokeWidth="3"
                              strokeDasharray="60, 100"
                              strokeLinecap="round"
                            />
                            <path
                              d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831"
                              fill="none"
                              stroke="#3b82f6"
                              strokeWidth="3"
                              strokeDasharray="25, 100"
                              strokeDashoffset="-60"
                              strokeLinecap="round"
                            />
                            <path
                              d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831"
                              fill="none"
                              stroke="#f59e0b"
                              strokeWidth="3"
                              strokeDasharray="15, 100"
                              strokeDashoffset="-85"
                              strokeLinecap="round"
                            />
                          </svg>
                          <div className="absolute inset-0 flex items-center justify-center">
                            <div className="text-center">
                              <div className="text-xs font-bold text-gray-900">$3.5M</div>
                            </div>
                          </div>
                        </div>
                      </div>
                      <div className="space-y-2">
                        <div className="flex items-center justify-between text-xs">
                          <div className="flex items-center">
                            <div className="w-2 h-2 bg-emerald-500 rounded-full mr-2"></div>
                            <span>USDC</span>
                          </div>
                          <span className="font-medium">60%</span>
                        </div>
                        <div className="flex items-center justify-between text-xs">
                          <div className="flex items-center">
                            <div className="w-2 h-2 bg-blue-500 rounded-full mr-2"></div>
                            <span>ETH</span>
                          </div>
                          <span className="font-medium">25%</span>
                        </div>
                        <div className="flex items-center justify-between text-xs">
                          <div className="flex items-center">
                            <div className="w-2 h-2 bg-amber-500 rounded-full mr-2"></div>
                            <span>WETH</span>
                          </div>
                          <span className="font-medium">15%</span>
                        </div>
                      </div>
                    </div>
                  </motion.div>
                )}

                {activeTab === 'donate' && (
                  <motion.div
                    initial={{ opacity: 0, y: 10 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ duration: 0.3 }}
                    className="space-y-6"
                  >

                     {/* Stake Amount Input */}
                     <div className="mb-4">
                       <label className="block text-xs font-semibold text-gray-700 mb-2">Stake Amount:</label>
                       
                       {/* Flexbox Container */}
                        <div className="flex items-stretch">
                          {/* Amount Input */}
                          <div className="flex-1">
                            <motion.input
                              type="number"
                              value={stakeAmount}
                              onChange={(e) => {
                                const value = e.target.value;
                                // Limit to 6 decimal places
                                if (value === '' || /^\d*\.?\d{0,6}$/.test(value)) {
                                  setStakeAmount(value);
                                }
                              }}
                              className="w-full px-4 py-3 text-base font-bold border-2 border-emerald-200 rounded-l-xl border-r-0 focus:outline-none focus:ring-2bg-white/80 backdrop-blur-sm transition-all [appearance:textfield] [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none"
                              placeholder="0"
                            />
                          </div>
                          
                          {/* Max Button */}
                          {tokenBalance && (
                            <motion.button
                              type="button"
                              onClick={() => {
                                const maxAmount = formatUnits(tokenBalance.value, selectedTokenInfo.decimals);
                                // Limit to 6 decimal places
                                const limitedAmount = parseFloat(maxAmount).toFixed(6).replace(/\.?0+$/, '');
                                setStakeAmount(limitedAmount);
                              }}
                              className="px-3 text-sm font-semibold text-emerald-600 hover:text-emerald-700 bg-white/80 hover:bg-emerald-50 border-t-2 border-b-2 border-emerald-200 transition-all backdrop-blur-sm leading-tight"
                            >
                              MAX
                            </motion.button>
                          )}
                          
                          {/* Token Dropdown */}
                          <div className="relative">
                            <motion.button
                               type="button"
                               onClick={() => setIsTokenDropdownOpen(!isTokenDropdownOpen)}
                               className="flex items-center space-x-1 px-2 py-3 text-base font-bold border-2 border-emerald-200 rounded-r-xl border-l-2 focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 bg-white/80 backdrop-blur-sm transition-all hover:bg-gray-50"
                             >
                               <img src={selectedTokenInfo.icon} alt={selectedTokenInfo.symbol} className="w-5 h-5" />
                               <span className="text-gray-700 min-w-[3rem]">{selectedTokenInfo.symbol}</span>
                               <ChevronDown className={`w-4 h-4 text-gray-500 transition-transform ${
                                 isTokenDropdownOpen ? 'rotate-180' : ''
                               }`} />
                             </motion.button>
                            
                            {/* Dropdown Menu */}
                            {isTokenDropdownOpen && (
                              <motion.div
                                initial={{ opacity: 0, y: -10 }}
                                animate={{ opacity: 1, y: 0 }}
                                exit={{ opacity: 0, y: -10 }}
                                className="absolute top-full right-0 mt-1 w-40 bg-white border-2 border-emerald-200 rounded-xl shadow-xl z-50 overflow-hidden"
                              >
                                {tokens.map((token) => (
                                  <motion.button
                                    key={token.symbol}
                                    onClick={() => {
                                      setSelectedToken(token.address);
                                      setIsTokenDropdownOpen(false);
                                    }}
                                    className={`w-full flex items-center space-x-3 px-4 py-3 text-left hover:bg-emerald-50 transition-colors border-b border-gray-100 last:border-b-0 ${
                                      selectedToken === token.address ? 'bg-emerald-50 text-emerald-700' : 'text-gray-700'
                                    }`}
                                    whileHover={{ backgroundColor: '#ecfdf5' }}
                                  >
                                    <img src={token.icon} alt={token.symbol} className="w-5 h-5" />
                                    <span className="text-sm font-medium">{token.symbol}</span>
                                  </motion.button>
                                ))}
                              </motion.div>
                            )}
                         </div>
                       </div>
                       
                       {tokenBalance && (
                         <p className="text-xs text-gray-600 mt-2 font-medium ml-2">
                           Balance: {parseFloat(formatUnits(tokenBalance.value, selectedTokenInfo.decimals)).toFixed(6).replace(/\.?0+$/, '')} {tokenBalance.symbol}
                         </p>
                       )}
                       
                       {/* Balance and Validation Feedback */}
                       {stakeAmount && (
                         <div className="mt-2 ml-2">
                           {tokenBalance && parseFloat(stakeAmount) > parseFloat(formatUnits(tokenBalance.value, selectedTokenInfo.decimals)) ? (
                             <p className="text-xs text-red-500 font-medium flex items-center gap-1">
                               Insufficient balance.
                             </p>
                           ) : parseFloat(stakeAmount) < 0.000001 ? (
                             <p className="text-xs text-orange-500 font-medium flex items-center gap-1">
                               Minimum stake amount is 0.000001 {selectedTokenInfo.symbol}
                             </p>
                           ) : null}
                         </div>
                       )}
                     </div>

              {/* Lock Period */}
              <div className="mb-5">
                <label className="block text-xs font-semibold text-gray-700 mb-3">Select lock-in period:</label>
                <div className="grid grid-cols-3 gap-2">
                  {[6, 12, 24].map((months) => (
                    <motion.button
                      key={months}
                      onClick={() => setLockPeriod(months)}
                      className={`py-2 px-3 rounded-xl text-xs font-semibold transition-all shadow-lg ${
                        lockPeriod === months
                          ? 'bg-gradient-to-r from-emerald-500 to-cyan-500 text-white shadow-emerald-200'
                          : 'bg-white/80 text-gray-700 hover:bg-emerald-50 border border-emerald-200'
                      }`}
                      whileHover={{ scale: 1.05, y: -2 }}
                      whileTap={{ scale: 0.95 }}
                    >
                      {months} Months
                    </motion.button>
                  ))}
                </div>
              </div>

              {/* Yield Sharing Ratio */}
              <div className="mb-5">
                <label className="block text-xs font-semibold text-gray-700 mb-3">Select yield-sharing ratio:</label>
                <div className="grid grid-cols-3 gap-2">
                  {[50, 75, 100].map((ratio) => (
                    <motion.button
                      key={ratio}
                      onClick={() => setYieldSharingRatio(ratio)}
                      className={`py-2 px-3 rounded-xl text-xs font-semibold transition-all shadow-lg ${
                        yieldSharingRatio === ratio
                          ? 'bg-gradient-to-r from-emerald-500 to-cyan-500 text-white shadow-emerald-200'
                          : 'bg-white/80 text-gray-700 hover:bg-emerald-50 border border-emerald-200'
                      }`}
                      whileHover={{ scale: 1.05, y: -2 }}
                      whileTap={{ scale: 0.95 }}
                    >
                      {ratio}%
                    </motion.button>
                  ))}
                </div>
              </div>

              {/* Yield Breakdown */}
              <motion.div 
                className="bg-gradient-to-br from-emerald-50 to-cyan-50 rounded-xl p-4 mb-5 border border-emerald-100"
                initial={{ opacity: 0, scale: 0.95 }}
                animate={{ opacity: 1, scale: 1 }}
                transition={{ duration: 0.5, delay: 0.4 }}
              >
                <div className="space-y-3">
                  <div className="flex justify-between items-center">
                    <span className="text-xs text-gray-600 font-medium">Lock Period:</span>
                    <span className="font-bold text-emerald-600 text-sm">{lockPeriod} months</span>
                  </div>
                  <div className="flex justify-between items-center">
                    <span className="text-xs text-gray-600 font-medium">Estimated APY:</span>
                    <div className="flex items-center gap-1">
                      <span className="font-bold text-emerald-600 text-sm">{estimatedAPY.toFixed(2)}%</span>
                      <span className="text-xs bg-orange-100 text-orange-700 px-1 rounded">Est.</span>
                    </div>
                  </div>
                  <div className="flex justify-between items-center">
                    <div className="flex items-center gap-1">
                      <span className="text-xs text-gray-600 font-medium">Total Yield:</span>
                      <img src={selectedTokenInfo.icon} alt={selectedTokenInfo.symbol} className="w-3 h-3" />
                      <span className="text-xs text-gray-600 font-medium">{selectedTokenInfo.symbol}</span>
                    </div>
                    <span className="font-bold text-cyan-600 text-sm">{totalYield.toFixed(4)}</span>
                  </div>
                  <div className="border-t border-emerald-200 pt-3">
                    <div className="flex justify-between items-center text-emerald-600 mb-1">
                      <div className="flex items-center gap-1">
                        <span className="text-xs font-medium">To NGO ({yieldSharingRatio}%):</span>
                        <img src={selectedTokenInfo.icon} alt={selectedTokenInfo.symbol} className="w-3 h-3" />
                        <span className="text-xs font-medium">{selectedTokenInfo.symbol}</span>
                      </div>
                      <span className="font-bold text-sm">{ngoShare.toFixed(4)}</span>
                    </div>
                    <div className="flex justify-between items-center text-cyan-600">
                      <div className="flex items-center gap-1">
                        <span className="text-xs font-medium">To You ({100 - yieldSharingRatio}%):</span>
                        <img src={selectedTokenInfo.icon} alt={selectedTokenInfo.symbol} className="w-3 h-3" />
                        <span className="text-xs font-medium">{selectedTokenInfo.symbol}</span>
                      </div>
                      <span className="font-bold text-sm">{userShare.toFixed(4)}</span>
                    </div>
                  </div>
                  <div className="border-t border-emerald-200 pt-3">
                    <div className="flex justify-between items-center">
                      <div className="flex items-center gap-1">
                        <span className="text-xs font-bold text-gray-700">You Get Back:</span>
                        <img src={selectedTokenInfo.icon} alt={selectedTokenInfo.symbol} className="w-4 h-4" />
                        <span className="text-xs font-bold text-gray-700">{selectedTokenInfo.symbol}</span>
                      </div>
                      <span className="font-bold text-base bg-gradient-to-r from-emerald-600 to-cyan-600 bg-clip-text text-transparent">{userGetBack.toFixed(4)}</span>
                    </div>
                  </div>
                </div>
              </motion.div>

              {/* Stake Button */}
              <motion.div
                whileHover={{ scale: 1.02 }}
                whileTap={{ scale: 0.98 }}
              >
                <Button
                  onClick={handleStake}
                  disabled={!address || !stakeAmount || isLoading || !!validateStakeAmount(stakeAmount) || !!networkError}
                  className={`w-full font-bold py-3 px-4 rounded-xl transition-all shadow-xl text-base ${
                    !address || !stakeAmount || !!validateStakeAmount(stakeAmount) || !!networkError
                      ? 'bg-gray-300 text-gray-500 cursor-not-allowed'
                      : isLoading
                      ? 'bg-gradient-to-r from-blue-400 to-blue-500 text-white cursor-wait'
                      : 'bg-gradient-to-r from-emerald-500 to-cyan-500 hover:from-emerald-600 hover:to-cyan-600 text-white hover:shadow-2xl'
                  }`}
                >
                  {!address ? (
                    <div className="flex items-center justify-center">
                      🔗 Connect Wallet
                    </div>
                  ) : !stakeAmount ? (
                    <div className="flex items-center justify-center">
                      💰 Enter Amount
                    </div>
                  ) : networkError ? (
                    <div className="flex items-center justify-center">
                      🌐 {networkError}
                    </div>
                  ) : validateStakeAmount(stakeAmount) ? (
                    <div className="flex items-center justify-center">
                      ⚠️ {validateStakeAmount(stakeAmount)}
                    </div>
                  ) : isLoading ? (
                    <div className="flex items-center justify-center">
                      <motion.div
                        className="w-5 h-5 border-2 border-white border-t-transparent rounded-full mr-2"
                        animate={{ rotate: 360 }}
                        transition={{ duration: 1, repeat: Infinity, ease: "linear" }}
                      />
                      {isApproving || isApprovingTx ? 'Approving...' : 'Staking...'}
                    </div>
                  ) : (
                    <div className="flex items-center justify-center font-unbounded">
                      <Heart className="w-4 h-4 mr-2" />
                      Donate Yield
                    </div>
                  )}
                </Button>
              </motion.div>

                       <p className="text-xs text-gray-500 text-center mt-3 font-medium">
                         🔒 Secure payment via smart contract
                       </p>
                  </motion.div>
                )}
              </div>
            </motion.div>
          </div>
        </div>
      </div>
    </div>
  );
}
