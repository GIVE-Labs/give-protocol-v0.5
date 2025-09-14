import { useState, useEffect, useCallback } from 'react';
import { useAccount, useBalance, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { parseEther, formatEther } from 'viem';
import { NGO } from '../../types';
import { MOCK_WETH, MOCK_USDC } from '../../config/contracts';
import { erc20Abi } from '../../abis/erc20';

import Button from '../ui/Button';
import StakingProgressModal from './StakingProgressModal';

interface StakingFormProps {
  ngo: NGO;
  onClose: () => void;
}

export default function StakingForm({ ngo, onClose }: StakingFormProps) {
  const { address } = useAccount();
  const [amount, setAmount] = useState('');
  const [token, setToken] = useState(MOCK_WETH);
  const [contributionRate, setContributionRate] = useState(75);
  const [lockPeriod, setLockPeriod] = useState(12);
  const [showProgressModal, setShowProgressModal] = useState(false);
  const [currentStep, setCurrentStep] = useState(0);
  const [progressSteps, setProgressSteps] = useState<string[]>([]);
  const [currentTxHash, setCurrentTxHash] = useState<`0x${string}` | undefined>();

  const { data: tokenBalance, refetch: refetchBalance } = useBalance({
    address,
    token: token as `0x${string}`,
  });

  const amountInWei = amount ? parseEther(amount) : BigInt(0);

  // Removed staking contract allowance check - no longer using MORPH_IMPACT_STAKING
  const allowance = BigInt(0);
  const refetchAllowance = () => {};
  const isAllowanceLoading = false;

  const { writeContract: approveToken, data: approveHash, isPending: isApproving, reset: resetApprove } = useWriteContract();
  const { writeContract: stakeTokens, data: stakeHash, isPending: isStaking, reset: resetStake } = useWriteContract();

  const { isLoading: isApprovingTx, isSuccess: isApprovalSuccess } = useWaitForTransactionReceipt({ hash: approveHash });
  const { isLoading: isStakingTx, isSuccess: isStakeSuccess } = useWaitForTransactionReceipt({ hash: stakeHash });

  const needsApproval = allowance !== undefined && amountInWei > 0 && allowance < amountInWei;

  const executeStake = useCallback(() => {
    setProgressSteps(needsApproval ? ['Approve Token', 'Stake Tokens'] : ['Stake Tokens']);
    setCurrentStep(needsApproval ? 1 : 0);
    if (!showProgressModal) setShowProgressModal(true);
    
    // Removed staking contract call - no longer using MORPH_IMPACT_STAKING
    console.log('Staking functionality disabled - contract removed');
    setShowProgressModal(false);
  }, [ngo.id, token, amountInWei, lockPeriod, contributionRate, needsApproval, showProgressModal, stakeTokens]);

  const handleStakeFlow = async () => {
    if (!amount || isAllowanceLoading) return;

    if (needsApproval) {
      setProgressSteps(['Approve Token', 'Stake Tokens']);
      setCurrentStep(0);
      setShowProgressModal(true);
      approveToken({
        address: token as `0x${string}`,
        abi: erc20Abi,
        functionName: 'approve',
        args: ['0x0000000000000000000000000000000000000000' as `0x${string}`, amountInWei],
      }, {
        onError: (err) => {
          console.error("Approval failed:", err);
          setShowProgressModal(false);
        }
      });
    } else {
      executeStake();
    }
  };
  
  useEffect(() => {
    if (isApprovalSuccess) {
      refetchAllowance();
      executeStake();
    }
  }, [isApprovalSuccess, refetchAllowance, executeStake]);

  useEffect(() => {
    if (isStakeSuccess) {
      refetchBalance();
      if (progressSteps.length > 0) {
        setCurrentStep(progressSteps.length);
      }
      setTimeout(() => {
        setShowProgressModal(false);
        onClose();
        resetApprove();
        resetStake();
      }, 3000);
    }
  }, [isStakeSuccess, onClose, refetchBalance, resetApprove, resetStake, progressSteps.length]);
  
  useEffect(() => {
    if (approveHash) setCurrentTxHash(approveHash);
  }, [approveHash]);

  useEffect(() => {
    if (stakeHash) setCurrentTxHash(stakeHash);
  }, [stakeHash]);

  const estimatedYield = (parseFloat(amount || '0') * 0.05 * (lockPeriod / 12) * (contributionRate / 100)).toFixed(2);
  const isLoading = isApproving || isStaking || isApprovingTx || isStakingTx;

  const getButtonText = () => {
    if (isAllowanceLoading && amountInWei > 0) return 'Checking Allowance...';
    if (isLoading) return 'Processing...';
    if (needsApproval) return 'Approve & Stake';
    return 'Stake Now';
  };

  return (
    <div className="space-y-6">
      <div>
        <label className="block text-sm font-medium text-gray-700 mb-2">Select Token</label>
        <select
          value={token}
          onChange={(e) => setToken(e.target.value as typeof MOCK_WETH)}
          className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
        >
          <option value={MOCK_WETH}>WETH</option>
          <option value={MOCK_USDC}>USDC</option>
        </select>
        <p className="text-sm text-gray-600 mt-1">
          Balance: {tokenBalance ? formatEther(tokenBalance.value) : '0'} {token === MOCK_WETH ? 'WETH' : 'USDC'}
        </p>
      </div>

      <div>
        <label className="block text-sm font-medium text-gray-700 mb-2">Amount to Stake</label>
        <input
          type="number"
          value={amount}
          onChange={(e) => setAmount(e.target.value)}
          placeholder="0.0"
          className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
          step="0.01"
          min="0"
        />
      </div>

      <div>
        <label className="block text-sm font-medium text-gray-700 mb-2">Yield Contribution Rate</label>
        <div className="space-y-2">
          {[50, 75, 100].map((rate) => (
            <label key={rate} className="flex items-center">
              <input
                type="radio"
                name="contributionRate"
                value={rate}
                checked={contributionRate === rate}
                onChange={(e) => setContributionRate(Number(e.target.value))}
                className="mr-2"
              />
              <span className="text-sm">{rate}% of yield goes to {ngo.name}</span>
            </label>
          ))}
        </div>
      </div>

      <div>
        <label className="block text-sm font-medium text-gray-700 mb-2">Lock Period</label>
        <select
          value={lockPeriod}
          onChange={(e) => setLockPeriod(Number(e.target.value))}
          className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
        >
          <option value={6}>6 months</option>
          <option value={12}>12 months</option>
          <option value={24}>24 months</option>
        </select>
      </div>

      {amount && (
        <div className="bg-blue-50 p-4 rounded-lg">
          <h4 className="font-medium text-blue-900 mb-2">Estimated Impact</h4>
          <div className="space-y-1 text-sm text-blue-800">
            <p>Estimated yield: ${estimatedYield} over {lockPeriod} months</p>
            <p>Your contribution: ${estimatedYield} &times; {contributionRate}% = ${(parseFloat(estimatedYield) * contributionRate / 100).toFixed(2)}</p>
            <p>You keep: ${parseFloat(amount).toFixed(2)} principal + ${(parseFloat(estimatedYield) * (100 - contributionRate) / 100).toFixed(2)} yield</p>
          </div>
        </div>
      )}

      {/* TEMPORARY DEBUGGING OUTPUT */}
      <pre className="bg-gray-100 p-2 rounded text-xs overflow-auto">
        <p><strong>Address:</strong> {address}</p>
        <p><strong>Amount (Wei):</strong> {amountInWei.toString()}</p>
        <p><strong>Allowance Loading:</strong> {isAllowanceLoading.toString()}</p>
        <p><strong>Allowance:</strong> {allowance?.toString() ?? 'undefined'}</p>
        <p><strong>Needs Approval:</strong> {needsApproval.toString()}</p>
      </pre>

      <div className="flex gap-3">
        <Button
          onClick={handleStakeFlow}
          disabled={!amount || isLoading || (isAllowanceLoading && amountInWei > 0)}
          loading={isLoading || (isAllowanceLoading && amountInWei > 0)}
          className="flex-1"
        >
          {getButtonText()}
        </Button>
        <Button
          onClick={onClose}
          variant="secondary"
          className="flex-1"
          disabled={isLoading}
        >
          Cancel
        </Button>
      </div>

      <StakingProgressModal
        isOpen={showProgressModal}
        onClose={() => {
          setShowProgressModal(false);
          onClose();
        }}
        currentStep={currentStep}
        steps={progressSteps}
        txHash={currentTxHash}
        isComplete={isStakeSuccess}
      />
    </div>
  );
}
