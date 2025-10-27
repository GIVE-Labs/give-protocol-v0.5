import { useState, useEffect } from 'react';
import { useParams, Link } from 'react-router-dom';
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt, useBalance } from 'wagmi';
import { parseEther, parseUnits, formatUnits } from 'viem';
import { erc20Abi } from 'viem';
import { ArrowLeft, ChevronLeft, ChevronRight, Ban } from 'lucide-react';
import StakingProgressModal from '../components/staking/StakingProgressModal';
import CampaignTerminationModal from '../components/campaign/CampaignTerminationModal';
import { CONTRACT_ADDRESSES, MOCK_WETH, MOCK_USDC } from '../config/contracts';
import GiveVault4626ABIJson from '../abis/GiveVault4626.json';
import campaignRegistryABI from '../abis/CampaignRegistry.json';
import { hexToCid, fetchMetadataFromIPFS, getIPFSUrl } from '../services/ipfs';

const GiveVault4626ABI = (GiveVault4626ABIJson as any).abi || GiveVault4626ABIJson;

const STAKING_CONTRACT = (CONTRACT_ADDRESSES as any).VAULT || (CONTRACT_ADDRESSES as any).GIVE_WETH_VAULT;
const CAMPAIGN_REGISTRY_ADDRESS = (CONTRACT_ADDRESSES as any).CAMPAIGN_REGISTRY;
const WETH_ADDRESS = MOCK_WETH;
const USDC_ADDRESS = MOCK_USDC;

export default function CampaignDetails() {
  const { campaignId } = useParams<{ campaignId: string }>();
  const { address: userAddress } = useAccount();
  
  // State variables
  const [stakeAmount, setStakeAmount] = useState('');
  const [selectedToken, setSelectedToken] = useState('USDC');
  const [allocation, setAllocation] = useState('75%');
  const [activeTab, setActiveTab] = useState('overview');
  const [showProgressModal, setShowProgressModal] = useState(false);
  const [currentStep, setCurrentStep] = useState(0);
  const [isStakeComplete, setIsStakeComplete] = useState(false);
  const [isStakeError, setIsStakeError] = useState(false);
  const [currentTxHash, setCurrentTxHash] = useState<string | undefined>();
  const [currentImageIndex, setCurrentImageIndex] = useState(0);
  const [metadata, setMetadata] = useState<any>(null);
  const [isLoadingMetadata, setIsLoadingMetadata] = useState(false);
  
  // Termination modal state
  const [showTerminationModal, setShowTerminationModal] = useState(false);
  const [terminationStep, setTerminationStep] = useState(0);
  const [terminationTxHash, setTerminationTxHash] = useState<`0x${string}` | undefined>();
  const [isTerminationComplete, setIsTerminationComplete] = useState(false);
  const [isTerminationError, setIsTerminationError] = useState(false);
  const [terminationErrorMsg, setTerminationErrorMsg] = useState<string>('');
  
  const terminationSteps = [
    'Confirm Transaction',
    'Update Campaign Status',
    'Complete'
  ];
  
  // Check if connected wallet has campaign admin role via ACL
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
  
  // Debug: Log admin check
  useEffect(() => {
    if (userAddress) {
      console.log('👤 Connected wallet:', userAddress);
      console.log('🔑 Has admin role:', hasAdminRole);
      console.log('✅ Is campaign admin:', isCampaignAdmin);
    }
  }, [userAddress, hasAdminRole, isCampaignAdmin]);
  
  // Campaign data - using the hook instead of direct contract call
  const { data: campaignData } = useReadContract({
    address: CAMPAIGN_REGISTRY_ADDRESS as `0x${string}`,
    abi: campaignRegistryABI,
    functionName: 'getCampaign',
    args: campaignId ? [campaignId as `0x${string}`] : undefined,
    query: { enabled: !!campaignId }
  });
  
  // Fetch IPFS metadata when campaign data loads
  useEffect(() => {
    const loadMetadata = async () => {
      if (!campaignData) return;
      
      const campaign = campaignData as any;
      const metadataHash = campaign.metadataHash;
      
      if (!metadataHash || metadataHash === '0x0000000000000000000000000000000000000000000000000000000000000000') {
        return;
      }
      
      setIsLoadingMetadata(true);
      
      try {
        // Convert bytes32 to CID (pass campaignId to check localStorage or event logs)
        const cid = await hexToCid(metadataHash, campaignId || undefined);
        
        if (!cid) {
          return;
        }
        
        const data = await fetchMetadataFromIPFS(cid);
        
        if (data) {
          setMetadata(data);
        }
      } catch (error) {
        console.error('Error loading campaign metadata:', error);
      } finally {
        setIsLoadingMetadata(false);
      }
    };
    
    loadMetadata();
  }, [campaignData, campaignId]);
  
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
  
  // Campaign images - use metadata if available, fallback to mock images
  const campaignImages = metadata?.images?.length > 0 
    ? metadata.images.map((hash: string) => getIPFSUrl(hash))
    : [
        '/src/assets/IMG_4241.jpg',
        '/src/assets/IMG_5543.jpg',
        '/src/assets/IMG_5550.jpg'
      ];
  
  // Image carousel navigation
  const nextImage = () => {
    setCurrentImageIndex((prev) => (prev + 1) % campaignImages.length);
  };
  
  const prevImage = () => {
    setCurrentImageIndex((prev) => (prev - 1 + campaignImages.length) % campaignImages.length);
  };
  
  // Auto-advance carousel every 5 seconds
  useEffect(() => {
    if (campaignImages.length <= 1) return;
    
    const interval = setInterval(() => {
      nextImage();
    }, 5000);
    
    return () => clearInterval(interval);
  }, [campaignImages.length, currentImageIndex]);
  
  // Contract interactions
  const { data: allowance, refetch: refetchAllowance } = useReadContract({
    address: tokenAddress as `0x${string}`,
    abi: erc20Abi,
    functionName: 'allowance',
    args: userAddress && tokenAddress ? [userAddress, STAKING_CONTRACT as `0x${string}`] : undefined,
    query: { enabled: !!userAddress && !!tokenAddress && selectedToken !== 'ETH' },
  });
  
  const { writeContract: approveToken, data: approvalHash, isPending: isApproving } = useWriteContract();
  const { writeContract: depositTokens, data: depositHash, isPending: isDepositing } = useWriteContract();
  
  const { isLoading: isApprovalTx, isSuccess: isApprovalSuccess, isError: isApprovalError, error: approvalError } = useWaitForTransactionReceipt({
    hash: approvalHash,
  });
  
  const { isLoading: isDepositTx, isSuccess: isDepositSuccess, isError: isDepositError, error: depositError } = useWaitForTransactionReceipt({
    hash: depositHash,
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
    'Deposit to Vault',
    'Complete'
  ];
  
  // Mock campaign data
  const campaign = campaignData as any || {
    payoutRecipient: '0x0000000000000000000000000000000000000000',
    targetStake: 10000000000000000000n, // 10 ETH
    totalStaked: 3500000000000000000n, // 3.5 ETH
    status: 2 // Active
  };
  
  const targetAmount = Number(campaign.targetStake) / 1e18;
  const currentStaked = Number(campaign.totalStaked || 0) / 1e18;
  const progress = Math.min((currentStaked / targetAmount) * 100, 100);
  const mockSupporters = 850;
  const daysLeft = 20;
  
  // Calculate estimated yield
  const estimatedYield = amountToStake * 0.10; // 10% APY
  const yieldToCampaign = estimatedYield * (parseInt(allocation) / 100);
  const yieldToUser = estimatedYield - yieldToCampaign;
  
  const executeDeposit = async () => {
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
        await depositTokens({
          address: STAKING_CONTRACT as `0x${string}`,
          abi: GiveVault4626ABI,
          functionName: 'deposit',
          args: [amountInWei, userAddress],
        });
      }
    } catch (error) {
      console.error('Deposit error:', error);
      setIsStakeError(true);
    }
  };
  
  const handlePrimaryAction = () => {
    executeDeposit();
  };
  
  // Effects for transaction handling
  useEffect(() => {
    if (isApprovalSuccess && needsApproval) {
      setCurrentStep(1);
      setCurrentTxHash(approvalHash);
      refetchAllowance();
      
      setTimeout(() => {
        executeDeposit();
      }, 1000);
    }
    
    if (isApprovalError) {
      setIsStakeError(true);
    }
  }, [isApprovalSuccess, isApprovalError, approvalHash]);
  
  useEffect(() => {
    if (isDepositSuccess) {
      setCurrentStep(2);
      setCurrentTxHash(depositHash);
      setIsStakeComplete(true);
      setStakeAmount('');
      refetchEthBalance();
      refetchWethBalance();
      refetchUsdcBalance();
    }
    
    if (isDepositError) {
      setIsStakeError(true);
    }
  }, [isDepositSuccess, isDepositError, depositHash]);
  
  const isLoading = isApproving || isDepositing || isApprovalTx || isDepositTx;
  const buttonText = isLoading ? 'Processing...' : needsApproval ? 'Approve & Deposit' : 'Deposit Now';
  
  // Terminate campaign (admin only)
  const { writeContract: terminateCampaign, data: terminateHash, isPending: isTerminatePending } = useWriteContract();
  
  const { 
    isLoading: isTerminateTx, 
    isSuccess: isTerminateSuccess, 
    isError: isTerminateTxError,
    error: terminateTxError 
  } = useWaitForTransactionReceipt({
    hash: terminateHash,
  });
  
  // Handle termination transaction states
  useEffect(() => {
    if (terminateHash) {
      setTerminationTxHash(terminateHash);
      setTerminationStep(1);
    }
  }, [terminateHash]);
  
  useEffect(() => {
    if (isTerminateSuccess) {
      setTerminationStep(2);
      setIsTerminationComplete(true);
    }
  }, [isTerminateSuccess]);
  
  useEffect(() => {
    if (isTerminateTxError && terminateTxError) {
      setIsTerminationError(true);
      
      let errorMessage = 'Failed to terminate campaign';
      const fullError = terminateTxError.message || '';
      
      if (fullError.includes('User rejected') || fullError.includes('User denied')) {
        errorMessage = 'Transaction was rejected by user';
      } else if (fullError.includes('insufficient funds')) {
        errorMessage = 'Insufficient funds for gas fee';
      } else if (fullError.includes('Unauthorized')) {
        errorMessage = 'You do not have permission to terminate this campaign';
      } else {
        const revertMatch = fullError.match(/reverted with reason string '([^']+)'/);
        if (revertMatch) {
          errorMessage = `Contract error: ${revertMatch[1]}`;
        }
      }
      
      setTerminationErrorMsg(errorMessage);
    }
  }, [isTerminateTxError, terminateTxError]);
  
  const handleTerminateCampaign = async () => {
    if (!campaignId) return;
    
    try {
      setTerminationStep(0);
      setIsTerminationError(false);
      setIsTerminationComplete(false);
      setTerminationErrorMsg('');
      setShowTerminationModal(true);
    } catch (error) {
      console.error('Error opening termination modal:', error);
    }
  };
  
  const executeTermination = async () => {
    if (!campaignId) return;
    
    try {
      setTerminationStep(1);
      
      await terminateCampaign({
        address: CAMPAIGN_REGISTRY_ADDRESS as `0x${string}`,
        abi: campaignRegistryABI,
        functionName: 'setCampaignStatus',
        args: [campaignId as `0x${string}`, 6], // 6 = Cancelled
      });
    } catch (error) {
      console.error('Error terminating campaign:', error);
      setIsTerminationError(true);
      
      let errorMessage = 'Failed to terminate campaign';
      const fullError = error instanceof Error ? error.message : '';
      
      if (fullError.includes('User rejected') || fullError.includes('User denied')) {
        errorMessage = 'Transaction was rejected by user';
      } else if (fullError.includes('insufficient funds')) {
        errorMessage = 'Insufficient funds for gas fee';
      }
      
      setTerminationErrorMsg(errorMessage);
    }
  };
  
  const closeTerminationModal = () => {
    setShowTerminationModal(false);
    setTerminationStep(0);
    setTerminationTxHash(undefined);
    setIsTerminationComplete(false);
    setIsTerminationError(false);
    setTerminationErrorMsg('');
  };
  
  return (
    <div className="min-h-screen bg-gradient-to-br from-emerald-50 via-cyan-50 to-teal-50 relative overflow-hidden">
      {/* Animated Background Elements */}
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        <div className="absolute top-20 left-10 w-32 h-32 bg-gradient-to-r from-emerald-200/30 to-cyan-200/30 rounded-full blur-xl" />
        <div className="absolute top-40 right-20 w-24 h-24 bg-gradient-to-r from-teal-200/30 to-blue-200/30 rounded-full blur-xl" />
        <div className="absolute bottom-20 left-1/3 w-40 h-40 bg-gradient-to-r from-blue-200/20 to-purple-200/20 rounded-full blur-2xl" />
      </div>
      
      {/* Hero Section with Image Carousel */}
      <div className="relative bg-gradient-to-r from-emerald-600 via-teal-600 to-cyan-600">
        {/* Back Button */}
        <div className="absolute top-4 left-4 z-20">
          <Link
            to="/campaigns"
            className="inline-flex items-center text-white hover:text-white/90 font-semibold transition-colors font-unbounded bg-black/30 backdrop-blur-md px-3 py-2 rounded-lg hover:bg-black/40"
          >
            <ArrowLeft className="w-4 h-4 mr-2" />
            Back
          </Link>
        </div>

        {/* Image Carousel with Overlay Text */}
        <div className="relative h-96 overflow-hidden">
          <div className="absolute inset-0 flex items-center justify-center bg-black/5">
            <img 
              key={`campaign-image-${currentImageIndex}-${campaignImages[currentImageIndex]}`}
              src={campaignImages[currentImageIndex]} 
              alt="Campaign"
              className="max-h-full max-w-full object-contain transition-all duration-500"
            />
            
            {/* Preload other images */}
            {campaignImages.map((imgUrl: string, idx: number) => (
              idx !== currentImageIndex && (
                <link key={`preload-${idx}`} rel="preload" as="image" href={imgUrl} />
              )
            ))}
            
            {/* Strong gradient overlay at bottom for text */}
            <div className="absolute inset-0 bg-gradient-to-t from-black/70 via-black/20 to-transparent pointer-events-none" />
            
            {/* Compact Carousel Navigation */}
            {campaignImages.length > 1 && (
              <>
                <button
                  onClick={prevImage}
                  className="absolute left-3 top-1/2 transform -translate-y-1/2 bg-white/80 hover:bg-white text-gray-900 p-2 rounded-full transition-all duration-200 z-10 shadow-lg"
                >
                  <ChevronLeft className="w-5 h-5" />
                </button>
                <button
                  onClick={nextImage}
                  className="absolute right-3 top-1/2 transform -translate-y-1/2 bg-white/80 hover:bg-white text-gray-900 p-2 rounded-full transition-all duration-200 z-10 shadow-lg"
                >
                  <ChevronRight className="w-5 h-5" />
                </button>
                
                {/* Image Indicators - Hidden (auto-play enabled) */}
              </>
            )}
          </div>

          {/* Campaign Info - Overlaid on Image */}
          <div className="absolute bottom-0 left-0 right-0 px-6 py-6 max-w-7xl mx-auto z-10">
            <div className="flex flex-wrap items-center gap-2 mb-3">
              <span className="bg-white/90 backdrop-blur-sm text-emerald-700 px-2.5 py-1 rounded-full text-xs font-semibold flex items-center shadow-lg">
                <svg className="w-3 h-3 mr-1" fill="currentColor" viewBox="0 0 20 20">
                  <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
                </svg>
                Verified
              </span>
              {metadata?.category && (
                <span className="bg-white/90 backdrop-blur-sm text-teal-700 px-2.5 py-1 rounded-full text-xs font-semibold shadow-lg">
                  {metadata.category}
                </span>
              )}
            </div>
            
            <h1 className="text-3xl md:text-4xl font-bold font-unbounded mb-3 leading-tight text-white drop-shadow-lg">
              {metadata?.name || 'Loading Campaign...'}
            </h1>
            
            <p className="text-base md:text-lg font-medium leading-relaxed text-white/95 max-w-4xl drop-shadow-md">
              {metadata?.mission || 'Supporting sustainable impact through no-loss giving'}
            </p>
          </div>
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
                  <h2 className="text-3xl font-bold text-gray-900">{currentStaked.toFixed(2)} ETH</h2>
                  <p className="text-gray-600">of {targetAmount.toFixed(2)} ETH target amount</p>
                </div>
                <div className="text-right">
                  <div className="text-2xl font-bold text-gray-900">{mockSupporters}</div>
                  <div className="text-sm text-gray-600">Backers</div>
                </div>
              </div>
              
              <div className="w-full bg-gray-200 rounded-full h-3 mb-4">
                <div 
                  className="bg-gradient-to-r from-emerald-500 to-teal-500 h-3 rounded-full transition-all duration-300"
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
                      {tab === 'comments' && ' (0)'}
                    </button>
                  ))}
                </nav>
              </div>
              
              <div className="p-6">
                {activeTab === 'overview' && (
                  <div className="space-y-6">
                    <div>
                      <h3 className="text-lg font-semibold text-gray-900 mb-3 font-unbounded">About This Campaign</h3>
                      {isLoadingMetadata ? (
                        <div className="flex items-center justify-center py-8">
                          <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-emerald-500"></div>
                        </div>
                      ) : (
                        <p className="text-gray-700 leading-relaxed mb-4 font-medium">
                          {metadata?.description || 'This campaign is dedicated to creating sustainable impact through no-loss giving. Donors deposit principal into yield-generating vaults, and the generated returns stream to this campaign without touching the principal.'}
                        </p>
                      )}
                    </div>
                    
                    {metadata?.teamMembers && metadata.teamMembers.length > 0 && (
                      <div>
                        <h3 className="text-lg font-semibold text-gray-900 mb-3 font-unbounded">Team Members</h3>
                        <div className="space-y-3">
                          {metadata.teamMembers.map((member: any, idx: number) => (
                            <div key={idx} className="bg-gray-50 rounded-lg p-4">
                              <div className="font-semibold text-gray-900">{member.name}</div>
                              <div className="text-sm text-emerald-600 mb-2">{member.role}</div>
                              {member.bio && <div className="text-sm text-gray-600">{member.bio}</div>}
                            </div>
                          ))}
                        </div>
                      </div>
                    )}
                    
                    {metadata?.impactMetrics && metadata.impactMetrics.length > 0 && (
                      <div>
                        <h3 className="text-lg font-semibold text-gray-900 mb-3 font-unbounded">Impact Goals</h3>
                        <div className="space-y-3">
                          {metadata.impactMetrics.map((metric: any, idx: number) => (
                            <div key={idx} className="bg-gradient-to-r from-emerald-50 to-teal-50 rounded-lg p-4">
                              <div className="font-semibold text-gray-900">{metric.name}</div>
                              <div className="text-sm text-emerald-700 font-medium">Target: {metric.target}</div>
                              {metric.description && <div className="text-sm text-gray-600 mt-1">{metric.description}</div>}
                            </div>
                          ))}
                        </div>
                      </div>
                    )}
                    
                    {metadata?.category && (
                      <div>
                        <h3 className="text-lg font-semibold text-gray-900 mb-3 font-unbounded">Focus Areas</h3>
                        <div className="flex flex-wrap gap-2">
                          <span className="bg-gradient-to-r from-emerald-100 to-teal-100 text-emerald-800 px-3 py-1 rounded-full text-sm font-medium">
                            {metadata.category}
                          </span>
                        </div>
                      </div>
                    )}
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
          
          {/* Right Column - Deposit Form */}
          <div className="lg:col-span-1">
            <div className="bg-white/80 backdrop-blur-sm rounded-2xl shadow-xl border border-white/20 p-6 sticky top-8">
              <h3 className="text-xl font-bold text-gray-900 mb-6 font-unbounded">Support This Campaign</h3>
              
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
              
              {/* Allocation */}
              <div className="mb-6">
                <label className="block text-sm font-medium text-gray-700 mb-2">Yield allocation to campaign</label>
                <div className="grid grid-cols-3 gap-2">
                  {['50%', '75%', '100%'].map((ratio) => (
                    <button
                      key={ratio}
                      onClick={() => setAllocation(ratio)}
                      className={`px-3 py-2 rounded-lg text-sm font-medium transition-colors ${
                        allocation === ratio
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
                      <span className="text-gray-600">Deposit Amount:</span>
                      <span className="font-medium">{stakeAmount} {selectedToken}</span>
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
                        <span>To Campaign ({allocation}):</span>
                        <span className="font-medium">{yieldToCampaign.toFixed(4)} {selectedToken}</span>
                      </div>
                      <div className="flex justify-between text-teal-600">
                        <span>To You ({100 - parseInt(allocation)}%):</span>
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
              
              {/* Deposit Button */}
              <button
                onClick={handlePrimaryAction}
                disabled={!stakeAmount || parseFloat(stakeAmount) <= 0 || isLoading || !userAddress}
                className="w-full bg-gradient-to-r from-emerald-600 to-teal-600 text-white py-3 px-4 rounded-lg font-semibold hover:from-emerald-700 hover:to-teal-700 disabled:bg-gray-300 disabled:cursor-not-allowed transition-all duration-200 shadow-lg hover:shadow-xl transform hover:-translate-y-0.5 font-unbounded"
              >
                {buttonText}
              </button>
              
              {/* Admin: Terminate Campaign Button */}
              {isCampaignAdmin && (
                <button
                  onClick={handleTerminateCampaign}
                  className="w-full mt-3 bg-gradient-to-r from-red-600 to-red-700 text-white py-3 px-4 rounded-lg font-semibold hover:from-red-700 hover:to-red-800 transition-all duration-200 shadow-lg hover:shadow-xl flex items-center justify-center gap-2"
                >
                  <Ban className="w-5 h-5" />
                  Terminate Campaign
                </button>
              )}
              
              <p className="text-xs text-gray-500 text-center mt-3">
                Secure payment via smart contract
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
        errorMessage={approvalError?.message || depositError?.message}
      />
      
      {/* Termination Modal */}
      <CampaignTerminationModal
        isOpen={showTerminationModal}
        onClose={closeTerminationModal}
        onConfirm={executeTermination}
        currentStep={terminationStep}
        steps={terminationSteps}
        txHash={terminationTxHash}
        isComplete={isTerminationComplete}
        isError={isTerminationError}
        errorMessage={terminationErrorMsg}
        isPending={isTerminatePending || isTerminateTx}
      />
    </div>
  );
}
