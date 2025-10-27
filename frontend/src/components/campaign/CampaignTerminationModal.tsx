import { useEffect } from 'react';
import { CheckCircle, Circle, Loader2, XCircle, Ban, AlertTriangle } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';

interface CampaignTerminationModalProps {
  isOpen: boolean;
  onClose: () => void;
  onConfirm: () => void;
  currentStep: number;
  steps: string[];
  txHash?: `0x${string}`;
  isComplete: boolean;
  isError?: boolean;
  errorMessage?: string;
  isPending?: boolean;
}

export default function CampaignTerminationModal({ 
  isOpen, 
  onClose, 
  onConfirm,
  currentStep, 
  steps, 
  txHash,
  isComplete,
  isError = false,
  errorMessage,
  isPending = false
}: CampaignTerminationModalProps) {
  // Auto-close on success after 3 seconds
  useEffect(() => {
    if (isComplete) {
      const timer = setTimeout(() => {
        window.location.href = '/campaigns';
      }, 3000);
      return () => clearTimeout(timer);
    }
  }, [isComplete]);

  if (!isOpen) return null;

  const getStepIcon = (stepIndex: number) => {
    if (isError && stepIndex === currentStep) {
      return <XCircle className="w-6 h-6 text-red-500" />;
    } else if (isComplete || stepIndex < currentStep) {
      return <CheckCircle className="w-6 h-6 text-green-500" />;
    } else if (stepIndex === currentStep) {
      return <Loader2 className="w-6 h-6 text-red-500 animate-spin" />;
    } else {
      return <Circle className="w-6 h-6 text-gray-400" />;
    }
  };

  const getStepColor = (stepIndex: number) => {
    if (isError && stepIndex === currentStep) return 'text-red-600 font-semibold';
    if (isComplete || stepIndex < currentStep) return 'text-green-600';
    if (stepIndex === currentStep) return 'text-red-600 font-semibold';
    return 'text-gray-500';
  };

  return (
    <AnimatePresence>
      <motion.div 
        className="fixed inset-0 bg-black/60 backdrop-blur-sm flex items-center justify-center z-50"
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        exit={{ opacity: 0 }}
        onClick={onClose}
      >
        <motion.div 
          className="bg-white/95 backdrop-blur-xl rounded-2xl p-8 max-w-md w-full mx-4 shadow-2xl border border-white/20"
          initial={{ scale: 0.9, opacity: 0, y: 20 }}
          animate={{ scale: 1, opacity: 1, y: 0 }}
          exit={{ scale: 0.9, opacity: 0, y: 20 }}
          transition={{ type: "spring", damping: 25, stiffness: 300 }}
          onClick={(e) => e.stopPropagation()}
        >
          {/* Header */}
          <div className="text-center mb-6">
            <motion.div
              initial={{ scale: 0 }}
              animate={{ scale: 1 }}
              transition={{ delay: 0.2, type: "spring", stiffness: 200 }}
              className="inline-block mb-4"
            >
              {isError ? (
                <div className="w-16 h-16 bg-red-100 rounded-full flex items-center justify-center">
                  <XCircle className="w-10 h-10 text-red-500" />
                </div>
              ) : isComplete ? (
                <div className="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center">
                  <CheckCircle className="w-10 h-10 text-green-500" />
                </div>
              ) : currentStep === 0 ? (
                <div className="w-16 h-16 bg-red-100 rounded-full flex items-center justify-center">
                  <AlertTriangle className="w-10 h-10 text-red-500" />
                </div>
              ) : (
                <div className="w-16 h-16 bg-red-100 rounded-full flex items-center justify-center">
                  <Ban className="w-10 h-10 text-red-500 animate-pulse" />
                </div>
              )}
            </motion.div>

            <h2 className="text-2xl font-bold text-gray-900 mb-2 font-unbounded">
              {isError 
                ? 'Termination Failed' 
                : isComplete 
                  ? 'Campaign Terminated!' 
                  : currentStep === 0
                    ? 'Terminate Campaign?'
                    : 'Terminating Campaign'}
            </h2>
            <p className="text-gray-600 font-medium">
              {isError 
                ? errorMessage || 'Failed to terminate campaign. Please try again.'
                : isComplete 
                  ? 'Campaign has been successfully terminated and will no longer appear in listings.' 
                  : currentStep === 0
                    ? 'This action will set the campaign status to Cancelled. This cannot be undone.'
                    : 'Please confirm the transaction in your wallet...'}
            </p>
          </div>

          {/* Steps Progress (only show after confirmation) */}
          {currentStep > 0 && (
            <motion.div 
              className="space-y-4 mb-6"
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.3 }}
            >
              {steps.map((step, index) => (
                <motion.div 
                  key={index} 
                  className="flex items-center space-x-3"
                  initial={{ opacity: 0, x: -20 }}
                  animate={{ opacity: 1, x: 0 }}
                  transition={{ delay: 0.4 + (index * 0.1) }}
                >
                  {getStepIcon(index)}
                  <div className="flex-1">
                    <p className={`text-sm ${getStepColor(index)} font-medium`}>
                      {step}
                    </p>
                    {index === currentStep && !isComplete && !isError && (
                      <motion.p 
                        className="text-xs text-gray-500 mt-1"
                        initial={{ opacity: 0 }}
                        animate={{ opacity: 1 }}
                        transition={{ delay: 0.5 }}
                      >
                        Waiting for wallet confirmation...
                      </motion.p>
                    )}
                    {index === currentStep && isError && (
                      <motion.p 
                        className="text-xs text-red-500 mt-1"
                        initial={{ opacity: 0 }}
                        animate={{ opacity: 1 }}
                      >
                        Transaction rejected or failed
                      </motion.p>
                    )}
                  </div>
                </motion.div>
              ))}
            </motion.div>
          )}

          {/* Warning Message (confirmation step) */}
          {currentStep === 0 && !isError && (
            <motion.div 
              className="bg-gradient-to-r from-red-50 to-orange-50 border border-red-200 rounded-xl p-4 mb-6"
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.3 }}
            >
              <div className="flex items-start space-x-3">
                <AlertTriangle className="w-5 h-5 text-red-600 flex-shrink-0 mt-0.5" />
                <div className="text-sm text-red-800">
                  <p className="font-semibold mb-1">This action cannot be undone</p>
                  <ul className="list-disc list-inside space-y-1 text-xs">
                    <li>Campaign status will be set to Cancelled</li>
                    <li>Campaign will be hidden from public listings</li>
                    <li>Existing backers will keep their deposits</li>
                    <li>No new deposits will be accepted</li>
                  </ul>
                </div>
              </div>
            </motion.div>
          )}

          {/* Transaction Hash */}
          {txHash && currentStep > 0 && (
            <motion.div 
              className="bg-gray-50 rounded-lg p-3 mb-6 border border-gray-200"
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
            >
              <p className="text-xs text-gray-600 mb-1 font-medium">Transaction Hash:</p>
              <a 
                href={`https://sepolia.basescan.org/tx/${txHash}`}
                target="_blank"
                rel="noopener noreferrer"
                className="text-xs text-emerald-600 hover:underline break-all font-mono"
              >
                {txHash}
              </a>
            </motion.div>
          )}

          {/* Action Buttons */}
          <motion.div 
            className="flex gap-3"
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.4 }}
          >
            {isComplete ? (
              <button 
                onClick={() => window.location.href = '/campaigns'}
                className="flex-1 bg-gradient-to-r from-emerald-600 to-teal-600 text-white py-3 px-6 rounded-lg font-semibold hover:from-emerald-700 hover:to-teal-700 transition-all duration-200 shadow-lg hover:shadow-xl font-unbounded"
              >
                Return to Campaigns
              </button>
            ) : isError ? (
              <>
                <button 
                  onClick={onClose}
                  className="flex-1 bg-gradient-to-r from-gray-600 to-gray-700 text-white py-3 px-6 rounded-lg font-semibold hover:from-gray-700 hover:to-gray-800 transition-all duration-200 shadow-lg hover:shadow-xl font-unbounded"
                >
                  Close
                </button>
                <button 
                  onClick={onConfirm}
                  className="flex-1 bg-gradient-to-r from-red-600 to-red-700 text-white py-3 px-6 rounded-lg font-semibold hover:from-red-700 hover:to-red-800 transition-all duration-200 shadow-lg hover:shadow-xl font-unbounded"
                >
                  Try Again
                </button>
              </>
            ) : currentStep === 0 ? (
              <>
                <button 
                  onClick={onClose}
                  disabled={isPending}
                  className="flex-1 bg-gradient-to-r from-gray-600 to-gray-700 text-white py-3 px-4 rounded-lg font-semibold hover:from-gray-700 hover:to-gray-800 disabled:opacity-50 disabled:cursor-not-allowed transition-all duration-200 shadow-lg hover:shadow-xl font-unbounded"
                >
                  Cancel
                </button>
                <button 
                  onClick={onConfirm}
                  disabled={isPending}
                  className="flex-1 bg-gradient-to-r from-red-600 to-red-700 text-white py-3 px-4 rounded-lg font-semibold hover:from-red-700 hover:to-red-800 disabled:opacity-50 disabled:cursor-not-allowed transition-all duration-200 shadow-lg hover:shadow-xl font-unbounded flex items-center justify-center gap-2"
                >
                  {isPending ? (
                    <>
                      <Loader2 className="w-4 h-4 animate-spin" />
                      <span className="whitespace-nowrap">Terminating...</span>
                    </>
                  ) : (
                    <>
                      <Ban className="w-4 h-4" />
                      <span className="whitespace-nowrap">Terminate</span>
                    </>
                  )}
                </button>
              </>
            ) : (
              <button 
                onClick={onClose}
                disabled={!isError && !isComplete}
                className="flex-1 bg-gradient-to-r from-gray-600 to-gray-700 text-white py-3 px-6 rounded-lg font-semibold hover:from-gray-700 hover:to-gray-800 disabled:opacity-50 disabled:cursor-not-allowed transition-all duration-200 shadow-lg hover:shadow-xl font-unbounded"
              >
                {!isError && !isComplete ? 'Processing...' : 'Close'}
              </button>
            )}
          </motion.div>
        </motion.div>
      </motion.div>
    </AnimatePresence>
  );
}
