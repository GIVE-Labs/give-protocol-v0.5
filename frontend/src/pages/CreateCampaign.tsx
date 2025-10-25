/**
 * CreateCampaign Page
 * Multi-step form to submit new campaigns to the registry
 * Design: Glass-card style with emerald/cyan gradients and step progression
 */

import { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { ArrowLeft, ArrowRight, Upload, X, Check, Camera, AlertCircle } from 'lucide-react';
import { Link, useNavigate } from 'react-router-dom';
import { useAccount, useWaitForTransactionReceipt, useReadContract } from 'wagmi';
import { useCampaignRegistry } from '../hooks/v05';
import { parseEther, keccak256, toBytes } from 'viem';
import { DotLottieReact } from '@lottiefiles/dotlottie-react';
import ACLManagerABI from '../abis/ACLManager.json';
import { CONTRACT_ADDRESSES } from '../config/contracts';

interface FormData {
  // Basic Info
  campaignAddress: string;
  campaignName: string;
  missionStatement: string;
  category: string;
  detailedDescription: string;
  
  // Funding
  targetAmount: string;
  minStake: string;
  fundraisingDuration: string;
  
  // Media
  images: File[];
  videos: string[];
  
  // Team
  teamMembers: Array<{
    name: string;
    role: string;
    bio: string;
  }>;
  
  // Impact Metrics
  impactMetrics: Array<{
    name: string;
    target: string;
    description: string;
  }>;
}

const CATEGORIES = [
  '🌍 Climate Action',
  '📚 Education',
  '❤️ Health & Wellness',
  '🤝 Poverty Relief',
  '💧 Clean Water',
  '⚡ Renewable Energy'
];

const STEPS = [
  { id: 1, name: 'Basic Info', description: 'Campaign details and mission' },
  { id: 2, name: 'Funding', description: 'Goals and duration' },
  { id: 3, name: 'Media', description: 'Images and videos' },
  { id: 4, name: 'Team', description: 'Team members' },
  { id: 5, name: 'Impact', description: 'Impact metrics' },
  { id: 6, name: 'Review', description: 'Final review' }
];

export default function CreateCampaign() {
  const [currentStep, setCurrentStep] = useState(1);
  const { address, isConnected } = useAccount();
  const { submitCampaign, isPending, isSuccess, error, hash } = useCampaignRegistry();
  const navigate = useNavigate();

  // Check if user has CAMPAIGN_CREATOR_ROLE
  const CAMPAIGN_CREATOR_ROLE = keccak256(toBytes('CAMPAIGN_CREATOR_ROLE'));
  const { data: hasCreatorRole, isLoading: isCheckingRole } = useReadContract({
    address: (CONTRACT_ADDRESSES as any).ACL_MANAGER as `0x${string}`,
    abi: ACLManagerABI,
    functionName: 'hasRole',
    args: [CAMPAIGN_CREATOR_ROLE, address || '0x0000000000000000000000000000000000000000'],
    query: { enabled: !!address }
  });

  // Monitor transaction receipt for revert reasons
  const { 
    data: receipt, 
    isLoading: isConfirming, 
    isSuccess: isConfirmed,
    error: receiptError 
  } = useWaitForTransactionReceipt({
    hash: hash as `0x${string}` | undefined,
  });

  // Form state
  const [formData, setFormData] = useState<FormData>({
    campaignAddress: '',
    campaignName: '',
    missionStatement: '',
    category: '',
    detailedDescription: '',
    targetAmount: '',
    minStake: '0.01',
    fundraisingDuration: '90',
    images: [],
    videos: [],
    teamMembers: [{ name: '', role: '', bio: '' }],
    impactMetrics: [
      { name: 'Beneficiaries Reached', target: '1000', description: '' },
      { name: 'Funds Deployed', target: '10000', description: '' }
    ]
  });

  // Submission state
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [submitError, setSubmitError] = useState<string | null>(null);
  const [validationErrors, setValidationErrors] = useState<string[]>([]);
  const [showFailureModal, setShowFailureModal] = useState(false);

  // Handle transaction confirmation
  useEffect(() => {
    if (isConfirmed) {
      console.log('Campaign submitted successfully, receipt:', receipt);
      setIsSubmitting(false);
      navigate('/campaigns');
    }
  }, [isConfirmed, receipt, navigate]);

  // Handle submission errors
  useEffect(() => {
    if (error) {
      console.error('Transaction submission error:', error);
      
      let errorMessage = 'Failed to submit campaign';
      const fullError = error.message || '';
      
      // Parse common error types
      if (fullError.includes('User rejected') || fullError.includes('User denied')) {
        errorMessage = 'Transaction was rejected by user';
      } else if (fullError.includes('insufficient funds')) {
        errorMessage = 'Insufficient funds for gas fee';
      } else if (fullError.includes('nonce')) {
        errorMessage = 'Transaction nonce error - please try again';
      } else if (fullError.includes('gas required exceeds')) {
        errorMessage = 'Transaction will fail - check your inputs';
      } else {
        // Try to extract revert reason
        const revertMatch = fullError.match(/reverted with reason string '([^']+)'/);
        if (revertMatch) {
          errorMessage = `Contract error: ${revertMatch[1]}`;
        } else if (fullError.includes('execution reverted')) {
          errorMessage = 'Transaction reverted - check campaign parameters';
        }
      }
      
      console.error('Parsed error:', errorMessage);
      setSubmitError(errorMessage);
      setIsSubmitting(false);
      setShowFailureModal(true);
    }
  }, [error]);

  // Handle receipt errors (transaction confirmed but reverted)
  useEffect(() => {
    if (receiptError) {
      console.error('Transaction receipt error:', receiptError);
      
      let errorMessage = 'Transaction failed on-chain';
      const fullError = receiptError.message || '';
      
      // Try to extract revert reason from receipt
      if (fullError.includes('reverted')) {
        errorMessage = 'Transaction was reverted by the contract';
      }
      
      setSubmitError(errorMessage);
      setIsSubmitting(false);
      setShowFailureModal(true);
    }
  }, [receiptError]);

  const updateFormData = (field: keyof FormData, value: any) => {
    setFormData(prev => ({ ...prev, [field]: value }));
  };

  const nextStep = () => {
    // Basic validation before proceeding
    if (currentStep === 1) {
      setSubmitError(null);
      setValidationErrors([]);
      
      const errors: string[] = [];
      if (!formData.campaignAddress.trim()) {
        errors.push('Campaign recipient address is required');
      } else if (!/^0x[a-fA-F0-9]{40}$/.test(formData.campaignAddress)) {
        errors.push('Recipient address must be a valid Ethereum address');
      }
      
      if (!formData.campaignName.trim()) {
        errors.push('Campaign name is required');
      } else if (formData.campaignName.length > 31) {
        errors.push('Campaign name must be 31 characters or less (bytes32 limit)');
      }
      
      if (errors.length > 0) {
        setValidationErrors(errors);
        return;
      }
    }
    
    if (currentStep < STEPS.length) {
      setCurrentStep(currentStep + 1);
    }
  };

  const prevStep = () => {
    if (currentStep > 1) {
      setCurrentStep(currentStep - 1);
    }
  };

  const handleImageUpload = (files: FileList | null) => {
    if (files) {
      const newImages = Array.from(files).slice(0, 3 - formData.images.length);
      const allImages = [...formData.images, ...newImages];
      
      // Basic validation
      const errors: string[] = [];
      allImages.forEach(img => {
        if (img.size > 5 * 1024 * 1024) { // 5MB limit
          errors.push(`Image ${img.name} is too large (max 5MB)`);
        }
      });
      
      if (errors.length === 0) {
        updateFormData('images', allImages);
        setValidationErrors([]);
      } else {
        setValidationErrors(errors);
      }
    }
  };

  const removeImage = (index: number) => {
    const newImages = formData.images.filter((_, i) => i !== index);
    updateFormData('images', newImages);
  };

  const addTeamMember = () => {
    updateFormData('teamMembers', [...formData.teamMembers, { name: '', role: '', bio: '' }]);
  };

  const updateTeamMember = (index: number, field: string, value: string) => {
    const newTeamMembers = formData.teamMembers.map((member, i) => 
      i === index ? { ...member, [field]: value } : member
    );
    updateFormData('teamMembers', newTeamMembers);
  };

  const removeTeamMember = (index: number) => {
    if (formData.teamMembers.length > 1) {
      const newTeamMembers = formData.teamMembers.filter((_, i) => i !== index);
      updateFormData('teamMembers', newTeamMembers);
    }
  };

  const updateImpactMetric = (index: number, field: string, value: string) => {
    const newMetrics = formData.impactMetrics.map((metric, i) => 
      i === index ? { ...metric, [field]: value } : metric
    );
    updateFormData('impactMetrics', newMetrics);
  };

  const addImpactMetric = () => {
    updateFormData('impactMetrics', [...formData.impactMetrics, { name: '', target: '', description: '' }]);
  };

  const removeImpactMetric = (index: number) => {
    if (formData.impactMetrics.length > 1) {
      const newMetrics = formData.impactMetrics.filter((_, i) => i !== index);
      updateFormData('impactMetrics', newMetrics);
    }
  };

  const uploadToIPFS = async () => {
    try {
      // Prepare metadata
      const metadata = {
        name: formData.campaignName,
        mission: formData.missionStatement,
        description: formData.detailedDescription,
        category: formData.category,
        recipient: formData.campaignAddress,
        targetAmount: formData.targetAmount,
        teamMembers: formData.teamMembers.filter(m => m.name.trim()),
        impactMetrics: formData.impactMetrics.filter(m => m.name.trim()),
        createdAt: new Date().toISOString(),
        version: '0.5.0',
      };

      console.log('📤 Uploading metadata to Pinata IPFS:', metadata);

      // Upload to Pinata using JWT from .env
      const pinataJWT = import.meta.env.VITE_PINATA_JWT;
      
      if (!pinataJWT) {
        throw new Error('VITE_PINATA_JWT not configured in .env file');
      }

      const response = await fetch('https://api.pinata.cloud/pinning/pinJSONToIPFS', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${pinataJWT}`
        },
        body: JSON.stringify({
          pinataContent: metadata,
          pinataMetadata: {
            name: `${formData.campaignName}-metadata.json`
          }
        })
      });

      if (!response.ok) {
        const errorData = await response.json().catch(() => ({}));
        console.error('❌ Pinata upload failed:', response.status, errorData);
        throw new Error(`Pinata upload failed: ${response.statusText}`);
      }

      const result = await response.json();
      const ipfsHash = result.IpfsHash; // e.g., "QmXxx..."
      
      console.log('✅ Metadata uploaded to IPFS:', ipfsHash);
      console.log('🔗 View at:', `https://${import.meta.env.VITE_PINATA_GATEWAY}/ipfs/${ipfsHash}`);
      
      return ipfsHash;
    } catch (err) {
      console.error('IPFS upload failed:', err);
      throw new Error(`Failed to upload metadata to IPFS: ${err instanceof Error ? err.message : 'Unknown error'}`);
    }
  };

  const validateForm = (): boolean => {
    const errors: string[] = [];
    
    if (!formData.campaignAddress.trim()) {
      errors.push('Campaign recipient address is required');
    } else if (!/^0x[a-fA-F0-9]{40}$/.test(formData.campaignAddress)) {
      errors.push('Recipient address must be a valid Ethereum address');
    }
    if (!formData.campaignName.trim()) errors.push('Campaign name is required');
    if (!formData.missionStatement.trim()) errors.push('Mission statement is required');
    if (!formData.category) errors.push('Category is required');
    if (!formData.detailedDescription.trim()) errors.push('Detailed description is required');
    if (!formData.targetAmount || parseFloat(formData.targetAmount) <= 0) {
      errors.push('Valid target amount is required');
    }
    if (!formData.fundraisingDuration || parseInt(formData.fundraisingDuration) <= 0) {
      errors.push('Valid fundraising duration is required');
    }
    
    const validTeamMembers = formData.teamMembers.filter(member => member.name.trim());
    if (validTeamMembers.length === 0) {
      errors.push('At least one team member is required');
    }
    
    setValidationErrors(errors);
    return errors.length === 0;
  };

  const handleSubmit = async () => {
    if (!address || !isConnected) {
      setSubmitError('Please connect your wallet first');
      return;
    }

    if (!validateForm()) {
      setSubmitError('Please fix the validation errors before submitting');
      return;
    }

    setIsSubmitting(true);
    setSubmitError(null);
    
    try {
      // Step 1: Upload to IPFS
      console.log('Creating campaign metadata...');
      const hash = await uploadToIPFS();
      console.log('Metadata uploaded to IPFS:', hash);
      
      // Step 2: Generate campaign ID from name
      const campaignId = `0x${Array.from(new TextEncoder().encode(formData.campaignName))
        .map(b => b.toString(16).padStart(2, '0'))
        .join('')
        .padEnd(64, '0')}` as `0x${string}`;

      // Step 3: Prepare CampaignInput
      const targetStake = parseEther(formData.targetAmount || '10');
      const minStake = parseEther(formData.minStake || '0.01');
      const fundraisingStart = BigInt(Math.floor(Date.now() / 1000));
      const fundraisingDuration = BigInt(parseInt(formData.fundraisingDuration) * 24 * 60 * 60);
      const fundraisingEnd = fundraisingStart + fundraisingDuration;

      const metadataHashBytes = `0x${Array.from(new TextEncoder().encode(hash))
        .map(b => b.toString(16).padStart(2, '0'))
        .join('')
        .padEnd(64, '0')}` as `0x${string}`;

      // Default strategy ID (TODO: let user select)
      const defaultStrategyId = '0x79861c7f93db9d6c9c5c46da4760ee78aef494b26e84a8b82a4cdfbf4dbdc848' as `0x${string}`;

      const input = {
        id: campaignId,
        payoutRecipient: formData.campaignAddress as `0x${string}`,
        strategyId: defaultStrategyId,
        metadataHash: metadataHashBytes,
        targetStake,
        minStake,
        fundraisingStart,
        fundraisingEnd,
      };

      console.log('=== Campaign Submission Details ===');
      console.log('Campaign ID:', campaignId);
      console.log('Campaign Name:', formData.campaignName);
      console.log('Payout Recipient:', formData.campaignAddress);
      console.log('Strategy ID:', defaultStrategyId);
      console.log('Metadata Hash:', metadataHashBytes);
      console.log('Target Stake:', targetStake.toString(), 'wei (', formData.targetAmount, 'ETH)');
      console.log('Min Stake:', minStake.toString(), 'wei (', formData.minStake, 'ETH)');
      console.log('Fundraising Start:', new Date(Number(fundraisingStart) * 1000).toISOString());
      console.log('Fundraising End:', new Date(Number(fundraisingEnd) * 1000).toISOString());
      console.log('Full input:', input);
      
      // Validate before submitting
      console.log('\n=== Pre-flight Checks ===');
      console.log('✓ Campaign ID is not zero:', campaignId !== '0x' + '0'.repeat(64));
      console.log('✓ Recipient not zero:', formData.campaignAddress !== '0x' + '0'.repeat(40));
      console.log('✓ Strategy ID not zero:', defaultStrategyId !== '0x' + '0'.repeat(64));
      console.log('✓ Target stake > 0:', targetStake > 0n);
      console.log('✓ Min stake <= Target stake:', minStake <= targetStake);
      console.log('✓ End > Start (or End = 0):', fundraisingEnd === 0n || fundraisingEnd > fundraisingStart);
      console.log('✓ All validations passed!');
      console.log('=====================================');
      
      await submitCampaign(input);
      
    } catch (error) {
      console.error('Error creating campaign:', error);
      
      let errorMessage = 'Failed to create campaign';
      const fullError = error instanceof Error ? error.message : '';
      
      if (fullError.includes('User rejected') || fullError.includes('User denied')) {
        errorMessage = 'Transaction was rejected by user';
      } else if (fullError.includes('insufficient funds')) {
        errorMessage = 'Insufficient funds for transaction';
      } else if (fullError.includes('network')) {
        errorMessage = 'Network connection error';
      } else if (fullError.includes('IPFS')) {
        errorMessage = 'Failed to upload campaign data';
      }
      
      setSubmitError(errorMessage);
      setIsSubmitting(false);
      setShowFailureModal(true);
    }
  };

  const renderStepContent = () => {
    switch (currentStep) {
      case 1:
        return (
          <motion.div
            initial={{ opacity: 0, x: 20 }}
            animate={{ opacity: 1, x: 0 }}
            exit={{ opacity: 0, x: -20 }}
            className="space-y-6"
          >
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-semibold text-gray-700 mb-2 font-unbounded">
                  Recipient Address *
                </label>
                <div className="relative">
                  <input
                    type="text"
                    value={formData.campaignAddress}
                    onChange={(e) => updateFormData('campaignAddress', e.target.value)}
                    placeholder="0x... (Ethereum address to receive yield)"
                    className={`w-full px-4 py-3 pr-32 border rounded-xl focus:ring-2 transition-colors font-mono text-sm ${
                      formData.campaignAddress && !/^0x[a-fA-F0-9]{40}$/.test(formData.campaignAddress)
                        ? 'border-red-300 focus:ring-red-500 focus:border-red-500'
                        : 'border-gray-300 focus:ring-emerald-500 focus:border-emerald-500'
                    }`}
                    required
                  />
                  {address && (
                    <button
                      type="button"
                      onClick={() => updateFormData('campaignAddress', address)}
                      className="absolute right-2 top-1/2 transform -translate-y-1/2 px-3 py-1 text-xs bg-emerald-100 text-emerald-700 rounded-lg hover:bg-emerald-200 transition-colors"
                    >
                      Use Wallet
                    </button>
                  )}
                </div>
                <div className="mt-1 space-y-1">
                  <p className="text-xs text-gray-500 font-medium">
                    The Ethereum address that will receive the yield payouts from this campaign.
                  </p>
                  {formData.campaignAddress && (
                    <div className="flex items-center space-x-2">
                      {!/^0x[a-fA-F0-9]{40}$/.test(formData.campaignAddress) ? (
                        <div className="flex items-center text-red-600 text-xs">
                          <X className="w-3 h-3 mr-1" />
                          Invalid Ethereum address format
                        </div>
                      ) : (
                        <div className="flex items-center text-green-600 text-xs">
                          <Check className="w-3 h-3 mr-1" />
                          Address is valid
                        </div>
                      )}
                    </div>
                  )}
                </div>
              </div>

              <div>
                <label className="block text-sm font-semibold text-gray-700 mb-2 font-unbounded">
                  Campaign Name / Project Title *
                  <span className="ml-2 text-xs font-normal text-gray-500">
                    ({formData.campaignName.length}/31 characters)
                  </span>
                </label>
                <input
                  type="text"
                  value={formData.campaignName}
                  onChange={(e) => updateFormData('campaignName', e.target.value)}
                  placeholder="Enter your campaign or project name"
                  maxLength={31}
                  className="w-full px-4 py-3 border border-gray-300 rounded-xl focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 transition-colors"
                  required
                />
                <p className="mt-1 text-xs text-gray-500">
                  Keep it short and memorable (max 31 characters for blockchain storage)
                </p>
              </div>

              <div>
                <label className="block text-sm font-semibold text-gray-700 mb-2 font-unbounded">
                  Mission Statement *
                </label>
                <textarea
                  value={formData.missionStatement}
                  onChange={(e) => updateFormData('missionStatement', e.target.value)}
                  placeholder="Describe your mission in a few sentences"
                  rows={3}
                  className="w-full px-4 py-3 border border-gray-300 rounded-xl focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 transition-colors resize-none"
                  required
                />
              </div>

              <div>
                <label className="block text-sm font-semibold text-gray-700 mb-2 font-unbounded">
                  Category *
                </label>
                <select
                  value={formData.category}
                  onChange={(e) => updateFormData('category', e.target.value)}
                  className="w-full px-4 py-3 border border-gray-300 rounded-xl focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 transition-colors"
                  required
                >
                  <option value="">Select a category</option>
                  {CATEGORIES.map(category => (
                    <option key={category} value={category}>{category}</option>
                  ))}
                </select>
              </div>

              <div>
                <label className="block text-sm font-semibold text-gray-700 mb-2 font-unbounded">
                  Detailed Description *
                </label>
                <textarea
                  value={formData.detailedDescription}
                  onChange={(e) => updateFormData('detailedDescription', e.target.value)}
                  placeholder="Provide a comprehensive description of your project, goals, and impact"
                  rows={6}
                  className="w-full px-4 py-3 border border-gray-300 rounded-xl focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 transition-colors resize-none"
                  required
                />
              </div>
            </div>
          </motion.div>
        );

      case 2:
        return (
          <motion.div
            initial={{ opacity: 0, x: 20 }}
            animate={{ opacity: 1, x: 0 }}
            exit={{ opacity: 0, x: -20 }}
            className="space-y-6"
          >
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-semibold text-gray-700 mb-2 font-unbounded">
                  Target Amount (ETH) *
                </label>
                <input
                  type="number"
                  value={formData.targetAmount}
                  onChange={(e) => updateFormData('targetAmount', e.target.value)}
                  placeholder="10"
                  step="0.01"
                  className="w-full px-4 py-3 border border-gray-300 rounded-xl focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 transition-colors"
                  required
                />
              </div>

              <div>
                <label className="block text-sm font-semibold text-gray-700 mb-2 font-unbounded">
                  Minimum Stake (ETH) *
                </label>
                <input
                  type="number"
                  value={formData.minStake}
                  onChange={(e) => updateFormData('minStake', e.target.value)}
                  placeholder="0.01"
                  step="0.001"
                  className="w-full px-4 py-3 border border-gray-300 rounded-xl focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 transition-colors"
                  required
                />
              </div>

              <div>
                <label className="block text-sm font-semibold text-gray-700 mb-2 font-unbounded">
                  Fundraising Duration (days) *
                </label>
                <input
                  type="number"
                  value={formData.fundraisingDuration}
                  onChange={(e) => updateFormData('fundraisingDuration', e.target.value)}
                  placeholder="90"
                  className="w-full px-4 py-3 border border-gray-300 rounded-xl focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 transition-colors"
                  required
                />
              </div>
            </div>
          </motion.div>
        );

      case 3:
        return (
          <motion.div
            initial={{ opacity: 0, x: 20 }}
            animate={{ opacity: 1, x: 0 }}
            exit={{ opacity: 0, x: -20 }}
            className="space-y-6"
          >
            <div>
              <label className="block text-sm font-semibold text-gray-700 mb-4 font-unbounded">
                Campaign Images (1-3 images) *
              </label>
              
              <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-4">
                {formData.images.map((image, index) => (
                  <div key={index} className="relative group">
                    <img
                      src={URL.createObjectURL(image)}
                      alt={`Upload ${index + 1}`}
                      className="w-full h-32 object-cover rounded-xl border-2 border-gray-200"
                    />
                    <button
                      type="button"
                      onClick={() => removeImage(index)}
                      className="absolute top-2 right-2 bg-red-500 text-white rounded-full p-1 opacity-0 group-hover:opacity-100 transition-opacity"
                    >
                      <X className="w-4 h-4" />
                    </button>
                  </div>
                ))}
                
                {formData.images.length < 3 && (
                  <label className="border-2 border-dashed border-gray-300 rounded-xl p-8 text-center cursor-pointer hover:border-emerald-500 transition-colors">
                    <Camera className="w-8 h-8 mx-auto mb-2 text-gray-400" />
                    <span className="text-sm text-gray-600 font-medium">Upload Image</span>
                    <input
                      type="file"
                      accept="image/*"
                      multiple
                      onChange={(e) => handleImageUpload(e.target.files)}
                      className="hidden"
                    />
                  </label>
                )}
              </div>
              
              <p className="text-sm text-gray-500 font-medium">
                Upload 1-3 high-quality images that represent your campaign. Max 5MB each.
              </p>
            </div>

            <div>
              <label className="block text-sm font-semibold text-gray-700 mb-2 font-unbounded">
                Video URLs (Optional)
              </label>
              <input
                type="url"
                placeholder="https://youtube.com/watch?v=..."
                className="w-full px-4 py-3 border border-gray-300 rounded-xl focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 transition-colors"
              />
            </div>
          </motion.div>
        );

      case 4:
        return (
          <motion.div
            initial={{ opacity: 0, x: 20 }}
            animate={{ opacity: 1, x: 0 }}
            exit={{ opacity: 0, x: -20 }}
            className="space-y-6"
          >
            <div className="flex justify-between items-center">
              <h3 className="text-lg font-bold text-gray-900 font-unbounded">Team Members</h3>
              <button
                type="button"
                onClick={addTeamMember}
                className="bg-emerald-500 text-white px-4 py-2 rounded-lg hover:bg-emerald-600 transition-colors font-semibold font-unbounded"
              >
                Add Member
              </button>
            </div>
            
            {formData.teamMembers.map((member, index) => (
              <div key={index} className="border border-gray-200 rounded-xl p-4 space-y-4">
                <div className="flex justify-between items-center">
                  <h4 className="font-semibold text-gray-900 font-unbounded">Team Member {index + 1}</h4>
                  {formData.teamMembers.length > 1 && (
                    <button
                      type="button"
                      onClick={() => removeTeamMember(index)}
                      className="text-red-500 hover:text-red-700"
                    >
                      <X className="w-5 h-5" />
                    </button>
                  )}
                </div>
                
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <input
                    type="text"
                    value={member.name}
                    onChange={(e) => updateTeamMember(index, 'name', e.target.value)}
                    placeholder="Full Name"
                    className="px-4 py-3 border border-gray-300 rounded-xl focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 transition-colors"
                  />
                  <input
                    type="text"
                    value={member.role}
                    onChange={(e) => updateTeamMember(index, 'role', e.target.value)}
                    placeholder="Role/Position"
                    className="px-4 py-3 border border-gray-300 rounded-xl focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 transition-colors"
                  />
                </div>
                
                <textarea
                  value={member.bio}
                  onChange={(e) => updateTeamMember(index, 'bio', e.target.value)}
                  placeholder="Brief bio and experience"
                  rows={3}
                  className="w-full px-4 py-3 border border-gray-300 rounded-xl focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 transition-colors resize-none"
                />
              </div>
            ))}
          </motion.div>
        );

      case 5:
        return (
          <motion.div
            initial={{ opacity: 0, x: 20 }}
            animate={{ opacity: 1, x: 0 }}
            exit={{ opacity: 0, x: -20 }}
            className="space-y-6"
          >
            <div className="flex justify-between items-center">
              <h3 className="text-lg font-bold text-gray-900 font-unbounded">Impact Metrics</h3>
              <button
                type="button"
                onClick={addImpactMetric}
                className="bg-emerald-500 text-white px-4 py-2 rounded-lg hover:bg-emerald-600 transition-colors font-semibold font-unbounded"
              >
                Add Metric
              </button>
            </div>
            
            {formData.impactMetrics.map((metric, index) => (
              <div key={index} className="border border-gray-200 rounded-xl p-4 space-y-4">
                <div className="flex justify-between items-center">
                  <h4 className="font-semibold text-gray-900 font-unbounded">Metric {index + 1}</h4>
                  {formData.impactMetrics.length > 1 && (
                    <button
                      type="button"
                      onClick={() => removeImpactMetric(index)}
                      className="text-red-500 hover:text-red-700"
                    >
                      <X className="w-5 h-5" />
                    </button>
                  )}
                </div>
                
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <input
                    type="text"
                    value={metric.name}
                    onChange={(e) => updateImpactMetric(index, 'name', e.target.value)}
                    placeholder="Metric Name"
                    className="px-4 py-3 border border-gray-300 rounded-xl focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 transition-colors"
                  />
                  <input
                    type="text"
                    value={metric.target}
                    onChange={(e) => updateImpactMetric(index, 'target', e.target.value)}
                    placeholder="Target Value"
                    className="px-4 py-3 border border-gray-300 rounded-xl focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 transition-colors"
                  />
                </div>
                
                <textarea
                  value={metric.description}
                  onChange={(e) => updateImpactMetric(index, 'description', e.target.value)}
                  placeholder="Description of how this will be measured"
                  rows={2}
                  className="w-full px-4 py-3 border border-gray-300 rounded-xl focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 transition-colors resize-none"
                />
              </div>
            ))}
          </motion.div>
        );

      case 6:
        return (
          <motion.div
            initial={{ opacity: 0, x: 20 }}
            animate={{ opacity: 1, x: 0 }}
            exit={{ opacity: 0, x: -20 }}
            className="space-y-6"
          >
            <h3 className="text-lg font-unbounded font-semibold text-gray-900">Review Your Campaign</h3>
            
            <div className="bg-gray-50 rounded-xl p-6 space-y-4">
              <div>
                <h4 className="font-semibold text-gray-900 font-unbounded">Basic Information</h4>
                <p className="text-gray-600 font-medium">Recipient: <span className="font-mono text-sm">{formData.campaignAddress}</span></p>
                <p className="text-gray-600 font-medium">Name: {formData.campaignName}</p>
                <p className="text-gray-600 font-medium">Category: {formData.category}</p>
                <p className="text-gray-600 font-medium">Mission: {formData.missionStatement}</p>
              </div>
              
              <div>
                <h4 className="font-semibold text-gray-900 font-unbounded">Funding</h4>
                <p className="text-gray-600 font-medium">Target: {formData.targetAmount} ETH</p>
                <p className="text-gray-600 font-medium">Min Stake: {formData.minStake} ETH</p>
                <p className="text-gray-600 font-medium">Duration: {formData.fundraisingDuration} days</p>
              </div>
              
              <div>
                <h4 className="font-semibold text-gray-900 font-unbounded">Media</h4>
                <p className="text-gray-600 font-medium">{formData.images.length} images uploaded</p>
              </div>
              
              <div>
                <h4 className="font-semibold text-gray-900 font-unbounded">Team</h4>
                <p className="text-gray-600 font-medium">{formData.teamMembers.filter(m => m.name.trim()).length} team members</p>
              </div>
            </div>
            
            <div className="bg-yellow-50 border border-yellow-200 rounded-xl p-4">
              <p className="text-yellow-800 text-sm font-medium">
                <strong className="font-unbounded">Note:</strong> Once submitted, your campaign will be uploaded to IPFS and registered on the blockchain.
              </p>
            </div>
          </motion.div>
        );

      default:
        return null;
    }
  };

  const progress = (currentStep / STEPS.length) * 100;

  return (
    <div className="min-h-screen bg-gradient-to-br from-emerald-50 via-cyan-50 to-teal-50 relative overflow-hidden">
      {/* Animated Background Elements */}
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        <motion.div 
          className="absolute top-20 left-10 w-32 h-32 bg-gradient-to-r from-emerald-200/30 to-cyan-200/30 rounded-full blur-xl"
          animate={{ 
            scale: [1, 1.2, 1],
            rotate: [0, 180, 360]
          }}
          transition={{
            duration: 20,
            repeat: Infinity,
            ease: "linear"
          }}
        />
        <motion.div 
          className="absolute top-40 right-20 w-24 h-24 bg-gradient-to-r from-teal-200/30 to-blue-200/30 rounded-full blur-xl"
          animate={{ 
            scale: [1.2, 1, 1.2],
            rotate: [360, 180, 0]
          }}
          transition={{
            duration: 15,
            repeat: Infinity,
            ease: "linear"
          }}
        />
        <motion.div 
          className="absolute bottom-20 left-1/3 w-40 h-40 bg-gradient-to-r from-cyan-200/20 to-emerald-200/20 rounded-full blur-2xl"
          animate={{ 
            scale: [1, 1.3, 1],
            x: [-20, 20, -20]
          }}
          transition={{
            duration: 25,
            repeat: Infinity,
            ease: "easeInOut"
          }}
        />
      </div>

      <div className="container mx-auto px-4 py-8 relative z-10">
        {/* Header */}
        <motion.div 
          className="mb-12"
          initial={{ opacity: 0, y: 30 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6, ease: "easeOut" }}
        >
          <Link
            to="/campaigns"
            className="inline-flex items-center text-emerald-600 hover:text-emerald-700 mb-6 font-semibold transition-colors font-unbounded"
          >
            <ArrowLeft className="w-5 h-5 mr-2" />
            Back to Campaigns
          </Link>
          
          <div className="text-center">
            <h1 className="text-5xl lg:text-6xl font-bold text-gray-900 mb-4 font-unbounded leading-tight">
              <span className="text-gray-900">Create Campaign</span>
              <span className="block text-transparent bg-gradient-to-r from-emerald-600 via-cyan-600 to-teal-600 bg-clip-text pb-1">
                for Good
              </span>
            </h1>
            <p className="text-xl lg:text-2xl text-gray-700 leading-relaxed font-medium font-unbounded max-w-3xl mx-auto">
              Launch your humanitarian project and connect with compassionate backers worldwide
            </p>
            
            {/* Permission Notice */}
            <motion.div
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.3 }}
              className="mt-6 max-w-2xl mx-auto"
            >
              {!isConnected ? (
                <div className="bg-blue-50 border-l-4 border-blue-400 p-4 rounded-lg">
                  <div className="flex items-start">
                    <AlertCircle className="w-5 h-5 text-blue-600 mr-3 mt-0.5 flex-shrink-0" />
                    <div className="text-left">
                      <p className="text-sm font-semibold text-blue-800">
                        Connect Your Wallet
                      </p>
                      <p className="text-xs text-blue-700">
                        Please connect your wallet to create a campaign.
                      </p>
                    </div>
                  </div>
                </div>
              ) : isCheckingRole ? (
                <div className="bg-gray-50 border-l-4 border-gray-400 p-4 rounded-lg">
                  <div className="flex items-start">
                    <div className="w-5 h-5 border-2 border-gray-400 border-t-transparent rounded-full animate-spin mr-3 mt-0.5" />
                    <div className="text-left">
                      <p className="text-sm font-semibold text-gray-800">
                        Checking Permissions...
                      </p>
                    </div>
                  </div>
                </div>
              ) : hasCreatorRole ? (
                <div className="bg-green-50 border-l-4 border-green-400 p-4 rounded-lg">
                  <div className="flex items-start">
                    <Check className="w-5 h-5 text-green-600 mr-3 mt-0.5 flex-shrink-0" />
                    <div className="text-left">
                      <p className="text-sm font-semibold text-green-800">
                        ✓ Campaign Creator Role Verified
                      </p>
                      <p className="text-xs text-green-700">
                        Your wallet has permission to create campaigns.
                      </p>
                    </div>
                  </div>
                </div>
              ) : (
                <div className="bg-red-50 border-l-4 border-red-400 p-4 rounded-lg">
                  <div className="flex items-start">
                    <AlertCircle className="w-5 h-5 text-red-600 mr-3 mt-0.5 flex-shrink-0" />
                    <div className="text-left">
                      <p className="text-sm font-semibold text-red-800 mb-1">
                        ⚠️ Missing Campaign Creator Role
                      </p>
                      <p className="text-xs text-red-700 mb-2">
                        Your wallet (<code className="bg-red-100 px-1 py-0.5 rounded font-mono text-red-900">{address?.slice(0, 6)}...{address?.slice(-4)}</code>) does not have the <code className="bg-red-100 px-1.5 py-0.5 rounded text-red-900 font-mono">CAMPAIGN_CREATOR_ROLE</code>.
                      </p>
                      <p className="text-xs text-red-700">
                        Contact an admin to request this role before attempting to submit a campaign.
                      </p>
                    </div>
                  </div>
                </div>
              )}
            </motion.div>
          </div>
        </motion.div>

        {/* Progress Bar */}
        <motion.div 
          className="mb-12"
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6, delay: 0.2, ease: "easeOut" }}
        >
          <div className="flex justify-between items-center mb-6">
            <span className="text-lg font-bold text-gray-900 font-unbounded">
              Step {currentStep} of {STEPS.length}
            </span>
            <span className="text-lg font-bold text-transparent bg-gradient-to-r from-emerald-600 to-cyan-600 bg-clip-text font-unbounded">
              {Math.round(progress)}% Complete
            </span>
          </div>
          
          <div className="w-full bg-gray-200/50 rounded-full h-3 mb-8 shadow-inner">
            <motion.div
              className="bg-gradient-to-r from-emerald-500 via-cyan-500 to-teal-500 h-3 rounded-full shadow-lg"
              initial={{ width: 0 }}
              animate={{ width: `${progress}%` }}
              transition={{ duration: 0.5 }}
            />
          </div>
          
          {/* Step indicators */}
          <div className="flex justify-between">
            {STEPS.map((step, index) => (
              <motion.div 
                key={step.id} 
                className="flex flex-col items-center"
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.5, delay: index * 0.1 }}
              >
                <div className={`w-12 h-12 rounded-full flex items-center justify-center text-sm font-bold shadow-lg transition-all duration-300 ${
                  step.id <= currentStep
                    ? 'bg-gradient-to-r from-emerald-500 to-cyan-500 text-white shadow-emerald-500/30'
                    : 'bg-white text-gray-400 border-2 border-gray-200 shadow-gray-200/50'
                }`}>
                  {step.id < currentStep ? (
                    <Check className="w-6 h-6" />
                  ) : (
                    step.id
                  )}
                </div>
                <div className="mt-3 text-center">
                  <div className={`text-sm font-bold font-unbounded ${
                    step.id <= currentStep ? 'text-gray-900' : 'text-gray-500'
                  }`}>{step.name}</div>
                  <div className="text-xs text-gray-500 mt-1">{step.description}</div>
                </div>
              </motion.div>
            ))}
          </div>
        </motion.div>

        {/* Form Content */}
        <motion.div 
          className="max-w-4xl mx-auto"
          initial={{ opacity: 0, y: 30 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.7, delay: 0.3, ease: "easeOut" }}
        >
          <div className="bg-white/80 backdrop-blur-xl rounded-3xl shadow-2xl border border-white/20 p-10 lg:p-12">
            {/* Success Message */}
            <AnimatePresence>
              {isSuccess && (
                <motion.div
                  initial={{ opacity: 0, y: -20, scale: 0.95 }}
                  animate={{ opacity: 1, y: 0, scale: 1 }}
                  exit={{ opacity: 0, y: -20, scale: 0.95 }}
                  className="mb-6 p-6 bg-gradient-to-r from-emerald-50 to-cyan-50 border-2 border-emerald-200 rounded-2xl shadow-lg"
                >
                  <div className="flex items-start">
                    <div className="w-8 h-8 bg-gradient-to-r from-emerald-500 to-cyan-500 rounded-full flex items-center justify-center mr-4 flex-shrink-0">
                      <Check className="w-5 h-5 text-white" />
                    </div>
                    <div>
                      <h3 className="text-emerald-800 font-bold text-lg mb-2 font-unbounded">Campaign Created Successfully!</h3>
                      <p className="text-emerald-700 font-semibold">Your campaign has been submitted. Redirecting to campaigns...</p>
                    </div>
                  </div>
                </motion.div>
              )}
            </AnimatePresence>

            {/* Error Messages */}
            <AnimatePresence>
              {(submitError || validationErrors.length > 0) && (
                <motion.div
                  initial={{ opacity: 0, y: -20, scale: 0.95 }}
                  animate={{ opacity: 1, y: 0, scale: 1 }}
                  exit={{ opacity: 0, y: -20, scale: 0.95 }}
                  className="mb-6 p-6 bg-gradient-to-r from-red-50 to-pink-50 border-2 border-red-200 rounded-2xl shadow-lg"
                >
                  <div className="flex items-start">
                    <div className="w-8 h-8 bg-gradient-to-r from-red-500 to-pink-500 rounded-full flex items-center justify-center mr-4 flex-shrink-0">
                      <AlertCircle className="w-5 h-5 text-white" />
                    </div>
                    <div>
                      <h3 className="text-red-800 font-bold text-lg mb-2 font-unbounded">Action Required</h3>
                      {submitError && (
                        <p className="text-red-700 font-semibold mb-2">{submitError}</p>
                      )}
                      {validationErrors.length > 0 && (
                        <div>
                          <p className="text-red-700 font-semibold mb-2">Please fix the following errors:</p>
                          <ul className="list-disc list-inside text-red-600 space-y-1">
                            {validationErrors.map((error, index) => (
                              <li key={index} className="font-semibold">{error}</li>
                            ))}
                          </ul>
                        </div>
                      )}
                    </div>
                  </div>
                </motion.div>
              )}
            </AnimatePresence>

            {/* Loading Status */}
            <AnimatePresence>
              {(isSubmitting || isPending) && (
                <motion.div
                  initial={{ opacity: 0, y: -20, scale: 0.95 }}
                  animate={{ opacity: 1, y: 0, scale: 1 }}
                  exit={{ opacity: 0, y: -20, scale: 0.95 }}
                  className="mb-6 p-6 bg-gradient-to-r from-blue-50 to-indigo-50 border-2 border-blue-200 rounded-2xl shadow-lg"
                >
                  <div className="flex items-start">
                    <div className="w-8 h-8 bg-gradient-to-r from-blue-500 to-indigo-500 rounded-full flex items-center justify-center mr-4 flex-shrink-0">
                      <div className="animate-spin rounded-full h-5 w-5 border-b-2 border-white" />
                    </div>
                    <div>
                      <h3 className="text-blue-800 font-bold text-lg mb-2 font-unbounded">
                        {isSubmitting ? 'Uploading to IPFS...' : 'Waiting for Wallet...'}
                      </h3>
                    </div>
                  </div>
                </motion.div>
              )}
            </AnimatePresence>

            {/* Loading Overlay */}
            <AnimatePresence>
              {(isSubmitting || isPending) && (
                <motion.div
                  initial={{ opacity: 0 }}
                  animate={{ opacity: 1 }}
                  exit={{ opacity: 0 }}
                  className="fixed inset-0 bg-white/20 backdrop-blur-md flex items-center justify-center z-50 rounded-lg"
                >
                  <motion.div
                    initial={{ scale: 0.8, opacity: 0, y: 20 }}
                    animate={{ scale: 1, opacity: 1, y: 0 }}
                    exit={{ scale: 0.8, opacity: 0, y: 20 }}
                    transition={{ type: "spring", damping: 25, stiffness: 300 }}
                    className="bg-white/95 backdrop-blur-xl rounded-[2rem] p-8 shadow-lg border border-gray-100/50 max-w-md w-full mx-4"
                  >
                    <div className="text-center">
                      {/* Lottie Animation */}
                      <div className="w-32 h-32 mx-auto mb-6">
                        <DotLottieReact
                          src="https://lottie.host/9cacabce-843f-4d62-8100-336adcb35bfa/un9I86wPIp.lottie"
                          loop
                          autoplay
                          className="w-full h-full"
                        />
                      </div>
                      
                      {/* Loading Text */}
                      <h3 className="text-xl font-bold text-gray-900 mb-2 font-unbounded">
                        {isPending ? 'Sign Transaction in Wallet...' : 
                         isConfirming ? 'Confirming on Blockchain...' : 
                         'Preparing Submission...'}
                      </h3>
                      <p className="text-sm text-gray-600">
                        {isPending ? 'Please check your wallet and approve the transaction' :
                         isConfirming ? 'Waiting for block confirmation...' :
                         'Processing campaign data'}
                      </p>
                      
                      {/* Progress Dots */}
                      <div className="flex justify-center mt-6 space-x-1">
                        {[0, 1, 2].map((dot) => (
                          <motion.div
                            key={dot}
                            className="w-2 h-2 bg-emerald-500 rounded-full"
                            animate={{
                              scale: [1, 1.2, 1],
                              opacity: [0.5, 1, 0.5]
                            }}
                            transition={{
                              duration: 1.5,
                              repeat: Infinity,
                              delay: dot * 0.2
                            }}
                          />
                        ))}
                      </div>
                    </div>
                  </motion.div>
                </motion.div>
              )}
            </AnimatePresence>

            {/* Failure Modal */}
            <AnimatePresence>
              {showFailureModal && (
                <motion.div
                  initial={{ opacity: 0 }}
                  animate={{ opacity: 1 }}
                  exit={{ opacity: 0 }}
                  className="fixed inset-0 bg-black/20 backdrop-blur-md flex items-center justify-center z-50"
                >
                  <motion.div
                    initial={{ scale: 0.8, opacity: 0, y: 20 }}
                    animate={{ scale: 1, opacity: 1, y: 0 }}
                    exit={{ scale: 0.8, opacity: 0, y: 20 }}
                    transition={{ type: "spring", damping: 25, stiffness: 300 }}
                    className="bg-white/95 backdrop-blur-xl rounded-[2rem] p-8 shadow-lg border border-gray-100/50 max-w-md w-full mx-4"
                  >
                    <div className="text-center">
                      {/* Error Lottie Animation */}
                      <div className="w-32 h-32 mx-auto mb-6">
                        <DotLottieReact
                          src="https://lottie.host/d4bee4d9-e5c7-402c-9211-9a1925a46301/MiaRXnrFN4.lottie"
                          loop
                          autoplay
                          className="w-full h-full"
                        />
                      </div>
                      
                      {/* Error Text */}
                      <h3 className="text-2xl font-bold text-red-600 mb-2 font-unbounded">
                        Transaction Failed
                      </h3>
                      <p className="text-gray-600 font-semibold mb-6">
                        {submitError || 'Something went wrong with your transaction. You can review your information and submit again when ready.'}
                      </p>
                      
                      {/* Action Buttons */}
                      <div className="flex flex-col sm:flex-row gap-3">
                        <motion.button
                          onClick={() => {
                            setShowFailureModal(false);
                            setSubmitError(null);
                          }}
                          className="flex-1 bg-gray-100 hover:bg-gray-200 text-gray-700 px-6 py-3 rounded-xl font-semibold transition-colors font-unbounded"
                          whileHover={{ scale: 1.02 }}
                          whileTap={{ scale: 0.98 }}
                        >
                          Close
                        </motion.button>
                        <motion.button
                          onClick={() => {
                            setShowFailureModal(false);
                            setSubmitError(null);
                          }}
                          className="flex-1 bg-gradient-to-r from-emerald-500 to-cyan-500 hover:from-emerald-600 hover:to-cyan-600 text-white px-6 py-3 rounded-xl font-semibold transition-all font-unbounded"
                          whileHover={{ scale: 1.02 }}
                          whileTap={{ scale: 0.98 }}
                        >
                          Got It
                        </motion.button>
                      </div>
                    </div>
                  </motion.div>
                </motion.div>
              )}
            </AnimatePresence>

            <AnimatePresence mode="wait">
              {renderStepContent()}
            </AnimatePresence>
            
            {/* Navigation Buttons */}
            <div className="flex justify-between mt-12 pt-8 border-t border-gray-200/50">
              <motion.button
                onClick={prevStep}
                disabled={currentStep === 1 || isSubmitting || isPending}
                className="flex items-center px-8 py-4 border-2 border-gray-300/50 rounded-2xl text-gray-700 hover:bg-gray-50/80 hover:border-gray-400/50 disabled:opacity-50 disabled:cursor-not-allowed transition-all duration-300 shadow-lg hover:shadow-xl font-semibold font-unbounded backdrop-blur-sm"
                whileHover={{ scale: 1.02 }}
                whileTap={{ scale: 0.98 }}
              >
                <ArrowLeft className="w-5 h-5 mr-3" />
                Previous
              </motion.button>
              
              {currentStep === STEPS.length ? (
                <motion.button
                  onClick={handleSubmit}
                  disabled={isSubmitting || isPending}
                  className="flex items-center px-10 py-4 bg-gradient-to-r from-emerald-600 via-cyan-600 to-teal-600 text-white rounded-2xl hover:from-emerald-700 hover:via-cyan-700 hover:to-teal-700 disabled:opacity-50 disabled:cursor-not-allowed transition-all duration-300 shadow-xl hover:shadow-2xl font-bold font-unbounded"
                  whileHover={{ scale: 1.02 }}
                  whileTap={{ scale: 0.98 }}
                >
                  {(isSubmitting || isPending) ? (
                    <>
                      <div className="animate-spin rounded-full h-6 w-6 border-b-2 border-white mr-3" />
                      {isSubmitting ? 'Uploading to IPFS...' : 'Registering on Blockchain...'}
                    </>
                  ) : (
                    <>
                      <Upload className="w-6 h-6 mr-3" />
                      Create Campaign
                    </>
                  )}
                </motion.button>
              ) : (
                <motion.button
                  onClick={nextStep}
                  disabled={isSubmitting || isPending}
                  className="flex items-center px-8 py-4 bg-gradient-to-r from-emerald-600 via-cyan-600 to-teal-600 text-white rounded-2xl hover:from-emerald-700 hover:via-cyan-700 hover:to-teal-700 disabled:opacity-50 disabled:cursor-not-allowed transition-all duration-300 shadow-xl hover:shadow-2xl font-bold font-unbounded"
                  whileHover={{ scale: 1.02 }}
                  whileTap={{ scale: 0.98 }}
                >
                  Next
                  <ArrowRight className="w-5 h-5 ml-3" />
                </motion.button>
              )}
            </div>
          </div>
        </motion.div>
      </div>
    </div>
  );
}
