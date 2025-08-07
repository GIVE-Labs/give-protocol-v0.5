import { useState, useEffect, useMemo, useCallback } from 'react';
import { useParams } from 'react-router-dom';
import { useNGORegistry } from '../hooks/useNGORegistryWagmi';
import { useAccount, useBalance, useWriteContract, useWaitForTransactionReceipt, useReadContract } from 'wagmi';
import { formatUnits, parseUnits } from 'viem';
import { NGO } from '../types';
import StakingProgressModal from '../components/staking/StakingProgressModal';

// Contract addresses
const STAKING_CONTRACT = '0xE05473424Df537c9934748890d3D8A5b549da1C0';
const WETH_ADDRESS = '0x81F5c69b5312aD339144489f2ea5129523437bdC';
const USDC_ADDRESS = '0x44F38B49ddaAE53751BEEb32Eb3b958d950B26e6';
const CONTRACT_ADDRESS = '0x724dc0c1AE0d8559C48D0325Ff4cC8F45FE703De'; // NGORegistry

export default function NGODetails() {
  const { address } = useParams();
  const [stakeAmount, setStakeAmount] = useState('');
  const [selectedToken, setSelectedToken] = useState<'ETH' | 'WETH' | 'USDC'>('USDC');
  const [lockPeriod, setLockPeriod] = useState<'6m' | '1y' | '2y'>('1y');
  const [yieldShare, setYieldShare] = useState<'50%' | '75%' | '100%'>('50%');
  const { address: userAddress } = useAccount();
  
  const ngoHook = useNGORegistry(CONTRACT_ADDRESS);
  const [ngo, setNgo] = useState<NGO | null>(null);
  const [loading, setLoading] = useState(true);

  const [showProgressModal, setShowProgressModal] = useState(false);
  const [currentStep, setCurrentStep] = useState(0);
  const [progressSteps, setProgressSteps] = useState<string[]>([]);
  const [isStakeComplete, setIsStakeComplete] = useState(false);
  const [isStakeError, setIsStakeError] = useState(false);
  const [currentTxHash, setCurrentTxHash] = useState<`0x${string}` | undefined>();

  const { writeContract: approveToken, data: approveHash, isPending: isApproving } = useWriteContract();
  const { writeContract: stakeTokens, data: stakeHash, isPending: isStaking } = useWriteContract();

  const { isSuccess: isApprovalSuccess, isError: isApprovalError, error: approvalError } = useWaitForTransactionReceipt({ hash: approveHash });
  const { isLoading: isStakingTx, isSuccess: isStakingSuccess, isError: isStakingError, error: stakingError } = useWaitForTransactionReceipt({ hash: stakeHash });

  const amountToStake = stakeAmount ? parseUnits(stakeAmount, selectedToken === 'USDC' ? 6 : 18) : 0n;

  const tokenAddress = useMemo(() => {
    if (selectedToken === 'WETH') return WETH_ADDRESS;
    if (selectedToken === 'USDC') return USDC_ADDRESS;
    return undefined;
  }, [selectedToken]);

  const { data: allowance, refetch: refetchAllowance, isLoading: isAllowanceLoading } = useReadContract({
    address: tokenAddress as `0x${string}`,
    abi: [{
      name: 'allowance', type: 'function', stateMutability: 'view',
      inputs: [{ name: 'owner', type: 'address' }, { name: 'spender', type: 'address' }],
      outputs: [{ name: '', type: 'uint256' }]
    }],
    functionName: 'allowance',
    args: userAddress && tokenAddress ? [userAddress, STAKING_CONTRACT as `0x${string}`] : undefined,
    query: { enabled: !!userAddress && !!tokenAddress },
  });

  const needsApproval = useMemo(() => {
    if (selectedToken === 'ETH' || allowance === undefined || !stakeAmount || amountToStake === 0n) return false;
    const needs = amountToStake > allowance;
    console.log('Allowance check debug:', {
      selectedToken,
      allowance: allowance?.toString(),
      amountToStake: amountToStake?.toString(),
      needsApproval: needs,
      rawComparison: `${amountToStake} > ${allowance} = ${amountToStake > allowance}`,
      typeCheck: {
        allowanceType: typeof allowance,
        amountToStakeType: typeof amountToStake
      }
    });
    return needs;
  }, [allowance, amountToStake, selectedToken, stakeAmount]);

  const { data: ethBalance, refetch: refetchEthBalance } = useBalance({ address: userAddress });
  const { data: wethBalance, refetch: refetchWethBalance } = useBalance({ address: userAddress, token: WETH_ADDRESS as `0x${string}` });
  const { data: usdcBalance, refetch: refetchUsdcBalance } = useBalance({ address: userAddress, token: USDC_ADDRESS as `0x${string}` });

  const getBalance = () => {
    switch (selectedToken) {
      case 'ETH': return ethBalance;
      case 'WETH': return wethBalance;
      case 'USDC': return usdcBalance;
      default: return ethBalance;
    }
  };

  const currentBalance = getBalance();
  const formattedBalance = currentBalance ? formatUnits(currentBalance.value, currentBalance.decimals) : '0';

  useEffect(() => {
    const loadNGO = async () => {
      if (address) {
        setLoading(true);
        try {
          const ngoData = await ngoHook.fetchNGOByAddress(address);
          setNgo(ngoData);
        } catch (error) {
          console.error('Error loading NGO:', error);
        } finally {
          setLoading(false);
        }
      }
    };
    loadNGO();
  }, [address]);

  const executeStake = useCallback(() => {
    if (!ngo || !userAddress) return;

    let lockDuration = 0;
    if (lockPeriod === '6m') lockDuration = 180 * 24 * 60 * 60; // 180 days = 6 months
    if (lockPeriod === '1y') lockDuration = 365 * 24 * 60 * 60; // 365 days = 1 year
    if (lockPeriod === '2y') lockDuration = 730 * 24 * 60 * 60; // 730 days = 2 years

    const yieldShareBP = parseInt(yieldShare.replace('%', '')) * 100;
    const tokenAddress = selectedToken === 'ETH' ? '0x0000000000000000000000000000000000000000' : 
                         selectedToken === 'WETH' ? WETH_ADDRESS : USDC_ADDRESS;

    try {
      stakeTokens({
        address: STAKING_CONTRACT as `0x${string}`,
        abi: [{
          name: 'stake', type: 'function', stateMutability: 'payable',
          inputs: [{ name: 'ngoAddress', type: 'address' }, { name: 'token', type: 'address' }, { name: 'amount', type: 'uint256' }, { name: 'lockDuration', type: 'uint256' }, { name: 'yieldShareBP', type: 'uint256' }],
          outputs: []
        }],
        functionName: 'stake',
        args: [ngo.ngoAddress as `0x${string}`, tokenAddress as `0x${string}`, amountToStake, BigInt(lockDuration), BigInt(yieldShareBP)],
        value: selectedToken === 'ETH' ? amountToStake : 0n
      });
    } catch (error) {
      console.error('Error in executeStake:', error);
      setShowProgressModal(false);
    }
  }, [amountToStake, lockPeriod, ngo, selectedToken, stakeTokens, userAddress, yieldShare]);

  const handlePrimaryAction = async () => {
    if (!stakeAmount || parseFloat(stakeAmount) <= 0 || !userAddress || !ngo) return;

    console.log('handlePrimaryAction - needsApproval:', needsApproval, 'for amount:', amountToStake.toString());
    const yieldShareBP = parseInt(yieldShare.replace('%', '')) * 100;
    let lockDuration = 0;
    if (lockPeriod === '6m') lockDuration = 180 * 24 * 60 * 60;
    if (lockPeriod === '1y') lockDuration = 365 * 24 * 60 * 60;
    if (lockPeriod === '2y') lockDuration = 730 * 24 * 60 * 60;

    console.log('Staking parameters:', {
      ngoAddress: ngo.ngoAddress,
      tokenAddress,
      amount: amountToStake.toString(),
      lockDuration: lockDuration.toString(),
      yieldShareBP: yieldShareBP.toString(),
      selectedToken,
      lockPeriod,
      yieldShare
    });

    if (needsApproval) {
      setProgressSteps(['Approve Token', 'Stake Tokens']);
      setCurrentStep(0);
      setShowProgressModal(true);
      setIsStakeError(false);
      setIsStakeComplete(false);
      const tokenAddress = selectedToken === 'WETH' ? WETH_ADDRESS : USDC_ADDRESS;
      try {
        approveToken({
          address: tokenAddress as `0x${string}`,
          abi: [{
            name: 'approve', type: 'function', stateMutability: 'nonpayable',
            inputs: [{ name: 'spender', type: 'address' }, { name: 'amount', type: 'uint256' }],
            outputs: [{ name: '', type: 'bool' }]
          }],
          functionName: 'approve',
          args: [STAKING_CONTRACT as `0x${string}`, amountToStake]
        });
      } catch (error) {
        console.error('Error in approval:', error);
        setIsStakeError(true);
      }
    } else {
      console.log('Skipping approval, executing stake directly');
      setProgressSteps(['Stake Tokens']);
      setCurrentStep(0);
      setShowProgressModal(true);
      setIsStakeError(false);
      setIsStakeComplete(false);
      executeStake();
    }
  };

  useEffect(() => {
    if (isApprovalSuccess) {
      refetchAllowance();
      setCurrentStep(1);
      executeStake();
    } else if (isApprovalError) {
      setIsStakeError(true);
    }
  }, [isApprovalSuccess, isApprovalError, refetchAllowance, executeStake]);

  useEffect(() => {
    if (isStakingTx) {
      setCurrentTxHash(stakeHash);
    }
    if (isStakingSuccess) {
      refetchEthBalance();
      refetchWethBalance();
      refetchUsdcBalance();
      setIsStakeComplete(true);
      setIsStakeError(false);
    } else if (isStakingError) {
      setIsStakeComplete(false);
      setIsStakeError(true);
    }
  }, [isStakingTx, isStakingSuccess, isStakingError, stakeHash, refetchEthBalance, refetchWethBalance, refetchUsdcBalance]);

  useEffect(() => {
    console.log('Allowance updated:', allowance?.toString(), 'for token:', selectedToken, 'needs approval:', needsApproval);
  }, [allowance, selectedToken, needsApproval]);

  useEffect(() => {
    if (userAddress && tokenAddress) {
      refetchAllowance();
    }
  }, [tokenAddress, userAddress, refetchAllowance]);

  const targetAmount = ngo?.category === 'Education' ? 500000 : ngo?.category === 'Environment' ? 400000 : ngo?.category === 'Health' ? 600000 : 300000;
  const currentStaked = Number(ngo?.totalStakers || 0) * 1500;
  const progress = Math.min((currentStaked / targetAmount) * 100, 100);

  const isLoading = isApproving || isStaking || (isAllowanceLoading && amountToStake > 0);
  const buttonText = isLoading 
    ? 'Processing...' 
    : isAllowanceLoading
      ? 'Checking Allowance...'
      : needsApproval 
        ? 'Approve & Stake' 
        : 'Stake Now';

  if (loading) return <div className="text-center py-12">Loading...</div>;
  if (!ngo) return <div className="text-center py-12">NGO Not Found</div>;

  return (
    <>
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
          <div className="lg:col-span-2">{/* NGO Info */}
            <div className="mb-4"><span className="bg-yellow-100 text-yellow-800 px-3 py-1 rounded-full text-sm font-medium">{ngo.category}</span></div>
            <div className="relative h-96 rounded-xl overflow-hidden mb-6">
              <img src={ngo.logoURI} alt={ngo.name} className="w-full h-full object-cover" />
              <div className="absolute inset-0 bg-gradient-to-t from-black/60 to-transparent" />
              <div className="absolute bottom-6 left-6 text-white"><h1 className="text-4xl font-bold mb-2">{ngo.name}</h1><p className="text-xl opacity-90">{ngo.description}</p></div>
            </div>
            <div className="bg-white rounded-xl shadow-lg p-6 mb-6">
              <div className="flex items-center justify-between mb-4">
                <div className="flex items-center space-x-3">
                  <img src={ngo.logoURI} alt={ngo.name} className="w-16 h-16 rounded-lg object-cover" />
                  <div><h2 className="text-2xl font-bold text-gray-900">{ngo.name}</h2><div className="flex items-center space-x-2"><span className="bg-green-100 text-green-800 px-2 py-1 rounded-full text-xs font-medium flex items-center"><svg className="w-3 h-3 mr-1" fill="currentColor" viewBox="0 0 20 20"><path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" /></svg>Verified NGO</span></div></div>
                </div>
                <div className="flex space-x-2"><a href={ngo.website} target="_blank" rel="noopener noreferrer" className="p-2 rounded-lg bg-gray-100 hover:bg-gray-200 transition-colors"><svg className="w-5 h-5 text-gray-600" fill="currentColor" viewBox="0 0 20 20"><path fillRule="evenodd" d="M4.083 9h1.946c.089-1.546.383-2.97.837-4.118A6.004 6.004 0 004.083 9zM10 2a8 8 0 100 16 8 8 0 000-16zm0 2c-.076 0-.232.032-.465.262-.238.234-.497.623-.737 1.182-.389.907-.673 2.142-.766 3.556h3.936c-.093-1.414-.377-2.649-.766-3.556-.24-.559-.5-.948-.737-1.182C10.232 4.032 10.076 4 10 4zm3.971 5c-.089-1.546-.383-2.97-.837-4.118A6.004 6.004 0 0115.917 9h-1.946zm-2.003 2H8.032c.093 1.414.377 2.649.766 3.556.24.559.5.948.737 1.182.233.23.389.262.465.262.076 0 .232-.032.465-.262.238-.234.498-.623.737-1.182.389-.907.673-2.142.766-3.556zm1.166 4.118c.454-1.147.748-2.572.837-4.118h1.946a6.004 6.004 0 01-2.783 4.118zm-6.268 0C6.412 13.97 6.118 12.546 6.03 11H4.083a6.004 6.004 0 002.783 4.118z" clipRule="evenodd" /></svg></a></div>
              </div>
              <div className="mb-4"><h3 className="text-lg font-semibold text-gray-900 mb-2">Focus Areas</h3><div className="flex flex-wrap gap-2">{ngo.causes.map((cause) => (<span key={cause} className="bg-purple-100 text-purple-800 px-3 py-1 rounded-full text-sm">{cause}</span>))}</div></div>
              <p className="text-gray-700 leading-relaxed mb-4">{ngo.name} is dedicated to creating sustainable impact in {ngo.location.toLowerCase()}. Through innovative programs and community-driven solutions, we work tirelessly to address critical social issues and create lasting positive change.</p>
            </div>
          </div>
          <div className="lg:col-span-1">
            <div className="bg-white rounded-xl shadow-lg p-6 sticky top-8">
              <h3 className="text-2xl font-bold text-gray-900 mb-6">Support This Campaign</h3>
              <div className="mb-6">
                <div className="flex justify-between items-baseline mb-2"><span className="text-3xl font-bold text-gray-900">${currentStaked.toLocaleString()}</span><span className="text-sm text-gray-600">of ${targetAmount.toLocaleString()}</span></div>
                <div className="w-full bg-gray-200 rounded-full h-2 mb-2"><div className="bg-green-500 h-2 rounded-full transition-all duration-300" style={{ width: `${progress}%` }} /></div>
                <p className="text-sm text-gray-600">target staked amount</p>
              </div>
              <div className="flex justify-center mb-6 pb-6 border-b"><div className="text-center"><div className="text-2xl font-bold text-gray-900">{Number(ngo.totalStakers)}</div><div className="text-sm text-gray-600">Backers</div></div></div>
              <div className="mb-6">
                <label className="block text-sm font-medium text-gray-700 mb-2">Token</label>
                <div className="grid grid-cols-3 gap-2">
                  <button onClick={() => setSelectedToken('ETH')} className={`px-4 py-2 rounded-lg font-medium transition-colors ${selectedToken === 'ETH' ? 'bg-purple-600 text-white' : 'bg-gray-100 text-gray-700 hover:bg-gray-200'}`}>ETH</button>
                  <button onClick={() => setSelectedToken('WETH')} className={`px-4 py-2 rounded-lg font-medium transition-colors ${selectedToken === 'WETH' ? 'bg-purple-600 text-white' : 'bg-gray-100 text-gray-700 hover:bg-gray-200'}`}>WETH</button>
                  <button onClick={() => setSelectedToken('USDC')} className={`px-4 py-2 rounded-lg font-medium transition-colors ${selectedToken === 'USDC' ? 'bg-purple-600 text-white' : 'bg-gray-100 text-gray-700 hover:bg-gray-200'}`}>USDC</button>
                </div>
              </div>
              <div className="mb-6">
                <div className="flex justify-between items-center mb-2"><label className="block text-sm font-medium text-gray-700">Amount</label><div className="text-sm text-gray-600">Balance: {parseFloat(formattedBalance).toFixed(selectedToken === 'USDC' ? 2 : 4)} {selectedToken}</div></div>
                <div className="relative"><input type="number" value={stakeAmount} onChange={(e) => setStakeAmount(e.target.value)} placeholder={`Enter amount (${selectedToken})`} className="w-full px-4 py-2 pr-16 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-transparent" step="any" /><button onClick={() => setStakeAmount(formattedBalance)} className="absolute right-2 top-1/2 transform -translate-y-1/2 px-3 py-1 text-sm font-medium text-purple-600 bg-purple-100 rounded hover:bg-purple-200 transition-colors">MAX</button></div>
              </div>
              <div className="mb-6">
                <label className="block text-sm font-medium text-gray-700 mb-2">Lock-in Period</label>
                <div className="grid grid-cols-3 gap-2">
                  <button onClick={() => setLockPeriod('6m')} className={`px-3 py-2 rounded-lg text-sm font-medium transition-colors ${lockPeriod === '6m' ? 'bg-purple-600 text-white' : 'bg-gray-100 text-gray-700 hover:bg-gray-200'}`}>6 Months</button>
                  <button onClick={() => setLockPeriod('1y')} className={`px-3 py-2 rounded-lg text-sm font-medium transition-colors ${lockPeriod === '1y' ? 'bg-purple-600 text-white' : 'bg-gray-100 text-gray-700 hover:bg-gray-200'}`}>1 Year</button>
                  <button onClick={() => setLockPeriod('2y')} className={`px-3 py-2 rounded-lg text-sm font-medium transition-colors ${lockPeriod === '2y' ? 'bg-purple-600 text-white' : 'bg-gray-100 text-gray-700 hover:bg-gray-200'}`}>2 Years</button>
                </div>
              </div>
              <div className="mb-6">
                <label className="block text-sm font-medium text-gray-700 mb-2">Yield Contribution</label>
                <div className="grid grid-cols-3 gap-2">
                  <button onClick={() => setYieldShare('50%')} className={`px-3 py-2 rounded-lg text-sm font-medium transition-colors ${yieldShare === '50%' ? 'bg-green-600 text-white' : 'bg-gray-100 text-gray-700 hover:bg-gray-200'}`}>50%</button>
                  <button onClick={() => setYieldShare('75%')} className={`px-3 py-2 rounded-lg text-sm font-medium transition-colors ${yieldShare === '75%' ? 'bg-green-600 text-white' : 'bg-gray-100 text-gray-700 hover:bg-gray-200'}`}>75%</button>
                  <button onClick={() => setYieldShare('100%')} className={`px-3 py-2 rounded-lg text-sm font-medium transition-colors ${yieldShare === '100%' ? 'bg-green-600 text-white' : 'bg-gray-100 text-gray-700 hover:bg-gray-200'}`}>100%</button>
                </div>
              </div>
              <button onClick={handlePrimaryAction} disabled={!stakeAmount || parseFloat(stakeAmount) <= 0 || isLoading || !userAddress} className="w-full bg-green-600 text-white py-3 px-4 rounded-lg font-semibold hover:bg-green-700 disabled:bg-gray-300 disabled:cursor-not-allowed transition-colors">{buttonText}</button>
              <p className="text-xs text-gray-500 text-center mt-3">Secure payment via smart contract • Principal remains yours</p>
            </div>
          </div>
        </div>
      </div>
      <StakingProgressModal
        isOpen={showProgressModal}
        onClose={() => {
          setShowProgressModal(false);
          setIsStakeError(false);
          setIsStakeComplete(false);
        }}
        currentStep={currentStep}
        steps={progressSteps}
        txHash={currentTxHash}
        isComplete={isStakeComplete}
        isError={isStakeError}
        errorMessage={approvalError?.message || stakingError?.message}
      />
    </>
  );
}
