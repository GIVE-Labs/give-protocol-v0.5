import { useState, useEffect } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { ArrowLeft, ArrowRight, Upload, X, Check, Camera, AlertCircle } from 'lucide-react'
import { Link, useNavigate } from 'react-router-dom'
import { createNGOMetadata, validateImages } from '../services/ipfs'
import { useAccount } from 'wagmi'
import { useNGORegistry, useNGOApprovalStatus } from '../hooks/useContracts'
import { keccak256, toBytes } from 'viem'
import { DotLottieReact } from '@lottiefiles/dotlottie-react'

interface FormData {
  // Basic Info
  ngoAddress: string
  ngoName: string
  missionStatement: string
  category: string
  detailedDescription: string
  
  // Funding
  fundingGoal: string
  fundingDuration: string
  
  // Media
  images: File[]
  videos: string[]
  
  // Team
  teamMembers: Array<{
    name: string
    role: string
    bio: string
  }>
  
  // Donation Tiers
  donationTiers: Array<{
    name: string
    amount: string
    description: string
    benefits: string[]
  }>
}

const CATEGORIES = [
  'Education',
  'Healthcare', 
  'Environment',
  'Poverty Alleviation',
  'Human Rights',
  'Community Development'
]

const STEPS = [
  { id: 1, name: 'Basic Info', description: 'NGO details and mission' },
  { id: 2, name: 'Funding', description: 'Goal and duration' },
  { id: 3, name: 'Media', description: 'Images and videos' },
  { id: 4, name: 'Team', description: 'Team members' },
  { id: 5, name: 'Donation Tiers', description: 'Donation options' },
  { id: 6, name: 'Review', description: 'Final review' }
]

export default function CreateCampaign() {
  const [currentStep, setCurrentStep] = useState(1)
  const [formData, setFormData] = useState<FormData>({
    ngoAddress: '',
    ngoName: '',
    missionStatement: '',
    category: '',
    detailedDescription: '',
    fundingGoal: '',
    fundingDuration: '',
    images: [],
    videos: [],
    teamMembers: [{ name: '', role: '', bio: '' }],
    donationTiers: [
      { name: 'Basic Supporter', amount: '10', description: '', benefits: [''] },
      { name: 'Active Contributor', amount: '50', description: '', benefits: [''] },
      { name: 'Major Donor', amount: '100', description: '', benefits: [''] }
    ]
  })
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [submitError, setSubmitError] = useState<string | null>(null)
  const [validationErrors, setValidationErrors] = useState<string[]>([])
  const [showFailureModal, setShowFailureModal] = useState(false)
  
  const navigate = useNavigate()
  const { address } = useAccount()
  const { registerNGO, isPending: isRegistering, isConfirming, isConfirmed, error: registrationError } = useNGORegistry()
  const { isApproved: isNGOApproved, isLoading: isCheckingApproval } = useNGOApprovalStatus(formData.ngoAddress as `0x${string}`)

  // Handle transaction confirmation
  useEffect(() => {
    if (isConfirmed) {
      console.log('NGO registered successfully')
      setIsSubmitting(false)
      navigate('/ngo')
    }
  }, [isConfirmed, navigate])

  // Handle registration errors
  useEffect(() => {
    if (registrationError) {
      console.error('Registration error:', registrationError)
      
      // Extract user-friendly error message
      let errorMessage = 'Failed to register NGO'
      const fullError = registrationError.message || ''
      
      if (fullError.includes('User rejected') || fullError.includes('User denied')) {
        errorMessage = 'Transaction was rejected by user'
      } else if (fullError.includes('insufficient funds')) {
        errorMessage = 'Insufficient funds for transaction'
      } else if (fullError.includes('network')) {
        errorMessage = 'Network connection error'
      }
      
      setSubmitError(errorMessage)
      setIsSubmitting(false)
      setShowFailureModal(true)
    }
  }, [registrationError])

  const updateFormData = (field: keyof FormData, value: any) => {
    setFormData(prev => ({ ...prev, [field]: value }))
  }

  const nextStep = async () => {
    // Validate step 1 (NGO address) before proceeding
    if (currentStep === 1) {
      // Clear any previous errors
      setSubmitError(null)
      setValidationErrors([])
      
      // Basic validation for step 1
      const errors: string[] = []
      if (!formData.ngoAddress.trim()) {
        errors.push('NGO address is required')
      } else if (!/^0x[a-fA-F0-9]{40}$/.test(formData.ngoAddress)) {
        errors.push('NGO address must be a valid Ethereum address')
      }
      
      if (errors.length > 0) {
        setValidationErrors(errors)
        return
      }
      
      // Check if NGO is already approved
      if (isNGOApproved) {
        setSubmitError('This NGO address is already approved and registered. Please use a different address.')
        return
      }
      
      // Don't proceed if we're still checking approval status
      if (isCheckingApproval) {
        return
      }
    }
    
    // Proceed to next step
    if (currentStep < STEPS.length) {
      setCurrentStep(currentStep + 1)
    }
  }

  const prevStep = () => {
    if (currentStep > 1) {
      setCurrentStep(currentStep - 1)
    }
  }

  const handleImageUpload = (files: FileList | null) => {
    if (files) {
      const newImages = Array.from(files).slice(0, 3 - formData.images.length)
      const allImages = [...formData.images, ...newImages]
      
      // Validate images
      const validation = validateImages(allImages)
      if (validation.valid) {
        updateFormData('images', allImages)
        setValidationErrors([])
      } else {
        setValidationErrors(validation.errors)
      }
    }
  }

  const removeImage = (index: number) => {
    const newImages = formData.images.filter((_, i) => i !== index)
    updateFormData('images', newImages)
  }

  const addTeamMember = () => {
    updateFormData('teamMembers', [...formData.teamMembers, { name: '', role: '', bio: '' }])
  }

  const updateTeamMember = (index: number, field: string, value: string) => {
    const newTeamMembers = formData.teamMembers.map((member, i) => 
      i === index ? { ...member, [field]: value } : member
    )
    updateFormData('teamMembers', newTeamMembers)
  }

  const removeTeamMember = (index: number) => {
    if (formData.teamMembers.length > 1) {
      const newTeamMembers = formData.teamMembers.filter((_, i) => i !== index)
      updateFormData('teamMembers', newTeamMembers)
    }
  }

  const updateDonationTier = (index: number, field: string, value: string | string[]) => {
    const newTiers = formData.donationTiers.map((tier, i) => 
      i === index ? { ...tier, [field]: value } : tier
    )
    updateFormData('donationTiers', newTiers)
  }

  const addBenefit = (tierIndex: number) => {
    const newTiers = formData.donationTiers.map((tier, i) => 
      i === tierIndex ? { ...tier, benefits: [...tier.benefits, ''] } : tier
    )
    updateFormData('donationTiers', newTiers)
  }

  const updateBenefit = (tierIndex: number, benefitIndex: number, value: string) => {
    const newTiers = formData.donationTiers.map((tier, i) => 
      i === tierIndex ? {
        ...tier,
        benefits: tier.benefits.map((benefit, j) => j === benefitIndex ? value : benefit)
      } : tier
    )
    updateFormData('donationTiers', newTiers)
  }

  const removeBenefit = (tierIndex: number, benefitIndex: number) => {
    const newTiers = formData.donationTiers.map((tier, i) => 
      i === tierIndex ? {
        ...tier,
        benefits: tier.benefits.filter((_, j) => j !== benefitIndex)
      } : tier
    )
    updateFormData('donationTiers', newTiers)
  }

  const validateForm = (): boolean => {
    const errors: string[] = []
    
    // Basic validation
    if (!formData.ngoAddress.trim()) {
      errors.push('NGO address is required')
    } else if (!/^0x[a-fA-F0-9]{40}$/.test(formData.ngoAddress)) {
      errors.push('NGO address must be a valid Ethereum address')
    }
    if (!formData.ngoName.trim()) errors.push('NGO name is required')
    if (!formData.missionStatement.trim()) errors.push('Mission statement is required')
    if (!formData.category) errors.push('Category is required')
    if (!formData.detailedDescription.trim()) errors.push('Detailed description is required')
    if (!formData.fundingGoal || parseFloat(formData.fundingGoal) <= 0) errors.push('Valid funding goal is required')
    if (!formData.fundingDuration || parseInt(formData.fundingDuration) <= 0) errors.push('Valid funding duration is required')
    
    // Image validation
    const imageValidation = validateImages(formData.images)
    if (!imageValidation.valid) {
      errors.push(...imageValidation.errors)
    }
    
    // Team validation
    const validTeamMembers = formData.teamMembers.filter(member => member.name.trim())
    if (validTeamMembers.length === 0) {
      errors.push('At least one team member is required')
    }
    
    setValidationErrors(errors)
    return errors.length === 0
  }

  const handleSubmit = async () => {
    if (!address) {
      setSubmitError('Please connect your wallet first')
      return
    }

    if (!validateForm()) {
      setSubmitError('Please fix the validation errors before submitting')
      return
    }

    // Check if NGO is already approved
    if (isNGOApproved) {
      setSubmitError('This NGO address is already approved and registered. Please use a different address or contact support if this is an error.')
      return
    }

    setIsSubmitting(true)
    setSubmitError(null)
    
    try {
      // Upload to IPFS
      console.log('Creating NGO metadata...')
      const { metadataHash } = await createNGOMetadata(formData)
      console.log('Metadata uploaded to IPFS:', metadataHash)
      
      // Register NGO on blockchain
      console.log('Registering NGO on blockchain...')
      const kycHash = keccak256(toBytes('mock-kyc-hash')) // Mock KYC hash for development
      await registerNGO(formData.ngoAddress as `0x${string}`, metadataHash, kycHash, address)
      
      // Wait for transaction confirmation
      console.log('Waiting for transaction confirmation...')
      // The hook will handle the confirmation state, we'll check it in useEffect
      
    } catch (error) {
      console.error('Error creating campaign:', error)
      
      // Extract user-friendly error message
      let errorMessage = 'Failed to create campaign'
      const fullError = error instanceof Error ? error.message : ''
      
      if (fullError.includes('User rejected') || fullError.includes('User denied')) {
        errorMessage = 'Transaction was rejected by user'
      } else if (fullError.includes('insufficient funds')) {
        errorMessage = 'Insufficient funds for transaction'
      } else if (fullError.includes('network')) {
        errorMessage = 'Network connection error'
      } else if (fullError.includes('IPFS')) {
        errorMessage = 'Failed to upload campaign data'
      }
      
      setSubmitError(errorMessage)
      setIsSubmitting(false)
      setShowFailureModal(true)
    }
  }

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
                  NGO Address *
                </label>
                <div className="relative">
                  <input
                    type="text"
                    value={formData.ngoAddress}
                    onChange={(e) => updateFormData('ngoAddress', e.target.value)}
                    placeholder="0x... (Ethereum address of the NGO)"
                    className={`w-full px-4 py-3 pr-32 border rounded-xl focus:ring-2 transition-colors font-mono text-sm ${
                      formData.ngoAddress && !/^0x[a-fA-F0-9]{40}$/.test(formData.ngoAddress)
                        ? 'border-red-300 focus:ring-red-500 focus:border-red-500'
                        : isNGOApproved
                        ? 'border-red-300 focus:ring-red-500 focus:border-red-500'
                        : 'border-gray-300 focus:ring-emerald-500 focus:border-emerald-500'
                    }`}
                    required
                  />
                  {address && (
                    <button
                      type="button"
                      onClick={() => updateFormData('ngoAddress', address)}
                      className="absolute right-2 top-1/2 transform -translate-y-1/2 px-3 py-1 text-xs bg-emerald-100 text-emerald-700 rounded-lg hover:bg-emerald-200 transition-colors"
                    >
                      Use Wallet
                    </button>
                  )}
                </div>
                  <div className="mt-1 space-y-1">
                  <p className="text-xs text-gray-500 font-medium">
                    The Ethereum address that will be registered as the NGO. This can be different from your connected wallet.
                  </p>                  {/* Real-time validation feedback */}
                  {formData.ngoAddress && (
                    <div className="flex items-center space-x-2">
                      {!/^0x[a-fA-F0-9]{40}$/.test(formData.ngoAddress) ? (
                        <div className="flex items-center text-red-600 text-xs">
                          <X className="w-3 h-3 mr-1" />
                          Invalid Ethereum address format
                        </div>
                      ) : isCheckingApproval ? (
                        <div className="flex items-center text-blue-600 text-xs">
                          <div className="animate-spin rounded-full h-3 w-3 border-b border-blue-600 mr-1" />
                          Checking if address is available...
                        </div>
                      ) : isNGOApproved ? (
                        <div className="flex items-center text-red-600 text-xs">
                          <X className="w-3 h-3 mr-1" />
                          This address is already registered
                        </div>
                      ) : (
                        <div className="flex items-center text-green-600 text-xs">
                          <Check className="w-3 h-3 mr-1" />
                          Address is available
                        </div>
                      )}
                    </div>
                  )}
                </div>
              </div>

              <div>
                <label className="block text-sm font-semibold text-gray-700 mb-2 font-unbounded">
                  NGO Name / Project Title *
                </label>
                <input
                  type="text"
                  value={formData.ngoName}
                  onChange={(e) => updateFormData('ngoName', e.target.value)}
                  placeholder="Enter your NGO or project name"
                  className="w-full px-4 py-3 border border-gray-300 rounded-xl focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 transition-colors"
                  required
                />
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
        )

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
                  Funding Goal (USD) *
                </label>
                <input
                  type="number"
                  value={formData.fundingGoal}
                  onChange={(e) => updateFormData('fundingGoal', e.target.value)}
                  placeholder="10000"
                  className="w-full px-4 py-3 border border-gray-300 rounded-xl focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 transition-colors"
                  required
                />
              </div>

              <div>
                <label className="block text-sm font-semibold text-gray-700 mb-2 font-unbounded">
                  Campaign Duration (days) *
                </label>
                <input
                  type="number"
                  value={formData.fundingDuration}
                  onChange={(e) => updateFormData('fundingDuration', e.target.value)}
                  placeholder="30"
                  className="w-full px-4 py-3 border border-gray-300 rounded-xl focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 transition-colors"
                  required
                />
              </div>
            </div>
          </motion.div>
        )

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
                Upload 1-3 high-quality images that represent your campaign. Recommended size: 1200x800px
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
        )

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
        )

      case 5:
        return (
          <motion.div
            initial={{ opacity: 0, x: 20 }}
            animate={{ opacity: 1, x: 0 }}
            exit={{ opacity: 0, x: -20 }}
            className="space-y-6"
          >
            <h3 className="text-lg font-bold text-gray-900 font-unbounded">Donation Tiers</h3>
            
            {formData.donationTiers.map((tier, tierIndex) => (
              <div key={tierIndex} className="border border-gray-200 rounded-xl p-4 space-y-4">
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <input
                    type="text"
                    value={tier.name}
                    onChange={(e) => updateDonationTier(tierIndex, 'name', e.target.value)}
                    placeholder="Tier Name"
                    className="px-4 py-3 border border-gray-300 rounded-xl focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 transition-colors"
                  />
                  <input
                    type="number"
                    value={tier.amount}
                    onChange={(e) => updateDonationTier(tierIndex, 'amount', e.target.value)}
                    placeholder="Amount (USD)"
                    className="px-4 py-3 border border-gray-300 rounded-xl focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 transition-colors"
                  />
                </div>
                
                <textarea
                  value={tier.description}
                  onChange={(e) => updateDonationTier(tierIndex, 'description', e.target.value)}
                  placeholder="Tier description"
                  rows={2}
                  className="w-full px-4 py-3 border border-gray-300 rounded-xl focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 transition-colors resize-none"
                />
                
                <div>
                  <div className="flex justify-between items-center mb-2">
                    <label className="text-sm font-semibold text-gray-700 font-unbounded">Benefits</label>
                    <button
                      onClick={() => addBenefit(tierIndex)}
                      className="text-emerald-500 hover:text-emerald-700 text-sm font-medium"
                    >
                      + Add Benefit
                    </button>
                  </div>
                  
                  {tier.benefits.map((benefit, benefitIndex) => (
                    <div key={benefitIndex} className="flex gap-2 mb-2">
                      <input
                        type="text"
                        value={benefit}
                        onChange={(e) => updateBenefit(tierIndex, benefitIndex, e.target.value)}
                        placeholder="Benefit description"
                        className="flex-1 px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 transition-colors"
                      />
                      {tier.benefits.length > 1 && (
                        <button
                          onClick={() => removeBenefit(tierIndex, benefitIndex)}
                          className="text-red-500 hover:text-red-700"
                        >
                          <X className="w-5 h-5" />
                        </button>
                      )}
                    </div>
                  ))}
                </div>
              </div>
            ))}
          </motion.div>
        )

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
                <p className="text-gray-600 font-medium">NGO Address: <span className="font-mono text-sm">{formData.ngoAddress}</span></p>
                <p className="text-gray-600 font-medium">Name: {formData.ngoName}</p>
                <p className="text-gray-600 font-medium">Category: {formData.category}</p>
                <p className="text-gray-600 font-medium">Mission: {formData.missionStatement}</p>
              </div>
              
              <div>
                <h4 className="font-semibold text-gray-900 font-unbounded">Funding</h4>
                <p className="text-gray-600 font-medium">Goal: ${formData.fundingGoal}</p>
                <p className="text-gray-600 font-medium">Duration: {formData.fundingDuration} days</p>
              </div>
              
              <div>
                <h4 className="font-semibold text-gray-900 font-unbounded">Media</h4>
                <p className="text-gray-600 font-medium">{formData.images.length} images uploaded</p>
              </div>
              
              <div>
                <h4 className="font-semibold text-gray-900 font-unbounded">Team</h4>
                <p className="text-gray-600 font-medium">{formData.teamMembers.length} team members</p>
              </div>
            </div>
            
            <div className="bg-yellow-50 border border-yellow-200 rounded-xl p-4">
              <p className="text-yellow-800 text-sm font-medium">
                <strong className="font-unbounded">Note:</strong> Once submitted, your campaign will be uploaded to IPFS and registered on the blockchain.
              </p>
            </div>
          </motion.div>
        )

      default:
        return null
    }
  }

  const progress = (currentStep / STEPS.length) * 100

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
            to="/"
            className="inline-flex items-center text-emerald-600 hover:text-emerald-700 mb-6 font-semibold transition-colors font-unbounded"
          >
            <ArrowLeft className="w-5 h-5 mr-2" />
            Back to Home
          </Link>
          
          <div className="text-center">
            <h1 className="text-5xl lg:text-6xl font-bold text-gray-900 mb-4 font-unbounded leading-tight">
              <span className="text-gray-900">Create NGO</span>
              <span className="block text-transparent bg-gradient-to-r from-emerald-600 via-cyan-600 to-teal-600 bg-clip-text pb-1">
                Campaign
              </span>
            </h1>
            <p className="text-xl lg:text-2xl text-gray-700 leading-relaxed font-medium font-unbounded max-w-3xl mx-auto">
              Launch your humanitarian project and connect with compassionate backers worldwide
            </p>
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
              {isConfirmed && (
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
                      <p className="text-emerald-700 font-semibold">Your NGO has been registered on the blockchain. Redirecting to your dashboard...</p>
                    </div>
                  </div>
                </motion.div>
              )}
            </AnimatePresence>

            {/* Loading State */}
            <AnimatePresence>
              {(isSubmitting || isRegistering || isConfirming) && (
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
                        {isSubmitting ? 'Uploading to IPFS...' : 
                         isRegistering ? 'Waiting for Wallet...' : 
                         'Confirming Transaction...'}
                      </h3>
                    </div>
                  </div>
                </motion.div>
              )}
            </AnimatePresence>
            
            {/* Loading Overlay */}
            <AnimatePresence>
              {(isSubmitting || isRegistering) && (
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
                        {isSubmitting ? 'Submitting Campaign...' : 'Approving Transaction...'}
                      </h3>
                      {/* <p className="text-gray-600 font-medium">
                        {isSubmitting 
                          ? 'Uploading your campaign data to decentralized storage...' 
                          : 'Please confirm the transaction in your wallet to register your NGO.'
                        }
                      </p> */}
                      
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
                            setShowFailureModal(false)
                            setSubmitError(null)
                          }}
                          className="flex-1 bg-gray-100 hover:bg-gray-200 text-gray-700 px-6 py-3 rounded-xl font-semibold transition-colors font-unbounded"
                          whileHover={{ scale: 1.02 }}
                          whileTap={{ scale: 0.98 }}
                        >
                          Close
                        </motion.button>
                        <motion.button
                          onClick={() => {
                            setShowFailureModal(false)
                            setSubmitError(null)
                            // Don't automatically retry - let user manually try again from the form
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
                disabled={currentStep === 1 || isSubmitting || isRegistering}
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
                  disabled={isSubmitting || isRegistering || isCheckingApproval}
                  className="flex items-center px-10 py-4 bg-gradient-to-r from-emerald-600 via-cyan-600 to-teal-600 text-white rounded-2xl hover:from-emerald-700 hover:via-cyan-700 hover:to-teal-700 disabled:opacity-50 disabled:cursor-not-allowed transition-all duration-300 shadow-xl hover:shadow-2xl font-bold font-unbounded"
                  whileHover={{ scale: 1.02 }}
                  whileTap={{ scale: 0.98 }}
                >
                  {(isSubmitting || isRegistering || isCheckingApproval) ? (
                    <>
                      <div className="animate-spin rounded-full h-6 w-6 border-b-2 border-white mr-3" />
                      {isCheckingApproval ? 'Checking NGO Status...' : isSubmitting ? 'Uploading to IPFS...' : 'Registering on Blockchain...'}
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
                  disabled={isSubmitting || isRegistering || isConfirming || isCheckingApproval}
                  className="flex items-center px-8 py-4 bg-gradient-to-r from-emerald-600 via-cyan-600 to-teal-600 text-white rounded-2xl hover:from-emerald-700 hover:via-cyan-700 hover:to-teal-700 disabled:opacity-50 disabled:cursor-not-allowed transition-all duration-300 shadow-xl hover:shadow-2xl font-bold font-unbounded"
                  whileHover={{ scale: 1.02 }}
                  whileTap={{ scale: 0.98 }}
                >
                  {(currentStep === 1 && isCheckingApproval) ? (
                    <>
                      <div className="animate-spin rounded-full h-5 w-5 border-b-2 border-white mr-3" />
                      Checking Address...
                    </>
                  ) : (
                    <>
                      Next
                      <ArrowRight className="w-5 h-5 ml-3" />
                    </>
                  )}
                </motion.button>
              )}
            </div>
          </div>
        </motion.div>
      </div>
    </div>
  )
}