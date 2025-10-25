/**
 * CreateCampaign Page
 * Form to submit new campaigns to the registry
 * Design: Glass-card style with emerald/cyan gradients
 */

import { useState } from 'react';
import { motion } from 'framer-motion';
import { Heart, Upload, Loader, CheckCircle, AlertCircle } from 'lucide-react';
import { useAccount } from 'wagmi';
import { useCampaignRegistry } from '../hooks/v05';
import Button from '../components/ui/Button';
import { parseEther } from 'viem';

export default function CreateCampaign() {
  const { address, isConnected } = useAccount();
  const { submitCampaign, isPending, isSuccess, error } = useCampaignRegistry();

  // Form state
  const [formData, setFormData] = useState({
    name: '',
    description: '',
    category: 'climate',
    recipient: '',
    targetAmount: '',
    minStake: '0.01',
    fundraisingDuration: '90', // days
  });

  // IPFS upload state (placeholder - will use Pinata)
  const [metadataHash, setMetadataHash] = useState('');
  const [isUploading, setIsUploading] = useState(false);
  const [uploadError, setUploadError] = useState('');

  const categories = [
    { id: 'climate', name: '🌍 Climate Action', color: 'emerald' },
    { id: 'education', name: '📚 Education', color: 'blue' },
    { id: 'health', name: '❤️ Health & Wellness', color: 'red' },
    { id: 'poverty', name: '🤝 Poverty Relief', color: 'yellow' },
    { id: 'water', name: '💧 Clean Water', color: 'cyan' },
    { id: 'energy', name: '⚡ Renewable Energy', color: 'teal' },
  ];

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>) => {
    setFormData({
      ...formData,
      [e.target.name]: e.target.value,
    });
  };

  const uploadToIPFS = async () => {
    setIsUploading(true);
    setUploadError('');

    try {
      // Prepare metadata
      const metadata = {
        name: formData.name,
        description: formData.description,
        category: formData.category,
        recipient: formData.recipient,
        targetAmount: formData.targetAmount,
        createdAt: new Date().toISOString(),
        version: '0.5.0',
      };

      // TODO: Replace with actual Pinata upload
      // For now, generate a mock IPFS hash
      const mockHash = `Qm${Math.random().toString(36).substring(2, 15)}${Math.random().toString(36).substring(2, 15)}`;
      
      // Simulate upload delay
      await new Promise(resolve => setTimeout(resolve, 1500));
      
      setMetadataHash(mockHash);
      console.log('Metadata uploaded to IPFS:', mockHash, metadata);
      
      return mockHash;
    } catch (err) {
      console.error('IPFS upload failed:', err);
      setUploadError('Failed to upload metadata to IPFS');
      throw err;
    } finally {
      setIsUploading(false);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!isConnected || !address) {
      alert('Please connect your wallet first');
      return;
    }

    try {
      // Step 1: Upload metadata to IPFS
      let hash = metadataHash;
      if (!hash) {
        hash = await uploadToIPFS();
      }

      // Step 2: Get campaign ID (hash of name for determinism)
      const campaignId = `0x${Array.from(new TextEncoder().encode(formData.name))
        .map(b => b.toString(16).padStart(2, '0'))
        .join('')
        .padEnd(64, '0')}` as `0x${string}`;

      // Step 3: Get default strategy ID
      // TODO: Let user select strategy from StrategyRegistry
      const defaultStrategyId = '0x79861c7f93db9d6c9c5c46da4760ee78aef494b26e84a8b82a4cdfbf4dbdc848' as `0x${string}`;

      // Step 4: Prepare CampaignInput
      const targetStake = parseEther(formData.targetAmount || '10');
      const minStake = parseEther(formData.minStake || '0.01');
      const fundraisingStart = BigInt(Math.floor(Date.now() / 1000));
      const fundraisingDuration = BigInt(parseInt(formData.fundraisingDuration) * 24 * 60 * 60); // days to seconds
      const fundraisingEnd = fundraisingStart + fundraisingDuration;

      const metadataHashBytes = `0x${Array.from(new TextEncoder().encode(hash))
        .map(b => b.toString(16).padStart(2, '0'))
        .join('')
        .padEnd(64, '0')}` as `0x${string}`;

      // Step 5: Submit campaign
      const input = {
        id: campaignId,
        payoutRecipient: formData.recipient as `0x${string}`,
        strategyId: defaultStrategyId,
        metadataHash: metadataHashBytes,
        targetStake,
        minStake,
        fundraisingStart,
        fundraisingEnd,
      };

      console.log('Submitting campaign:', input);
      
      await submitCampaign(input);
      
    } catch (err) {
      console.error('Campaign submission failed:', err);
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-emerald-50 via-cyan-50 to-teal-50 relative overflow-hidden">
      {/* Animated Background */}
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        <div className="absolute top-20 left-10 w-72 h-72 bg-gradient-to-r from-emerald-200/20 to-cyan-200/20 rounded-full blur-3xl animate-pulse" />
        <div className="absolute bottom-20 right-10 w-96 h-96 bg-gradient-to-r from-teal-200/20 to-blue-200/20 rounded-full blur-3xl animate-pulse" />
      </div>

      <div className="container mx-auto px-4 py-16 relative z-10">
        <motion.div
          initial={{ opacity: 0, y: -20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5 }}
          className="max-w-3xl mx-auto"
        >
          {/* Header */}
          <div className="text-center mb-12">
            <h1 className="text-5xl font-bold mb-4 font-unbounded">
              <span className="text-gray-900">Create a </span>
              <span className="text-transparent bg-gradient-to-r from-emerald-600 via-cyan-600 to-teal-600 bg-clip-text">
                Campaign
              </span>
            </h1>
            <p className="text-lg text-gray-600">
              Submit your campaign for review and start receiving no-loss donations
            </p>
          </div>

          {/* Form Card */}
          <motion.div
            initial={{ opacity: 0, scale: 0.95 }}
            animate={{ opacity: 1, scale: 1 }}
            transition={{ duration: 0.5, delay: 0.1 }}
            className="bg-white/60 backdrop-blur-xl border border-white/70 rounded-2xl shadow-2xl p-8"
          >
            <form onSubmit={handleSubmit} className="space-y-6">
              {/* Campaign Name */}
              <div>
                <label className="block text-sm font-semibold text-gray-700 mb-2">
                  Campaign Name *
                </label>
                <input
                  type="text"
                  name="name"
                  required
                  value={formData.name}
                  onChange={handleInputChange}
                  placeholder="e.g., Reforestation in the Amazon"
                  className="w-full px-4 py-3 bg-white/50 border border-gray-300 rounded-xl focus:outline-none focus:ring-2 focus:ring-cyan-500 focus:border-transparent transition-all"
                />
              </div>

              {/* Description */}
              <div>
                <label className="block text-sm font-semibold text-gray-700 mb-2">
                  Description *
                </label>
                <textarea
                  name="description"
                  required
                  value={formData.description}
                  onChange={handleInputChange}
                  rows={4}
                  placeholder="Describe your campaign's mission, impact, and how funds will be used..."
                  className="w-full px-4 py-3 bg-white/50 border border-gray-300 rounded-xl focus:outline-none focus:ring-2 focus:ring-cyan-500 focus:border-transparent transition-all resize-none"
                />
              </div>

              {/* Category */}
              <div>
                <label className="block text-sm font-semibold text-gray-700 mb-2">
                  Category *
                </label>
                <select
                  name="category"
                  required
                  value={formData.category}
                  onChange={handleInputChange}
                  className="w-full px-4 py-3 bg-white/50 border border-gray-300 rounded-xl focus:outline-none focus:ring-2 focus:ring-cyan-500 focus:border-transparent transition-all"
                >
                  {categories.map(cat => (
                    <option key={cat.id} value={cat.id}>
                      {cat.name}
                    </option>
                  ))}
                </select>
              </div>

              {/* Recipient Address */}
              <div>
                <label className="block text-sm font-semibold text-gray-700 mb-2">
                  Recipient Address *
                </label>
                <input
                  type="text"
                  name="recipient"
                  required
                  value={formData.recipient}
                  onChange={handleInputChange}
                  placeholder="0x..."
                  pattern="0x[a-fA-F0-9]{40}"
                  className="w-full px-4 py-3 bg-white/50 border border-gray-300 rounded-xl focus:outline-none focus:ring-2 focus:ring-cyan-500 focus:border-transparent transition-all font-mono text-sm"
                />
                <p className="text-xs text-gray-500 mt-1">
                  Ethereum address that will receive the yield payouts
                </p>
              </div>

              {/* Funding Goals */}
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-semibold text-gray-700 mb-2">
                    Target Amount (ETH) *
                  </label>
                  <input
                    type="number"
                    name="targetAmount"
                    required
                    step="0.01"
                    min="0.1"
                    value={formData.targetAmount}
                    onChange={handleInputChange}
                    placeholder="10.0"
                    className="w-full px-4 py-3 bg-white/50 border border-gray-300 rounded-xl focus:outline-none focus:ring-2 focus:ring-cyan-500 focus:border-transparent transition-all"
                  />
                </div>
                <div>
                  <label className="block text-sm font-semibold text-gray-700 mb-2">
                    Min Stake (ETH) *
                  </label>
                  <input
                    type="number"
                    name="minStake"
                    required
                    step="0.001"
                    min="0.001"
                    value={formData.minStake}
                    onChange={handleInputChange}
                    placeholder="0.01"
                    className="w-full px-4 py-3 bg-white/50 border border-gray-300 rounded-xl focus:outline-none focus:ring-2 focus:ring-cyan-500 focus:border-transparent transition-all"
                  />
                </div>
              </div>

              {/* Fundraising Duration */}
              <div>
                <label className="block text-sm font-semibold text-gray-700 mb-2">
                  Fundraising Duration (days) *
                </label>
                <input
                  type="number"
                  name="fundraisingDuration"
                  required
                  min="7"
                  max="365"
                  value={formData.fundraisingDuration}
                  onChange={handleInputChange}
                  className="w-full px-4 py-3 bg-white/50 border border-gray-300 rounded-xl focus:outline-none focus:ring-2 focus:ring-cyan-500 focus:border-transparent transition-all"
                />
              </div>

              {/* IPFS Upload Status */}
              {metadataHash && (
                <div className="p-4 bg-emerald-50 border border-emerald-200 rounded-xl flex items-start space-x-3">
                  <CheckCircle className="w-5 h-5 text-emerald-600 flex-shrink-0 mt-0.5" />
                  <div className="flex-1">
                    <p className="text-sm font-semibold text-emerald-900">Metadata Uploaded</p>
                    <p className="text-xs text-emerald-700 font-mono break-all">{metadataHash}</p>
                  </div>
                </div>
              )}

              {uploadError && (
                <div className="p-4 bg-red-50 border border-red-200 rounded-xl flex items-start space-x-3">
                  <AlertCircle className="w-5 h-5 text-red-600 flex-shrink-0 mt-0.5" />
                  <p className="text-sm text-red-900">{uploadError}</p>
                </div>
              )}

              {/* Submit Button */}
              <div className="pt-4">
                <Button
                  type="submit"
                  disabled={!isConnected || isPending || isUploading}
                  className="w-full bg-gradient-to-r from-emerald-600 to-cyan-600 text-white py-4 rounded-xl font-bold text-lg hover:from-emerald-700 hover:to-cyan-700 transition-all duration-300 shadow-lg hover:shadow-xl flex items-center justify-center space-x-3"
                  loading={isPending || isUploading}
                >
                  {isUploading ? (
                    <>
                      <Upload className="w-5 h-5 animate-pulse" />
                      <span>Uploading Metadata...</span>
                    </>
                  ) : isPending ? (
                    <>
                      <Loader className="w-5 h-5 animate-spin" />
                      <span>Submitting Campaign...</span>
                    </>
                  ) : (
                    <>
                      <Heart className="w-5 h-5" />
                      <span>Submit Campaign for Review</span>
                    </>
                  )}
                </Button>

                {!isConnected && (
                  <p className="text-center text-sm text-gray-600 mt-3">
                    Please connect your wallet to submit a campaign
                  </p>
                )}
              </div>

              {/* Success Message */}
              {isSuccess && (
                <motion.div
                  initial={{ opacity: 0, scale: 0.9 }}
                  animate={{ opacity: 1, scale: 1 }}
                  className="p-4 bg-emerald-50 border border-emerald-200 rounded-xl"
                >
                  <div className="flex items-center space-x-3">
                    <CheckCircle className="w-6 h-6 text-emerald-600" />
                    <div>
                      <p className="font-semibold text-emerald-900">Campaign Submitted!</p>
                      <p className="text-sm text-emerald-700">
                        Your campaign is pending approval. You'll be notified once it's reviewed.
                      </p>
                    </div>
                  </div>
                </motion.div>
              )}

              {/* Error Message */}
              {error && (
                <div className="p-4 bg-red-50 border border-red-200 rounded-xl">
                  <div className="flex items-start space-x-3">
                    <AlertCircle className="w-5 h-5 text-red-600 flex-shrink-0 mt-0.5" />
                    <div>
                      <p className="font-semibold text-red-900">Submission Failed</p>
                      <p className="text-sm text-red-700">{error.message}</p>
                    </div>
                  </div>
                </div>
              )}
            </form>
          </motion.div>

          {/* Info Panel */}
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.5, delay: 0.2 }}
            className="mt-8 p-6 bg-white/40 backdrop-blur-md border border-white/60 rounded-xl"
          >
            <h3 className="font-bold text-gray-900 mb-3">How it works:</h3>
            <ol className="space-y-2 text-sm text-gray-700">
              <li className="flex items-start">
                <span className="font-bold text-cyan-600 mr-2">1.</span>
                <span>Submit your campaign with details and recipient address</span>
              </li>
              <li className="flex items-start">
                <span className="font-bold text-cyan-600 mr-2">2.</span>
                <span>Campaign admin reviews and approves your submission</span>
              </li>
              <li className="flex items-start">
                <span className="font-bold text-cyan-600 mr-2">3.</span>
                <span>Once approved, donors can allocate their vault yield to your campaign</span>
              </li>
              <li className="flex items-start">
                <span className="font-bold text-cyan-600 mr-2">4.</span>
                <span>Yield is automatically distributed to your recipient address</span>
              </li>
            </ol>
          </motion.div>
        </motion.div>
      </div>
    </div>
  );
}
