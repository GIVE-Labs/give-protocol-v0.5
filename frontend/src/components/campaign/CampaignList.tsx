/**
 * CampaignList Component
 * Browse all active campaigns
 * Design: Grid layout with loading states
 */

import { motion } from 'framer-motion';
import { Sparkles, Loader } from 'lucide-react';
import { useCampaignRegistry } from '../../hooks/v05';
import CampaignCard from './CampaignCard';

export default function CampaignList() {
  const { activeCampaigns, campaignCount } = useCampaignRegistry();

  const containerVariants = {
    hidden: { opacity: 0 },
    visible: {
      opacity: 1,
      transition: {
        staggerChildren: 0.1,
      }
    }
  };

  return (
    <div className="space-y-8">
      {/* Header */}
      <motion.div
        initial={{ opacity: 0, y: -20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.5 }}
        className="text-center"
      >
        <h2 className="text-4xl lg:text-5xl font-bold mb-4 font-unbounded">
          <span className="text-gray-900">Active </span>
          <span className="text-transparent bg-gradient-to-r from-emerald-600 via-cyan-600 to-teal-600 bg-clip-text">
            Campaigns
          </span>
        </h2>
        <p className="text-lg text-gray-600">
          Choose a campaign to support with your vault yield
        </p>
        <div className="mt-4 flex items-center justify-center space-x-2 text-sm text-gray-500">
          <Sparkles className="w-4 h-4 text-cyan-500" />
          <span>{campaignCount} campaigns available</span>
        </div>
      </motion.div>

      {/* Campaign Grid */}
      {!activeCampaigns ? (
        <div className="flex justify-center items-center py-20">
          <div className="text-center">
            <Loader className="w-12 h-12 animate-spin text-cyan-500 mx-auto mb-4" />
            <p className="text-gray-600">Loading campaigns...</p>
          </div>
        </div>
      ) : activeCampaigns.length === 0 ? (
        <motion.div
          initial={{ opacity: 0, scale: 0.9 }}
          animate={{ opacity: 1, scale: 1 }}
          className="text-center py-20"
        >
          <div className="inline-block p-8 bg-gradient-to-br from-emerald-50 to-cyan-50 rounded-2xl shadow-lg">
            <p className="text-xl font-semibold text-gray-700 mb-2">No active campaigns yet</p>
            <p className="text-gray-600">Check back soon for new opportunities to give!</p>
          </div>
        </motion.div>
      ) : (
        <motion.div
          className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6"
          variants={containerVariants}
          initial="hidden"
          animate="visible"
        >
          {activeCampaigns.map((campaignId, index) => (
            <CampaignCard
              key={campaignId.toString()}
              campaignId={campaignId}
              index={index}
            />
          ))}
        </motion.div>
      )}
    </div>
  );
}
