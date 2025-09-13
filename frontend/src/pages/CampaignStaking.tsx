import { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { useAccount, useReadContract } from 'wagmi';
import { formatUnits, parseEther } from 'viem';
import { NGO_REGISTRY_ABI } from '../abis/NGORegistry';

import { CONTRACT_ADDRESSES } from '../config/contracts';
import { NGO } from '../types';
import StakingForm from '../components/staking/StakingForm';
import Button from '../components/ui/Button';

interface CampaignStats {
  totalStaked: bigint;
  currentAPY: number;
  estimatedYield: number;
  lockPeriods: number[];
  supportedTokens: string[];
}

export default function CampaignStaking() {
  const { ngoAddress } = useParams<{ ngoAddress: string }>();
  const navigate = useNavigate();
  const { address } = useAccount();
  const [showStakingForm, setShowStakingForm] = useState(false);
  const [selectedAmount, setSelectedAmount] = useState('');
  const [selectedLockPeriod, setSelectedLockPeriod] = useState(12);
  const [selectedContributionRate, setSelectedContributionRate] = useState(75);

  // Fetch NGO information
  const { data: ngoInfo, isLoading: loadingNGO } = useReadContract({
    address: CONTRACT_ADDRESSES.NGO_REGISTRY,
    abi: NGO_REGISTRY_ABI,
    functionName: 'getNGOInfo',
    args: [ngoAddress as `0x${string}`],
    query: {
      enabled: !!ngoAddress,
    },
  });

  // Removed staking contract call - no longer using MORPH_IMPACT_STAKING
  const totalStaked = BigInt(0);

  // Calculate APY and yield estimates
  const calculateAPY = (lockPeriod: number): number => {
    // Base APY calculation - this would typically come from the vault/adapter
    const baseAPY = 5.0; // 5% base APY
    const lockMultiplier = lockPeriod === 6 ? 1.0 : lockPeriod === 12 ? 1.2 : 1.5;
    return baseAPY * lockMultiplier;
  };

  const calculateEstimatedYield = (amount: string, lockPeriod: number, contributionRate: number) => {
    if (!amount || parseFloat(amount) <= 0) return { userYield: 0, ngoYield: 0, totalYield: 0 };
    
    const principal = parseFloat(amount);
    const apy = calculateAPY(lockPeriod);
    const totalYield = principal * (apy / 100) * (lockPeriod / 12);
    const ngoYield = totalYield * (contributionRate / 100);
    const userYield = totalYield - ngoYield;
    
    return { userYield, ngoYield, totalYield };
  };

  const currentAPY = calculateAPY(selectedLockPeriod);
  const yieldEstimate = calculateEstimatedYield(selectedAmount, selectedLockPeriod, selectedContributionRate);

  if (loadingNGO) {
    return (
      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        <div className="animate-pulse">
          <div className="h-8 bg-gray-200 rounded w-1/3 mb-4"></div>
          <div className="h-64 bg-gray-200 rounded mb-6"></div>
          <div className="h-96 bg-gray-200 rounded"></div>
        </div>
      </div>
    );
  }

  if (!ngoInfo) {
    return (
      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        <div className="text-center">
          <h1 className="text-2xl font-bold text-gray-900 mb-4">Campaign Not Found</h1>
          <p className="text-gray-600 mb-6">The requested campaign could not be found.</p>
          <Button onClick={() => navigate('/discover')} variant="primary">
            Back to Discover
          </Button>
        </div>
      </div>
    );
  }

  const name = (ngoInfo as any)?.name || 'Unknown Campaign';
  const description = (ngoInfo as any)?.description || 'No description available';
  const isActive = (ngoInfo as any)?.isActive || false;
  const ngo: NGO = {
    ngoAddress: ngoAddress as `0x${string}`,
    name,
    description,
    website: (ngoInfo as any)?.website || '',
    logoURI: '',
    walletAddress: ngoAddress as `0x${string}`,
    causes: [],
    metadataURI: '',
    isVerified: false,
    isActive,
    reputationScore: BigInt(0),
    totalStakers: BigInt(0),
    totalYieldReceived: BigInt(0),
    id: ngoAddress || '',
    location: '',
    category: '',
    totalStaked: '0',
    activeStakers: 0,
    impactScore: 0,
  };

  return (
    <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
      {/* Header */}
      <div className="mb-8">
        <button
          onClick={() => navigate('/discover')}
          className="flex items-center text-blue-600 hover:text-blue-800 mb-4"
        >
          Back to Discover
        </button>
        <h1 className="text-4xl font-bold text-gray-900 mb-2">{name}</h1>
        <p className="text-xl text-gray-600">{description}</p>

      </div>

      {/* Campaign Stats */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
        <div className="bg-white rounded-lg border p-6">
          <div className="text-sm text-gray-500 mb-1">Total Staked</div>
          <div className="text-2xl font-bold text-gray-900">
            {totalStaked ? formatUnits(totalStaked, 18) : '0'} ETH
          </div>
        </div>
        <div className="bg-white rounded-lg border p-6">
          <div className="text-sm text-gray-500 mb-1">Current APY</div>
          <div className="text-2xl font-bold text-green-600">
            {currentAPY.toFixed(1)}%
          </div>
        </div>
        <div className="bg-white rounded-lg border p-6">
          <div className="text-sm text-gray-500 mb-1">Lock Period</div>
          <div className="text-2xl font-bold text-gray-900">
            {selectedLockPeriod} months
          </div>
        </div>
      </div>

      {/* Staking Interface */}
      <div className="bg-white rounded-lg border p-8">
        <h2 className="text-2xl font-bold text-gray-900 mb-6">Stake for Impact</h2>
        
        {/* Amount Input */}
        <div className="mb-6">
          <label className="block text-sm font-medium text-gray-700 mb-2">
            Stake Amount (ETH)
          </label>
          <input
            type="number"
            value={selectedAmount}
            onChange={(e) => setSelectedAmount(e.target.value)}
            placeholder="0.0"
            className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 text-lg"
          />
        </div>

        {/* Lock Period Selection */}
        <div className="mb-6">
          <label className="block text-sm font-medium text-gray-700 mb-3">
            Lock Period
          </label>
          <div className="grid grid-cols-3 gap-3">
            {[6, 12, 24].map((period) => {
              const apy = calculateAPY(period);
              return (
                <button
                  key={period}
                  onClick={() => setSelectedLockPeriod(period)}
                  className={`p-4 border rounded-lg text-center transition-colors ${
                    selectedLockPeriod === period
                      ? 'border-blue-500 bg-blue-50 text-blue-700'
                      : 'border-gray-300 hover:border-gray-400'
                  }`}
                >
                  <div className="font-semibold">{period} months</div>
                  <div className="text-sm text-green-600">{apy.toFixed(1)}% APY</div>
                </button>
              );
            })}
          </div>
        </div>

        {/* Contribution Rate */}
        <div className="mb-6">
          <label className="block text-sm font-medium text-gray-700 mb-3">
            Yield Contribution to {name}
          </label>
          <div className="grid grid-cols-4 gap-3">
            {[50, 75, 90, 100].map((rate) => (
              <button
                key={rate}
                onClick={() => setSelectedContributionRate(rate)}
                className={`p-3 border rounded-lg text-center transition-colors ${
                  selectedContributionRate === rate
                    ? 'border-blue-500 bg-blue-50 text-blue-700'
                    : 'border-gray-300 hover:border-gray-400'
                }`}
              >
                <div className="font-semibold">{rate}%</div>
              </button>
            ))}
          </div>
        </div>

        {/* Yield Breakdown */}
        {selectedAmount && parseFloat(selectedAmount) > 0 && (
          <div className="bg-gradient-to-r from-blue-50 to-green-50 p-6 rounded-lg mb-6">
            <h3 className="font-semibold text-gray-900 mb-4">Expected Returns</h3>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
              <div className="text-center">
                <div className="text-sm text-gray-600">Total Yield</div>
                <div className="text-xl font-bold text-gray-900">
                  {yieldEstimate.totalYield.toFixed(4)} ETH
                </div>
              </div>
              <div className="text-center">
                <div className="text-sm text-gray-600">Your Share</div>
                <div className="text-xl font-bold text-blue-600">
                  {yieldEstimate.userYield.toFixed(4)} ETH
                </div>
              </div>
              <div className="text-center">
                <div className="text-sm text-gray-600">NGO Impact</div>
                <div className="text-xl font-bold text-green-600">
                  {yieldEstimate.ngoYield.toFixed(4)} ETH
                </div>
              </div>
            </div>
            <div className="mt-4 text-center text-sm text-gray-600">
              You'll receive back: {selectedAmount} ETH (principal) + {yieldEstimate.userYield.toFixed(4)} ETH (yield)
            </div>
          </div>
        )}

        {/* Stake Button */}
        <div className="flex justify-center">
          {address ? (
            <Button
              onClick={() => setShowStakingForm(true)}
              variant="primary"
              size="lg"
              disabled={!selectedAmount || parseFloat(selectedAmount) <= 0}
              className="px-8 py-3"
            >
              Stake Now
            </Button>
          ) : (
            <div className="text-center text-gray-600">
              Please connect your wallet to stake
            </div>
          )}
        </div>
      </div>

      {/* Staking Form Modal */}
      {showStakingForm && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-lg max-w-md w-full max-h-[90vh] overflow-y-auto">
            <div className="p-6">
              <div className="flex justify-between items-center mb-4">
                <h3 className="text-lg font-semibold">Stake for {name}</h3>
                <button
                  onClick={() => setShowStakingForm(false)}
                  className="text-gray-400 hover:text-gray-600"
                >
                  ×
                </button>
              </div>
              <StakingForm
                ngo={ngo}
                onClose={() => setShowStakingForm(false)}
              />
            </div>
          </div>
        </div>
      )}
    </div>
  );
}