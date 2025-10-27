/**
 * VaultDepositForm Component
 * Handle WETH deposit flow: wrap ETH → approve → deposit
 * Design: Matches existing cyan/emerald theme with glass-card style
 */

import { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import { useAccount } from 'wagmi';
import { parseUnits } from 'viem';
import { ArrowRight, CheckCircle, Loader } from 'lucide-react';
import { useGiveVault, useWETH } from '../../hooks/v05';
import Button from '../ui/Button';

interface VaultDepositFormProps {
  vaultAddress?: `0x${string}`;
}

export default function VaultDepositForm({ vaultAddress }: VaultDepositFormProps) {
  const { address } = useAccount();
  const { deposit, isPending: isDepositPending, isConfirming, isSuccess } = useGiveVault(vaultAddress);
  const { 
    ethBalance, 
    wethBalance, 
    vaultAllowance,
    wrap,
    approveVault,
    isPending: isWethPending,
    refetchWethBalance,
    refetchVaultAllowance
  } = useWETH();

  const [amount, setAmount] = useState('');
  const [step, setStep] = useState<'wrap' | 'approve' | 'deposit'>('wrap');
  const [error, setError] = useState('');

  // Auto-detect which step user needs
  useEffect(() => {
    if (!amount) return;
    
    const amountFloat = parseFloat(amount);
    const wethFloat = parseFloat(wethBalance);
    const allowanceFloat = parseFloat(vaultAllowance);

    if (wethFloat < amountFloat) {
      setStep('wrap');
    } else if (allowanceFloat < amountFloat) {
      setStep('approve');
    } else {
      setStep('deposit');
    }
  }, [amount, wethBalance, vaultAllowance]);

  const handleWrap = async () => {
    try {
      setError('');
      const amountWei = parseUnits(amount, 18);
      await wrap(amountWei);
      // Wait for confirmation, then refetch
      setTimeout(() => {
        refetchWethBalance();
        setStep('approve');
      }, 3000);
    } catch (err: any) {
      setError(err.message || 'Failed to wrap ETH');
    }
  };

  const handleApprove = async () => {
    try {
      setError('');
      await approveVault();
      setTimeout(() => {
        refetchVaultAllowance();
        setStep('deposit');
      }, 3000);
    } catch (err: any) {
      setError(err.message || 'Failed to approve WETH');
    }
  };

  const handleDeposit = async () => {
    try {
      setError('');
      if (!address) return;
      const amountWei = parseUnits(amount, 18);
      await deposit(amountWei, address);
    } catch (err: any) {
      setError(err.message || 'Failed to deposit');
    }
  };

  const handleSubmit = () => {
    if (step === 'wrap') handleWrap();
    else if (step === 'approve') handleApprove();
    else handleDeposit();
  };

  const setMaxAmount = () => {
    if (step === 'wrap') {
      // Leave small buffer for gas
      const maxEth = Math.max(0, parseFloat(ethBalance) - 0.01);
      setAmount(maxEth.toFixed(4));
    } else {
      setAmount(wethBalance);
    }
  };

  const steps = [
    { key: 'wrap', label: 'Wrap ETH', desc: 'Convert ETH to WETH' },
    { key: 'approve', label: 'Approve', desc: 'Allow vault to spend WETH' },
    { key: 'deposit', label: 'Deposit', desc: 'Deposit WETH to vault' },
  ];

  const currentStepIndex = steps.findIndex(s => s.key === step);

  return (
    <motion.div
      className="bg-white/60 backdrop-blur-xl border border-white/70 rounded-2xl shadow-xl p-8"
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.5 }}
    >
      {/* Header */}
      <div className="mb-8">
        <h2 className="text-3xl font-bold text-gray-900 mb-2 font-unbounded">
          Deposit WETH
        </h2>
        <p className="text-gray-600">
          Earn yield on your ETH while supporting campaigns
        </p>
      </div>

      {/* Step Indicator */}
      <div className="mb-8">
        <div className="flex items-center justify-between">
          {steps.map((s, index) => (
            <div key={s.key} className="flex items-center flex-1">
              <div className="flex flex-col items-center flex-1">
                <motion.div
                  className={`w-10 h-10 rounded-full flex items-center justify-center font-bold text-sm ${
                    index < currentStepIndex
                      ? 'bg-gradient-to-r from-emerald-500 to-teal-500 text-white'
                      : index === currentStepIndex
                      ? 'bg-gradient-to-r from-cyan-500 to-blue-500 text-white'
                      : 'bg-gray-200 text-gray-400'
                  }`}
                  whileHover={{ scale: 1.1 }}
                >
                  {index < currentStepIndex ? (
                    <CheckCircle className="w-5 h-5" />
                  ) : (
                    index + 1
                  )}
                </motion.div>
                <p className={`text-xs mt-2 ${index === currentStepIndex ? 'text-cyan-600 font-semibold' : 'text-gray-500'}`}>
                  {s.label}
                </p>
              </div>
              {index < steps.length - 1 && (
                <div className={`flex-1 h-1 mx-2 ${index < currentStepIndex ? 'bg-gradient-to-r from-emerald-500 to-teal-500' : 'bg-gray-200'}`} />
              )}
            </div>
          ))}
        </div>
      </div>

      {/* Amount Input */}
      <div className="mb-6">
        <label className="block text-sm font-medium text-gray-700 mb-2">
          Amount {step === 'wrap' ? '(ETH)' : '(WETH)'}
        </label>
        <div className="relative">
          <input
            type="number"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            placeholder="0.1"
            step="0.01"
            className="w-full px-4 py-3 border-2 border-gray-200 rounded-xl focus:border-cyan-400 focus:outline-none text-lg font-semibold"
          />
          <button
            onClick={setMaxAmount}
            className="absolute right-3 top-1/2 -translate-y-1/2 text-sm text-cyan-600 hover:text-cyan-700 font-semibold"
          >
            MAX
          </button>
        </div>
        
        {/* Balance Display */}
        <div className="mt-2 flex justify-between text-sm text-gray-600">
          <span>ETH Balance: {parseFloat(ethBalance).toFixed(4)}</span>
          <span>WETH Balance: {parseFloat(wethBalance).toFixed(4)}</span>
        </div>
      </div>

      {/* Action Button */}
      <div className="mb-4">
        <motion.div whileHover={{ scale: 1.02 }} whileTap={{ scale: 0.98 }}>
          <Button
            onClick={handleSubmit}
            disabled={!amount || parseFloat(amount) <= 0 || isWethPending || isDepositPending || isConfirming}
            className="w-full bg-gradient-to-r from-emerald-600 to-cyan-600 text-white py-4 rounded-xl font-bold text-lg hover:from-emerald-700 hover:to-cyan-700 transition-all duration-300 shadow-lg hover:shadow-xl flex items-center justify-center space-x-2"
          >
            {(isWethPending || isDepositPending || isConfirming) ? (
              <>
                <Loader className="w-5 h-5 animate-spin" />
                <span>{isConfirming ? 'Confirming...' : 'Processing...'}</span>
              </>
            ) : (
              <>
                <span>{steps[currentStepIndex].label}</span>
                <ArrowRight className="w-5 h-5" />
              </>
            )}
          </Button>
        </motion.div>
      </div>

      {/* Step Description */}
      <div className="text-center">
        <p className="text-sm text-gray-600">
          {steps[currentStepIndex].desc}
        </p>
      </div>

      {/* Error Message */}
      {error && (
        <motion.div
          initial={{ opacity: 0, y: -10 }}
          animate={{ opacity: 1, y: 0 }}
          className="mt-4 p-4 bg-red-50 border border-red-200 rounded-xl text-red-700 text-sm"
        >
          {error}
        </motion.div>
      )}

      {/* Success Message */}
      {isSuccess && (
        <motion.div
          initial={{ opacity: 0, scale: 0.9 }}
          animate={{ opacity: 1, scale: 1 }}
          className="mt-4 p-4 bg-emerald-50 border border-emerald-200 rounded-xl flex items-center space-x-2 text-emerald-700"
        >
          <CheckCircle className="w-5 h-5" />
          <span className="font-semibold">Deposit successful! 🎉</span>
        </motion.div>
      )}
    </motion.div>
  );
}
