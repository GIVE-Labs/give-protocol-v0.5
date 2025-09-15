import { useState } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { ArrowLeft, ArrowRight, Upload, X, Check, Camera, AlertCircle } from 'lucide-react'
import { Link, useNavigate } from 'react-router-dom'
import { createNGOMetadata, validateImages } from '../services/ipfs'
import { useAccount } from 'wagmi'
import { useNGORegistry } from '../hooks/useContracts'

interface FormData {
  // Basic Info
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
  
  const navigate = useNavigate()
  const { address } = useAccount()
  const { registerNGO, isPending: isRegistering } = useNGORegistry()

  const updateFormData = (field: keyof FormData, value: any) => {
    setFormData(prev => ({ ...prev, [field]: value }))
  }

  const nextStep = () => {
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

    setIsSubmitting(true)
    setSubmitError(null)
    
    try {
      // Upload to IPFS
      console.log('Creating NGO metadata...')
      const { metadataHash } = await createNGOMetadata(formData)
      console.log('Metadata uploaded to IPFS:', metadataHash)
      
      // Register NGO on blockchain
      console.log('Registering NGO on blockchain...')
      await registerNGO(formData.ngoName, formData.detailedDescription)
      console.log('NGO registered successfully')
      
      // Navigate to success page or NGO details
      navigate('/dashboard')
    } catch (error) {
      console.error('Error creating campaign:', error)
      setSubmitError(error instanceof Error ? error.message : 'Failed to create campaign')
    } finally {
      setIsSubmitting(false)
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
                <label className="block text-sm font-medium text-gray-700 mb-2">
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
                <label className="block text-sm font-medium text-gray-700 mb-2">
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
                <label className="block text-sm font-medium text-gray-700 mb-2">
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
                <label className="block text-sm font-medium text-gray-700 mb-2">
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
                <label className="block text-sm font-medium text-gray-700 mb-2">
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
                <label className="block text-sm font-medium text-gray-700 mb-2">
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
              <label className="block text-sm font-medium text-gray-700 mb-4">
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
                    <span className="text-sm text-gray-600">Upload Image</span>
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
              
              <p className="text-sm text-gray-500">
                Upload 1-3 high-quality images that represent your campaign. Recommended size: 1200x800px
              </p>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
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
              <h3 className="text-lg font-semibold text-gray-900">Team Members</h3>
              <button
                onClick={addTeamMember}
                className="bg-emerald-500 text-white px-4 py-2 rounded-lg hover:bg-emerald-600 transition-colors"
              >
                Add Member
              </button>
            </div>
            
            {formData.teamMembers.map((member, index) => (
              <div key={index} className="border border-gray-200 rounded-xl p-4 space-y-4">
                <div className="flex justify-between items-center">
                  <h4 className="font-medium text-gray-900">Team Member {index + 1}</h4>
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
            <h3 className="text-lg font-semibold text-gray-900">Donation Tiers</h3>
            
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
                    <label className="text-sm font-medium text-gray-700">Benefits</label>
                    <button
                      onClick={() => addBenefit(tierIndex)}
                      className="text-emerald-500 hover:text-emerald-700 text-sm"
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
            <h3 className="text-lg font-semibold text-gray-900">Review Your Campaign</h3>
            
            <div className="bg-gray-50 rounded-xl p-6 space-y-4">
              <div>
                <h4 className="font-medium text-gray-900">Basic Information</h4>
                <p className="text-gray-600">Name: {formData.ngoName}</p>
                <p className="text-gray-600">Category: {formData.category}</p>
                <p className="text-gray-600">Mission: {formData.missionStatement}</p>
              </div>
              
              <div>
                <h4 className="font-medium text-gray-900">Funding</h4>
                <p className="text-gray-600">Goal: ${formData.fundingGoal}</p>
                <p className="text-gray-600">Duration: {formData.fundingDuration} days</p>
              </div>
              
              <div>
                <h4 className="font-medium text-gray-900">Media</h4>
                <p className="text-gray-600">{formData.images.length} images uploaded</p>
              </div>
              
              <div>
                <h4 className="font-medium text-gray-900">Team</h4>
                <p className="text-gray-600">{formData.teamMembers.length} team members</p>
              </div>
            </div>
            
            <div className="bg-yellow-50 border border-yellow-200 rounded-xl p-4">
              <p className="text-yellow-800 text-sm">
                <strong>Note:</strong> Once submitted, your campaign will be uploaded to IPFS and registered on the blockchain. 
                This action cannot be undone.
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
    <div className="min-h-screen bg-gradient-to-br from-emerald-50 via-cyan-50 to-teal-50">
      <div className="container mx-auto px-4 py-8">
        {/* Header */}
        <div className="mb-8">
          <Link
            to="/"
            className="inline-flex items-center text-emerald-600 hover:text-emerald-700 mb-4"
          >
            <ArrowLeft className="w-5 h-5 mr-2" />
            Back to Home
          </Link>
          
          <div className="text-center">
            <h1 className="text-4xl font-bold text-gray-900 mb-2">Create NGO Campaign</h1>
            <p className="text-xl text-gray-600">
              Launch your humanitarian project and connect with compassionate backers worldwide
            </p>
          </div>
        </div>

        {/* Progress Bar */}
        <div className="mb-8">
          <div className="flex justify-between items-center mb-4">
            <span className="text-sm font-medium text-gray-700">
              Step {currentStep} of {STEPS.length}
            </span>
            <span className="text-sm font-medium text-emerald-600">
              {Math.round(progress)}% Complete
            </span>
          </div>
          
          <div className="w-full bg-gray-200 rounded-full h-2 mb-6">
            <motion.div
              className="bg-gradient-to-r from-emerald-500 to-cyan-500 h-2 rounded-full"
              initial={{ width: 0 }}
              animate={{ width: `${progress}%` }}
              transition={{ duration: 0.5 }}
            />
          </div>
          
          {/* Step indicators */}
          <div className="flex justify-between">
            {STEPS.map((step) => (
              <div key={step.id} className="flex flex-col items-center">
                <div className={`w-10 h-10 rounded-full flex items-center justify-center text-sm font-medium ${
                  step.id <= currentStep
                    ? 'bg-emerald-500 text-white'
                    : 'bg-gray-200 text-gray-500'
                }`}>
                  {step.id < currentStep ? (
                    <Check className="w-5 h-5" />
                  ) : (
                    step.id
                  )}
                </div>
                <div className="mt-2 text-center">
                  <div className="text-sm font-medium text-gray-900">{step.name}</div>
                  <div className="text-xs text-gray-500">{step.description}</div>
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Form Content */}
        <div className="max-w-4xl mx-auto">
          <div className="bg-white rounded-2xl shadow-xl p-8">
            {/* Error Messages */}
            {(submitError || validationErrors.length > 0) && (
              <div className="mb-6 p-4 bg-red-50 border border-red-200 rounded-xl">
                <div className="flex items-start">
                  <AlertCircle className="w-5 h-5 text-red-500 mt-0.5 mr-3 flex-shrink-0" />
                  <div>
                    {submitError && (
                      <p className="text-red-700 font-medium mb-2">{submitError}</p>
                    )}
                    {validationErrors.length > 0 && (
                      <div>
                        <p className="text-red-700 font-medium mb-2">Please fix the following errors:</p>
                        <ul className="list-disc list-inside text-red-600 space-y-1">
                          {validationErrors.map((error, index) => (
                            <li key={index}>{error}</li>
                          ))}
                        </ul>
                      </div>
                    )}
                  </div>
                </div>
              </div>
            )}
            
            <AnimatePresence mode="wait">
              {renderStepContent()}
            </AnimatePresence>
            
            {/* Navigation Buttons */}
            <div className="flex justify-between mt-8 pt-6 border-t border-gray-200">
              <button
                onClick={prevStep}
                disabled={currentStep === 1}
                className="flex items-center px-6 py-3 border border-gray-300 rounded-xl text-gray-700 hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
              >
                <ArrowLeft className="w-5 h-5 mr-2" />
                Previous
              </button>
              
              {currentStep === STEPS.length ? (
                <button
                  onClick={handleSubmit}
                  disabled={isSubmitting || isRegistering}
                  className="flex items-center px-8 py-3 bg-gradient-to-r from-emerald-600 to-cyan-600 text-white rounded-xl hover:from-emerald-700 hover:to-cyan-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                >
                  {(isSubmitting || isRegistering) ? (
                    <>
                      <div className="animate-spin rounded-full h-5 w-5 border-b-2 border-white mr-2" />
                      {isSubmitting ? 'Uploading to IPFS...' : 'Registering on Blockchain...'}
                    </>
                  ) : (
                    <>
                      <Upload className="w-5 h-5 mr-2" />
                      Create Campaign
                    </>
                  )}
                </button>
              ) : (
                <button
                  onClick={nextStep}
                  className="flex items-center px-6 py-3 bg-gradient-to-r from-emerald-600 to-cyan-600 text-white rounded-xl hover:from-emerald-700 hover:to-cyan-700 transition-colors"
                >
                  Next
                  <ArrowRight className="w-5 h-5 ml-2" />
                </button>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}