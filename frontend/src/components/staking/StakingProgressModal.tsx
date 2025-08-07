import { CheckCircle, Circle, Loader2, XCircle } from 'lucide-react'

interface StakingProgressModalProps {
  isOpen: boolean
  onClose: () => void
  currentStep: number
  steps: string[]
  txHash?: `0x${string}`
  isComplete: boolean
  isError?: boolean
  errorMessage?: string
}

export default function StakingProgressModal({ 
  isOpen, 
  onClose, 
  currentStep, 
  steps, 
  txHash,
  isComplete,
  isError = false,
  errorMessage
}: StakingProgressModalProps) {
  if (!isOpen) return null

  const getStepIcon = (stepIndex: number) => {
    if (isError && stepIndex === currentStep) {
      return <XCircle className="w-6 h-6 text-red-500" />
    } else if (isComplete || stepIndex < currentStep) {
      return <CheckCircle className="w-6 h-6 text-green-500" />
    } else if (stepIndex === currentStep) {
      return <Loader2 className="w-6 h-6 text-purple-500 animate-spin" />
    } else {
      return <Circle className="w-6 h-6 text-gray-400" />
    }
  }

  const getStepColor = (stepIndex: number) => {
    if (isError && stepIndex === currentStep) return 'text-red-600 font-semibold'
    if (isComplete || stepIndex < currentStep) return 'text-green-600'
    if (stepIndex === currentStep) return 'text-purple-600 font-semibold'
    return 'text-gray-500'
  }

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-white rounded-xl p-6 max-w-md w-full mx-4">
        <div className="text-center mb-6">
          <h2 className="text-2xl font-bold text-gray-900 mb-2">
            {isError ? 'Transaction Failed!' : isComplete ? 'Staking Complete!' : 'Processing Stake'}
          </h2>
          <p className="text-gray-600">
            {isError 
              ? errorMessage || 'Something went wrong. Please try again.'
              : isComplete 
                ? 'Your stake has been successfully processed' 
                : 'Please follow these steps to complete your stake'}
          </p>
        </div>

        <div className="space-y-4 mb-6">
          {steps.map((step, index) => (
            <div key={index} className="flex items-center space-x-3">
              {getStepIcon(index)}
              <div className="flex-1">
                <p className={`text-sm ${getStepColor(index)}`}>
                  {step}
                </p>
                {index === currentStep && !isComplete && !isError && (
                  <p className="text-xs text-gray-500 mt-1">
                    Please confirm in your wallet...
                  </p>
                )}
                {index === currentStep && isError && (
                  <p className="text-xs text-red-500 mt-1">
                    Transaction failed. Please check your wallet and try again.
                  </p>
                )}
              </div>
            </div>
          ))}
        </div>

        {txHash && (
          <div className="bg-gray-50 rounded-lg p-3 mb-4">
            <p className="text-xs text-gray-600 mb-1">Transaction Hash:</p>
            <a 
              href={`https://explorer-holesky.morphl2.io/tx/${txHash}`}
              target="_blank"
              rel="noopener noreferrer"
              className="text-xs text-purple-600 hover:underline break-all"
            >
              {txHash}
            </a>
          </div>
        )}

        <div className="flex justify-center">
          {isComplete || isError ? (
            <button 
              onClick={onClose}
              className={`px-6 py-2 rounded-lg ${
                isError ? 'bg-red-600 text-white hover:bg-red-700' : 'bg-purple-600 text-white hover:bg-purple-700'
              }`}
            >
              {isError ? 'Close' : 'Done'}
            </button>
          ) : (
            <button 
              onClick={onClose}
              className="px-4 py-2 text-sm text-gray-600 hover:text-gray-800"
            >
              Cancel
            </button>
          )}
        </div>
      </div>
    </div>
  )
}