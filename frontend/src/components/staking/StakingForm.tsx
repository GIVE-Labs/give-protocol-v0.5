import { useState, useEffect } from 'react'
import { useAccount, useBalance, useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi'
import { parseEther, formatEther } from 'viem'
import { NGO } from '../../types'
import { MORPH_IMPACT_STAKING, MOCK_WETH, MOCK_USDC } from '../../config/contracts'
import { erc20Abi } from '../../abis/erc20'
import { morphImpactStakingAbi } from '../../abis/MorphImpactStaking'
import Button from '../ui/Button'
import StakingProgressModal from './StakingProgressModal'

interface StakingFormProps {
  ngo: NGO
  onClose: () => void
}

export default function StakingForm({ ngo, onClose }: StakingFormProps) {
  const { address } = useAccount()
  const [amount, setAmount] = useState('')
  const [token, setToken] = useState(MOCK_WETH)
  const [contributionRate, setContributionRate] = useState(75)
  const [lockPeriod, setLockPeriod] = useState(12)
  const [isApproving, setIsApproving] = useState(false)
  const [isStaking, setIsStaking] = useState(false)
  const [showProgressModal, setShowProgressModal] = useState(false)
  const [currentStep, setCurrentStep] = useState(0)
  const [progressSteps, setProgressSteps] = useState<string[]>([])
  const [currentTxHash, setCurrentTxHash] = useState<string>()

  const { data: tokenBalance } = useBalance({
    address,
    token: token as `0x${string}`,
  })

  const { data: allowance } = useReadContract({
    address: token as `0x${string}`,
    abi: erc20Abi,
    functionName: 'allowance',
    args: [address!, MORPH_IMPACT_STAKING],
  })

  const { writeContract: approveToken, data: approveHash } = useWriteContract()
  const { writeContract: stakeTokens, data: stakeHash } = useWriteContract()

  const { isLoading: isApprovingTx } = useWaitForTransactionReceipt({
    hash: approveHash,
  })

  const { isLoading: isStakingTx } = useWaitForTransactionReceipt({
    hash: stakeHash,
  })

  const needsApproval = allowance && allowance < parseEther(amount || '0')
  const amountInWei = parseEther(amount || '0')

  const handleApprove = async () => {
    if (!amount) return
    
    setProgressSteps(['Approve Token Allowance', 'Confirm Staking Transaction'])
    setCurrentStep(0)
    setShowProgressModal(true)
    setIsApproving(true)
    
    try {
      approveToken({
        address: token as `0x${string}`,
        abi: erc20Abi,
        functionName: 'approve',
        args: [MORPH_IMPACT_STAKING, amountInWei],
      })
    } catch (error) {
      console.error('Error approving token:', error)
      setShowProgressModal(false)
    } finally {
      setIsApproving(false)
    }
  }

  const handleStake = async () => {
    if (!amount) return

    setProgressSteps(['Confirm Staking Transaction'])
    setCurrentStep(0)
    setShowProgressModal(true)
    setIsStaking(true)
    
    try {
      stakeTokens({
        address: MORPH_IMPACT_STAKING,
        abi: morphImpactStakingAbi,
        functionName: 'stake',
        args: [
          ngo.id as `0x${string}`,
          token as `0x${string}`,
          amountInWei,
          BigInt(lockPeriod * 30 * 24 * 60 * 60), // Convert months to seconds
          BigInt(contributionRate),
        ],
      })
    } catch (error) {
      console.error('Error staking tokens:', error)
      setShowProgressModal(false)
    } finally {
      setIsStaking(false)
    }
  }

  const estimatedYield = (parseFloat(amount || '0') * 0.05 * (lockPeriod / 12) * (contributionRate / 100)).toFixed(2)

  useEffect(() => {
    if (approveHash) {
      setCurrentTxHash(approveHash)
    }
  }, [approveHash])

  useEffect(() => {
    if (stakeHash) {
      setCurrentTxHash(stakeHash)
    }
  }, [stakeHash])

  useEffect(() => {
    if (isApprovingTx) {
      setCurrentStep(0)
    } else if (approveHash && !isApprovingTx) {
      setCurrentStep(1)
    }
  }, [isApprovingTx, approveHash])

  useEffect(() => {
    if (isStakingTx) {
      setCurrentStep(0)
    } else if (stakeHash && !isStakingTx) {
      setCurrentStep(1)
      setTimeout(() => {
        setShowProgressModal(false)
        onClose()
      }, 2000)
    }
  }, [isStakingTx, stakeHash, onClose])

  return (
    <div className="space-y-6">
      {/* Token Selection */}
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

      {/* Amount Input */}
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

      {/* Contribution Rate */}
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

      {/* Lock Period */}
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

      {/* Estimated Yield Preview */}
      {amount && (
        <div className="bg-blue-50 p-4 rounded-lg">
          <h4 className="font-medium text-blue-900 mb-2">Estimated Impact</h4>
          <div className="space-y-1 text-sm text-blue-800">
            <p>Estimated yield: ${estimatedYield} over {lockPeriod} months</p>
            <p>Your contribution: ${estimatedYield} × {contributionRate}% = ${(parseFloat(estimatedYield) * contributionRate / 100).toFixed(2)}</p>
            <p>You keep: ${(parseFloat(amount) * (contributionRate === 100 ? 0 : 1)).toFixed(2)} principal + ${(parseFloat(estimatedYield) * (100 - contributionRate) / 100).toFixed(2)} yield</p>
          </div>
        </div>
      )}

      {/* Action Buttons */}
      <div className="flex gap-3">
        {needsApproval ? (
          <Button
            onClick={handleApprove}
            disabled={!amount || isApproving || isApprovingTx}
            loading={isApproving || isApprovingTx}
            className="flex-1"
          >
            {isApproving || isApprovingTx ? 'Approving...' : 'Approve Token'}
          </Button>
        ) : (
          <Button
            onClick={handleStake}
            disabled={!amount || isStaking || isStakingTx}
            loading={isStaking || isStakingTx}
            className="flex-1"
          >
            {isStaking || isStakingTx ? 'Staking...' : 'Stake Tokens'}
          </Button>
        )}
        <Button
          onClick={onClose}
          variant="secondary"
          className="flex-1"
        >
          Cancel
        </Button>
      </div>

      <StakingProgressModal
        isOpen={showProgressModal}
        onClose={() => {
          setShowProgressModal(false)
          onClose()
        }}
        currentStep={currentStep}
        steps={progressSteps}
        txHash={currentTxHash}
      />
    </div>
  )
}