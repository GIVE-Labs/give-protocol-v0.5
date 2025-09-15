import { PinataSDK } from 'pinata'

// Initialize Pinata SDK
const pinata = new PinataSDK({
  pinataJwt: import.meta.env.VITE_PINATA_JWT,
  pinataGateway: import.meta.env.VITE_PINATA_GATEWAY
})

export interface NGOMetadata {
  name: string
  description: string
  category: string
  missionStatement: string
  fundingGoal: string
  fundingDuration: string
  images: string[] // IPFS hashes
  videos: string[]
  teamMembers: Array<{
    name: string
    role: string
    bio: string
  }>
  donationTiers: Array<{
    name: string
    amount: string
    description: string
    benefits: string[]
  }>
  createdAt: string
  version: string
}

/**
 * Upload a single file to IPFS via Pinata
 */
export const uploadFileToIPFS = async (file: File): Promise<string> => {
  try {
    const upload = await pinata.upload.public.file(file)
    return upload.cid
  } catch (error) {
    console.error('Error uploading file to IPFS:', error)
    throw new Error('Failed to upload file to IPFS')
  }
}

/**
 * Upload multiple images to IPFS
 */
export async function uploadImagesToIPFS(images: File[]): Promise<string[]> {
  try {
    const uploadPromises = images.map(image => uploadFileToIPFS(image))
    const ipfsHashes = await Promise.all(uploadPromises)
    return ipfsHashes
  } catch (error) {
    console.error('Error uploading images to IPFS:', error)
    throw new Error('Failed to upload images to IPFS')
  }
}

/**
 * Upload NGO metadata JSON to IPFS
 */
export const uploadMetadataToIPFS = async (metadata: NGOMetadata): Promise<string> => {
  try {
    const upload = await pinata.upload.public.json(metadata)
    return upload.cid
  } catch (error) {
    console.error('Error uploading metadata to IPFS:', error)
    throw new Error('Failed to upload metadata to IPFS')
  }
}

/**
 * Complete NGO creation process:
 * 1. Upload images to IPFS
 * 2. Create metadata with image hashes
 * 3. Upload metadata to IPFS
 * 4. Return metadata IPFS hash
 */
export async function createNGOMetadata(
  formData: {
    ngoName: string
    missionStatement: string
    category: string
    detailedDescription: string
    fundingGoal: string
    fundingDuration: string
    images: File[]
    videos: string[]
    teamMembers: Array<{
      name: string
      role: string
      bio: string
    }>
    donationTiers: Array<{
      name: string
      amount: string
      description: string
      benefits: string[]
    }>
  }
): Promise<{ metadataHash: string; imageHashes: string[] }> {
  try {
    // Validate required fields
    if (!formData.ngoName || !formData.missionStatement || !formData.category) {
      throw new Error('Missing required fields')
    }

    if (formData.images.length === 0) {
      throw new Error('At least one image is required')
    }

    if (formData.images.length > 3) {
      throw new Error('Maximum 3 images allowed')
    }

    // Upload images first
    console.log('Uploading images to IPFS...')
    const imageHashes = await uploadImagesToIPFS(formData.images)
    console.log('Images uploaded:', imageHashes)

    // Create metadata object
    const metadata: NGOMetadata = {
      name: formData.ngoName,
      description: formData.detailedDescription,
      category: formData.category,
      missionStatement: formData.missionStatement,
      fundingGoal: formData.fundingGoal,
      fundingDuration: formData.fundingDuration,
      images: imageHashes,
      videos: formData.videos,
      teamMembers: formData.teamMembers.filter(member => member.name.trim() !== ''),
      donationTiers: formData.donationTiers.filter(tier => tier.name.trim() !== ''),
      createdAt: new Date().toISOString(),
      version: '1.0.0'
    }

    // Upload metadata to IPFS
    console.log('Uploading metadata to IPFS...')
    const metadataHash = await uploadMetadataToIPFS(metadata)
    console.log('Metadata uploaded:', metadataHash)

    return {
      metadataHash,
      imageHashes
    }
  } catch (error) {
    console.error('Error creating NGO metadata:', error)
    throw error
  }
}

/**
 * Get IPFS URL for a hash
 */
export function getIPFSUrl(hash: string): string {
  const gateway = import.meta.env.VITE_PINATA_GATEWAY || 'https://gateway.pinata.cloud'
  return `${gateway}/ipfs/${hash}`
}

/**
 * Fetch metadata from IPFS
 */
export async function fetchMetadataFromIPFS(hash: string): Promise<NGOMetadata> {
  try {
    const response = await fetch(getIPFSUrl(hash))
    if (!response.ok) {
      throw new Error('Failed to fetch metadata from IPFS')
    }
    return await response.json()
  } catch (error) {
    console.error('Error fetching metadata from IPFS:', error)
    throw new Error('Failed to fetch metadata from IPFS')
  }
}

/**
 * Validate image file
 */
export function validateImageFile(file: File): { valid: boolean; error?: string } {
  // Check file type
  if (!file.type.startsWith('image/')) {
    return { valid: false, error: 'File must be an image' }
  }

  // Check file size (max 10MB)
  const maxSize = 10 * 1024 * 1024 // 10MB
  if (file.size > maxSize) {
    return { valid: false, error: 'Image must be smaller than 10MB' }
  }

  // Check image dimensions (optional - can be implemented with FileReader)
  return { valid: true }
}

/**
 * Validate all images
 */
export function validateImages(files: File[]): { valid: boolean; errors: string[] } {
  const errors: string[] = []

  if (files.length === 0) {
    errors.push('At least one image is required')
  }

  if (files.length > 3) {
    errors.push('Maximum 3 images allowed')
  }

  files.forEach((file, index) => {
    const validation = validateImageFile(file)
    if (!validation.valid) {
      errors.push(`Image ${index + 1}: ${validation.error}`)
    }
  })

  return {
    valid: errors.length === 0,
    errors
  }
}