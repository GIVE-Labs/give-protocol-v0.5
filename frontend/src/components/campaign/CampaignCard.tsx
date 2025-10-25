/**
 * CampaignCard Component
 * Display individual campaign with donate button
 * Design: Glass-card style with emerald/cyan gradients
 */

import { motion } from 'framer-motion';
import { Heart, ExternalLink } from 'lucide-react';
import { useCampaignRegistry, usePayoutRouter } from '../../hooks/v05';
import { useAccount } from 'wagmi';
import Button from '../ui/Button';
import { useState } from 'react';
import { getBasescanLink } from '../../config/baseSepolia';

interface CampaignCardProps {
  campaignId: `0x${string}`;
  index?: number;
}

export default function CampaignCard({ campaignId, index = 0 }: CampaignCardProps) {
  const { address } = useAccount();
  const { getCampaign } = useCampaignRegistry();
  const { data: campaign } = getCampaign(campaignId);
  const { setDefaultAllocation, isPending } = usePayoutRouter();
  
  const [selectedAllocation, setSelectedAllocation] = useState<50 | 75 | 100>(100);

  const handleDonate = async () => {
    if (!address) return;
    try {
      // Convert hex string to bigint for the payout router
      const campaignIdBigInt = BigInt(campaignId);
      
      await setDefaultAllocation(
        BigInt(1), // vaultId (GIVE WETH Vault)
        campaignIdBigInt,
        selectedAllocation
      );
    } catch (err) {
      console.error('Failed to set allocation:', err);
    }
  };

  if (!campaign) return null;

  // Type the campaign data properly
  const campaignData = campaign as any; // TODO: Add proper type definition

  const allocations = [
    { value: 50, label: '50%', color: 'from-emerald-400 to-teal-400' },
    { value: 75, label: '75%', color: 'from-cyan-400 to-blue-400' },
    { value: 100, label: '100%', color: 'from-teal-400 to-emerald-400' },
  ];

  return (
    <motion.div
      initial={{ opacity: 0, y: 30 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.5, delay: index * 0.1 }}
      whileHover={{ y: -5, scale: 1.02 }}
      className="group"
    >
      <div className="relative bg-white/60 backdrop-blur-xl border border-white/70 rounded-2xl shadow-lg hover:shadow-2xl transition-all duration-500 overflow-hidden">
        {/* Decorative gradient */}
        <div className="absolute top-0 left-0 right-0 h-2 bg-gradient-to-r from-emerald-500 via-cyan-500 to-teal-500" />

        <div className="p-6">
          {/* Header */}
          <div className="flex items-start justify-between mb-4">
            <div className="flex-1">
              <h3 className="text-xl font-bold text-gray-900 mb-2 group-hover:text-gray-800 transition-colors font-unbounded">
                Campaign
              </h3>
              <p className="text-sm text-gray-600 line-clamp-2">
                {campaignData?.payoutRecipient && `Supporting ${campaignData.payoutRecipient.slice(0, 6)}...${campaignData.payoutRecipient.slice(-4)}`}
              </p>
            </div>
            <motion.div
              className="w-12 h-12 bg-gradient-to-r from-emerald-500 to-teal-500 rounded-xl flex items-center justify-center shadow-md"
              whileHover={{ rotate: 10, scale: 1.1 }}
              transition={{ type: "spring", stiffness: 300 }}
            >
              <Heart className="w-6 h-6 text-white" />
            </motion.div>
          </div>

          {/* Stats */}
          <div className="grid grid-cols-2 gap-4 mb-6 p-4 bg-gradient-to-br from-emerald-50 to-cyan-50 rounded-xl">
            <div>
              <p className="text-xs text-gray-600 mb-1">Target Stake</p>
              <p className="text-lg font-bold text-gray-900">
                {campaignData?.targetStake ? `${Number(campaignData.targetStake) / 1e18} ETH` : '—'}
              </p>
            </div>
            <div>
              <p className="text-xs text-gray-600 mb-1">Status</p>
              <span className={`inline-block px-3 py-1 text-white text-xs font-semibold rounded-full ${
                campaignData?.status === 1 ? 'bg-yellow-500' : 
                campaignData?.status === 2 ? 'bg-gradient-to-r from-emerald-500 to-teal-500' :
                'bg-gray-500'
              }`}>
                {campaignData?.status === 0 ? 'Submitted' :
                 campaignData?.status === 1 ? 'Approved' :
                 campaignData?.status === 2 ? 'Active' :
                 campaignData?.status === 3 ? 'Paused' :
                 campaignData?.status === 4 ? 'Completed' : 'Unknown'}
              </span>
            </div>
          </div>

          {/* Allocation Selection */}
          <div className="mb-6">
            <p className="text-sm font-medium text-gray-700 mb-3">Choose your yield allocation:</p>
            <div className="grid grid-cols-3 gap-2">
              {allocations.map((option) => (
                <motion.button
                  key={option.value}
                  onClick={() => setSelectedAllocation(option.value as 50 | 75 | 100)}
                  whileHover={{ scale: 1.05 }}
                  whileTap={{ scale: 0.95 }}
                  className={`py-2 px-3 rounded-lg font-bold text-sm transition-all ${
                    selectedAllocation === option.value
                      ? `bg-gradient-to-r ${option.color} text-white shadow-md`
                      : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
                  }`}
                >
                  {option.label}
                </motion.button>
              ))}
            </div>
          </div>

          {/* Donate Button */}
          <motion.div whileHover={{ scale: 1.02 }} whileTap={{ scale: 0.98 }}>
            <Button
              onClick={handleDonate}
              disabled={!address || isPending}
              className="w-full bg-gradient-to-r from-emerald-600 to-cyan-600 text-white py-3 rounded-xl font-bold hover:from-emerald-700 hover:to-cyan-700 transition-all duration-300 shadow-md hover:shadow-lg flex items-center justify-center space-x-2"
              loading={isPending}
            >
              {!isPending && (
                <>
                  <Heart className="w-5 h-5" />
                  <span>Donate {selectedAllocation}% of Yield</span>
                </>
              )}
            </Button>
          </motion.div>

          {/* View on Basescan */}
          {(campaign as any).recipient && (
            <div className="mt-4 pt-4 border-t border-gray-200">
              <a
                href={getBasescanLink((campaign as any).recipient, 'address')}
                target="_blank"
                rel="noopener noreferrer"
                className="text-xs text-cyan-600 hover:text-cyan-700 flex items-center justify-center space-x-1"
              >
                <span>View recipient on Basescan</span>
                <ExternalLink className="w-3 h-3" />
              </a>
            </div>
          )}
        </div>

        {/* Hover effect */}
        <motion.div
          className="absolute bottom-0 right-0 w-24 h-24 bg-gradient-to-r from-emerald-500/10 to-cyan-500/10 rounded-tl-full"
          animate={{
            scale: [1, 1.2, 1],
            rotate: [0, 45, 0]
          }}
          transition={{
            duration: 4,
            repeat: Infinity,
            delay: index * 0.3
          }}
        />
      </div>
    </motion.div>
  );
}
