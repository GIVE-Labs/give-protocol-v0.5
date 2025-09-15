import { useState, useEffect } from 'react';
import { useParams } from 'react-router-dom';
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt, useBalance } from 'wagmi';
import { parseEther, parseUnits, formatUnits } from 'viem';
import { erc20Abi } from 'viem';
import GiveVault4626ABI from '../abis/GiveVault4626.json';
import { useNGODetails } from '../hooks/useNGORegistryWagmi';
import { NGO } from '../types';
import StakingProgressModal from '../components/staking/StakingProgressModal';

const STAKING_CONTRACT = '0x742d35Cc6634C0532925a3b8D4C9db96C4b5Da5e';
const WETH_ADDRESS = '0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14';
const USDC_ADDRESS = '0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8';
const CONTRACT_ADDRESS = '0x742d35Cc6634C0532925a3b8D4C9db96C4b5Da5e';

export default function NGODetails() {
  const { ngoAddress } = useParams<{ ngoAddress: string }>();
  const { address: userAddress } = useAccount();
  
  // State variables
  const [stakeAmount, setStakeAmount] = useState('');
  const [lockPeriod, setLockPeriod] = useState('1y');
  const [yieldSharingRatio, setYieldSharingRatio] = useState('75%');
  const [selectedToken, setSelectedToken] = useState('USDC');
  const [activeTab, setActiveTab] = useState('overview');
  const [showProgressModal, setShowProgressModal] = useState(false);
  const [currentStep, setCurrentStep] = useState(0);
  const [isStakeComplete, setIsStakeComplete] = useState(false);
  const [isStakeError, setIsStakeError] = useState(false);
  const [currentTxHash, setCurrentTxHash] = useState<string | undefined>();
  
  // NGO data
  const { ngo, loading, error: ngoError } = useNGODetails(CONTRACT_ADDRESS, ngoAddress || '');
  
  // Token addresses
  const tokenAddress = selectedToken === 'ETH' ? undefined : 
                      selectedToken === 'WETH' ? WETH_ADDRESS : USDC_ADDRESS;
  
  // Balance queries
  const { data: ethBalance, refetch: refetchEthBalance } = useBalance({
    address: userAddress,
  });
  
  const { data: wethBalance, refetch: refetchWethBalance } = useBalance({
    address: userAddress,
    token: WETH_ADDRESS as `0x${string}`,
  });
  
  const { data: usdcBalance, refetch: refetchUsdcBalance } = useBalance({
    address: userAddress,
    token: USDC_ADDRESS as `0x${string}`,
  });
  
  // Contract interactions
  const { data: allowance, refetch: refetchAllowance } = useReadContract({
    address: tokenAddress as `0x${string}`,
    abi: erc20Abi,
    functionName: 'allowance',
    args: userAddress && tokenAddress ? [userAddress, STAKING_CONTRACT as `0x${string}`] : undefined,
    query: { enabled: !!userAddress && !!tokenAddress && selectedToken !== 'ETH' },
  });
  
  const { writeContract: approveToken, data: approvalHash, isPending: isApproving } = useWriteContract();
  const { writeContract: stakeTokens, data: stakeHash, isPending: isStaking } = useWriteContract();
  
  const { isLoading: isApprovalTx, isSuccess: isApprovalSuccess, isError: isApprovalError, error: approvalError } = useWaitForTransactionReceipt({
    hash: approvalHash,
  });
  
  const { isLoading: isStakingTx, isSuccess: isStakingSuccess, isError: isStakingError, error: stakingError } = useWaitForTransactionReceipt({
    hash: stakeHash,
  });
  
  // Helper functions
  const getBalance = () => {
    if (selectedToken === 'ETH') return ethBalance;
    if (selectedToken === 'WETH') return wethBalance;
    return usdcBalance;
  };
  
  const balance = getBalance();
  const formattedBalance = balance ? formatUnits(balance.value, balance.decimals) : '0';
  
  const amountToStake = stakeAmount ? parseFloat(stakeAmount) : 0;
  const amountInWei = selectedToken === 'ETH' || selectedToken === 'WETH' 
    ? parseEther(stakeAmount || '0')
    : parseUnits(stakeAmount || '0', 6);
  
  const needsApproval = selectedToken !== 'ETH' && allowance !== undefined && amountInWei > (allowance as bigint);
  
  const progressSteps = [
    'Approve Token',
    'Stake Tokens',
    'Complete'
  ];
  
  // Mock NGO data if not found
  const mockNgo: NGO = {
    id: ngoAddress || '1',
    ngoAddress: ngoAddress || '0x0000000000000000000000000000000000000000',
    name: 'Access to Quality Education',
    description: 'Empowering futures through accessible education',
    logoURI: '/api/placeholder/400/300',
    website: 'https://example.com',
    location: 'Global',
    category: 'Education',
    causes: ['Education', 'Youth Development', 'Community Building'],
    isVerified: true,
    totalStaked: '3500000',
    activeStakers: 850,
    walletAddress: ngoAddress || '0x0000000000000000000000000000000000000000',
    metadataURI: 'ipfs://example',
    isActive: true,
    reputationScore: 85n,
    totalStakers: 850n,
    totalYieldReceived: 2500n,
    impactScore: 92
  };
  
  const displayNgo = ngo || mockNgo;
  const targetAmount = 5000000;
  const currentStaked = parseInt(displayNgo.totalStaked);
  const progress = Math.min((currentStaked / targetAmount) * 100, 100);
  const daysLeft = 20;
  
  // Calculate estimated yield
  const estimatedYield = amountToStake * 0.10; // 10% APY
  const yieldToNgo = estimatedYield * (parseInt(yieldSharingRatio) / 100);
  const yieldToUser = estimatedYield - yieldToNgo;
  
  const executeStake = async () => {
    if (!userAddress || !stakeAmount) return;
    
    try {
      setShowProgressModal(true);
      setCurrentStep(needsApproval ? 0 : 1);
      setIsStakeError(false);
      setIsStakeComplete(false);
      
      if (needsApproval) {
        await approveToken({
          address: tokenAddress as `0x${string}`,
          abi: erc20Abi,
          functionName: 'approve',
          args: [STAKING_CONTRACT as `0x${string}`, amountInWei],
        });
      } else {
        await stakeTokens({
          address: STAKING_CONTRACT as `0x${string}`,
          abi: GiveVault4626ABI,
          functionName: 'deposit',
          args: [amountInWei, userAddress],
        });
      }
    } catch (error) {
      console.error('Staking error:', error);
      setIsStakeError(true);
    }
  };
  
  const handlePrimaryAction = () => {
    executeStake();
  };
  
  // Effects for transaction handling
  useEffect(() => {
    if (isApprovalSuccess && needsApproval) {
      setCurrentStep(1);
      setCurrentTxHash(approvalHash);
      refetchAllowance();
      
      setTimeout(() => {
        executeStake();
      }, 1000);
    }
    
    if (isApprovalError) {
      setIsStakeError(true);
    }
  }, [isApprovalSuccess, isApprovalError, approvalHash]);
  
  useEffect(() => {
    if (isStakingSuccess) {
      setCurrentStep(2);
      setCurrentTxHash(stakeHash);
      setIsStakeComplete(true);
      setStakeAmount('');
      refetchEthBalance();
      refetchWethBalance();
      refetchUsdcBalance();
    }
    
    if (isStakingError) {
      setIsStakeError(true);
    }
  }, [isStakingSuccess, isStakingError, stakeHash]);
  
  const isLoading = isApproving || isStaking || isApprovalTx || isStakingTx;
  const buttonText = isLoading ? 'Processing...' : needsApproval ? 'Approve & Stake' : 'Stake Now';
  
  if (loading) return <div className="text-center py-12">Loading...</div>;
  if (ngoError && !ngo) return <div className="text-center py-12">Error loading campaign</div>;
  
  return (
    <div className="min-h-screen bg-gradient-to-br from-emerald-50 via-cyan-50 to-teal-50 relative overflow-hidden">
      {/* Animated Background Elements */}
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        <div className="absolute top-20 left-10 w-32 h-32 bg-gradient-to-r from-emerald-200/30 to-cyan-200/30 rounded-full blur-xl" />
        <div className="absolute top-40 right-20 w-24 h-24 bg-gradient-to-r from-teal-200/30 to-blue-200/30 rounded-full blur-xl" />
        <div className="absolute bottom-20 left-1/3 w-40 h-40 bg-gradient-to-r from-blue-200/20 to-purple-200/20 rounded-full blur-2xl" />
      </div>
      
      {/* Hero Section */}
      <div className="relative h-96 bg-gradient-to-r from-emerald-600 via-teal-600 to-cyan-600">
        <img 
          src={displayNgo.logoURI} 
          alt={displayNgo.name}
          className="w-full h-full object-cover opacity-20"
        />
        <div className="absolute inset-0 bg-gradient-to-r from-emerald-600/80 via-teal-600/80 to-cyan-600/80" />
        <div className="absolute top-6 left-6">
          <span className="bg-emerald-100 text-emerald-800 px-3 py-1 rounded-full text-sm font-medium font-unbounded">
            {displayNgo.category}
          </span>
        </div>
        <div className="absolute bottom-6 left-6 text-white">
          <div className="flex items-center space-x-3 mb-4">
            <img 
              src={displayNgo.logoURI} 
              alt={displayNgo.name}
              className="w-16 h-16 rounded-lg object-cover border-2 border-white shadow-lg"
            />
            <div>
              <h1 className="text-3xl font-bold font-unbounded mb-2">{displayNgo.name}</h1>
              <div className="flex items-center space-x-2">
                <span className="bg-emerald-100 text-emerald-800 px-2 py-1 rounded-full text-xs font-medium flex items-center">
                  <svg className="w-3 h-3 mr-1" fill="currentColor" viewBox="0 0 20 20">
                    <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
                  </svg>
                  Verified NGO
                </span>
              </div>
            </div>
          </div>
          <p className="text-xl opacity-90 max-w-2xl font-medium">{displayNgo.description}</p>
        </div>
      </div>
      
      {/* Main Content */}
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8 relative z-10">
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
          {/* Left Column - Campaign Info */}
          <div className="lg:col-span-2">
            {/* Progress Section */}
            <div className="bg-white/80 backdrop-blur-sm rounded-2xl shadow-xl border border-white/20 p-6 mb-6">
              <div className="flex justify-between items-start mb-4">
                <div>
                  <h2 className="text-3xl font-bold text-gray-900">USD {currentStaked.toLocaleString()}</h2>
                  <p className="text-gray-600">of USD {targetAmount.toLocaleString()} target staked amount</p>
                </div>
                <div className="text-right">
                  <div className="text-2xl font-bold text-gray-900">{displayNgo.activeStakers}</div>
                  <div className="text-sm text-gray-600">Backers</div>
                </div>
              </div>
              
              <div className="w-full bg-gray-200 rounded-full h-3 mb-4">
                <div 
                  className="bg-gradient-to-r from-blue-500 to-purple-500 h-3 rounded-full transition-all duration-300"
                  style={{ width: `${progress}%` }}
                />
              </div>
              
              <div className="flex justify-between text-sm text-gray-600">
                <span>{Math.round(progress)}% funded</span>
                <span>{daysLeft} days since launch</span>
              </div>
            </div>
            
            {/* Tabs */}
            <div className="bg-white/80 backdrop-blur-sm rounded-2xl shadow-xl border border-white/20">
              <div className="border-b border-gray-200">
                <nav className="flex space-x-8 px-6">
                  {['overview', 'updates', 'comments', 'backers'].map((tab) => (
                    <button
                      key={tab}
                      onClick={() => setActiveTab(tab)}
                      className={`py-4 px-1 border-b-2 font-medium text-sm capitalize transition-colors font-unbounded ${
                        activeTab === tab
                          ? 'border-emerald-500 text-emerald-600'
                          : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                      }`}
                    >
                      {tab}
                      {tab === 'comments' && ' (127)'}
                    </button>
                  ))}
                </nav>
              </div>
              
              <div className="p-6">
                {activeTab === 'overview' && (
                  <div className="space-y-6">
                    <div>
                      <h3 className="text-lg font-semibold text-gray-900 mb-3 font-unbounded">About This Campaign</h3>
                      <p className="text-gray-700 leading-relaxed mb-4 font-medium">
                        {displayNgo.name} is dedicated to creating sustainable impact in {displayNgo.location.toLowerCase()}. 
                        Through innovative programs and community-driven solutions, we work tirelessly to address 
                        critical social issues and create lasting positive change.
                      </p>
                      <p className="text-gray-700 leading-relaxed font-medium">
                        Our mission focuses on empowering communities through education, providing access to quality 
                        learning opportunities, and building sustainable futures for the next generation.
                      </p>
                    </div>
                    
                    <div>
                      <h3 className="text-lg font-semibold text-gray-900 mb-3 font-unbounded">Focus Areas</h3>
                      <div className="flex flex-wrap gap-2">
                        {displayNgo.causes.map((cause: string) => (
                          <span key={cause} className="bg-gradient-to-r from-emerald-100 to-teal-100 text-emerald-800 px-3 py-1 rounded-full text-sm font-medium">
                            {cause}
                          </span>
                        ))}
                      </div>
                    </div>
                  </div>
                )}
                
                {activeTab === 'updates' && (
                  <div className="text-center py-8 text-gray-500">
                    No updates available yet.
                  </div>
                )}
                
                {activeTab === 'comments' && (
                  <div className="text-center py-8 text-gray-500">
                    Comments will be displayed here.
                  </div>
                )}
                
                {activeTab === 'backers' && (
                  <div className="text-center py-8 text-gray-500">
                    Backer information will be displayed here.
                  </div>
                )}
              </div>
            </div>
          </div>
          
          {/* Right Column - Staking Form */}
          <div className="lg:col-span-1">
            <div className="bg-white/80 backdrop-blur-sm rounded-2xl shadow-xl border border-white/20 p-6 sticky top-8">
              <h3 className="text-xl font-bold text-gray-900 mb-6 font-unbounded">Stake & Support</h3>
              
              {/* Token Selection */}
              <div className="mb-6">
                <label className="block text-sm font-medium text-gray-700 mb-2">Select token</label>
                <div className="grid grid-cols-3 gap-2">
                  {['ETH', 'WETH', 'USDC'].map((token) => (
                    <button
                      key={token}
                      onClick={() => setSelectedToken(token)}
                      className={`px-3 py-2 rounded-lg text-sm font-medium transition-colors ${
                        selectedToken === token
                          ? 'bg-gradient-to-r from-emerald-600 to-teal-600 text-white shadow-lg'
                          : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
                      }`}
                    >
                      {token}
                    </button>
                  ))}
                </div>
              </div>
              
              {/* Amount Input */}
              <div className="mb-6">
                <div className="flex justify-between items-center mb-2">
                  <label className="block text-sm font-medium text-gray-700">Amount</label>
                  <div className="text-sm text-gray-600">
                    Balance: {parseFloat(formattedBalance).toFixed(selectedToken === 'USDC' ? 2 : 4)} {selectedToken}
                  </div>
                </div>
                <div className="relative">
                  <input
                    type="number"
                    value={stakeAmount}
                    onChange={(e) => setStakeAmount(e.target.value)}
                    placeholder={`Enter amount (${selectedToken})`}
                    className="w-full px-4 py-3 pr-16 border border-gray-300 rounded-lg focus:ring-2 focus:ring-emerald-500 focus:border-transparent font-medium"
                    step="any"
                  />
                  <button
                    onClick={() => setStakeAmount(formattedBalance)}
                    className="absolute right-2 top-1/2 transform -translate-y-1/2 px-3 py-1 text-sm font-medium text-emerald-600 bg-emerald-100 rounded hover:bg-emerald-200 transition-colors"
                  >
                    MAX
                  </button>
                </div>
              </div>
              
              {/* Lock Period */}
              <div className="mb-6">
                <label className="block text-sm font-medium text-gray-700 mb-2">Lock period</label>
                <div className="grid grid-cols-3 gap-2">
                  {[
                    { value: '6m', label: '6 Months' },
                    { value: '1y', label: '1 Year' },
                    { value: '2y', label: '2 Years' }
                  ].map((period) => (
                    <button
                      key={period.value}
                      onClick={() => setLockPeriod(period.value)}
                      className={`px-3 py-2 rounded-lg text-sm font-medium transition-colors ${
                        lockPeriod === period.value
                          ? 'bg-gradient-to-r from-emerald-600 to-teal-600 text-white shadow-lg'
                          : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
                      }`}
                    >
                      {period.label}
                    </button>
                  ))}
                </div>
              </div>
              
              {/* Yield Sharing */}
              <div className="mb-6">
                <label className="block text-sm font-medium text-gray-700 mb-2">Select yield-sharing ratio</label>
                <div className="grid grid-cols-3 gap-2">
                  {['50%', '75%', '100%'].map((ratio) => (
                    <button
                      key={ratio}
                      onClick={() => setYieldSharingRatio(ratio)}
                      className={`px-3 py-2 rounded-lg text-sm font-medium transition-colors ${
                        yieldSharingRatio === ratio
                          ? 'bg-gradient-to-r from-emerald-600 to-teal-600 text-white shadow-lg'
                          : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
                      }`}
                    >
                      {ratio}
                    </button>
                  ))}
                </div>
              </div>
              
              {/* Yield Estimation */}
              {stakeAmount && (
                <div className="bg-gradient-to-r from-emerald-50 to-teal-50 rounded-lg p-4 mb-6 border border-emerald-200">
                  <h4 className="font-medium text-gray-900 mb-3 font-unbounded">Yield Estimation</h4>
                  <div className="space-y-2 text-sm">
                    <div className="flex justify-between">
                      <span className="text-gray-600">Stake Amount:</span>
                      <span className="font-medium">{stakeAmount} {selectedToken}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-gray-600">Lock Period:</span>
                      <span className="font-medium">{lockPeriod === '6m' ? '6 months' : lockPeriod === '1y' ? '12 months' : '24 months'}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-gray-600">Estimated APY:</span>
                      <span className="font-medium">10%</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-gray-600">Total Yield:</span>
                      <span className="font-medium">{estimatedYield.toFixed(4)} {selectedToken}</span>
                    </div>
                    <div className="border-t pt-2 mt-2">
                      <div className="flex justify-between text-emerald-600">
                        <span>To NGO ({yieldSharingRatio}):</span>
                        <span className="font-medium">{yieldToNgo.toFixed(4)} {selectedToken}</span>
                      </div>
                      <div className="flex justify-between text-teal-600">
                        <span>To You ({100 - parseInt(yieldSharingRatio)}%):</span>
                        <span className="font-medium">{yieldToUser.toFixed(4)} {selectedToken}</span>
                      </div>
                    </div>
                    <div className="flex justify-between font-semibold text-gray-900 border-t pt-2">
                      <span>You Get Back:</span>
                      <span>{(amountToStake + yieldToUser).toFixed(4)} {selectedToken}</span>
                    </div>
                  </div>
                  <p className="text-xs text-emerald-600 mt-2 font-medium">
                    This is an estimate based on current APY rates. Actual yields may vary.
                  </p>
                </div>
              )}
              
              {/* Stake Button */}
              <button
                onClick={handlePrimaryAction}
                disabled={!stakeAmount || parseFloat(stakeAmount) <= 0 || isLoading || !userAddress}
                className="w-full bg-gradient-to-r from-emerald-600 to-teal-600 text-white py-3 px-4 rounded-lg font-semibold hover:from-emerald-700 hover:to-teal-700 disabled:bg-gray-300 disabled:cursor-not-allowed transition-all duration-200 shadow-lg hover:shadow-xl transform hover:-translate-y-0.5 font-unbounded"
              >
                {buttonText}
              </button>
              
              <p className="text-xs text-gray-500 text-center mt-3">
                Secure payment via smart contract • Principal remains yours
              </p>
            </div>
          </div>
        </div>
      </div>
      
      {/* Progress Modal */}
      <StakingProgressModal
        isOpen={showProgressModal}
        onClose={() => {
          setShowProgressModal(false);
          setIsStakeError(false);
          setIsStakeComplete(false);
        }}
        currentStep={currentStep}
        steps={progressSteps}
        txHash={currentTxHash as `0x${string}` | undefined}
        isComplete={isStakeComplete}
        isError={isStakeError}
        errorMessage={approvalError?.message || stakingError?.message}
      />
    </div>
  );
}
