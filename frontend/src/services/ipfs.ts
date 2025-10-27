import { PinataSDK } from 'pinata'

// Validate environment variables
const PINATA_JWT = import.meta.env.VITE_PINATA_JWT;
const PINATA_GATEWAY = import.meta.env.VITE_PINATA_GATEWAY;

if (!PINATA_JWT) {
  console.warn('VITE_PINATA_JWT is not configured');
}

if (!PINATA_GATEWAY) {
  console.warn('VITE_PINATA_GATEWAY is not configured');
}

// Initialize Pinata SDK with validation
const pinata = new PinataSDK({
  pinataJwt: PINATA_JWT,
  pinataGateway: PINATA_GATEWAY
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
 * Complete Campaign creation process:
 * 1. Upload images to IPFS (if any)
 * 2. Create metadata with image hashes
 * 3. Upload metadata to IPFS
 * 4. Return metadata IPFS hash (CID)
 */
export async function createCampaignMetadata(
  formData: {
    campaignName: string
    missionStatement: string
    category: string
    detailedDescription: string
    campaignAddress: string
    targetAmount: string
    minStake: string
    fundraisingDuration: string
    images: File[]
    videos: string[]
    teamMembers: Array<{
      name: string
      role: string
      bio: string
    }>
    impactMetrics: Array<{
      name: string
      target: string
      description: string
    }>
  }
): Promise<{ metadataHash: string; imageHashes: string[] }> {
  try {
    // Validate required fields
    if (!formData.campaignName || !formData.missionStatement || !formData.category) {
      throw new Error('Missing required fields')
    }

    // Upload images if provided (optional for campaigns)
    let imageHashes: string[] = [];
    if (formData.images && formData.images.length > 0) {
      console.log('Uploading campaign images to IPFS...');
      imageHashes = await uploadImagesToIPFS(formData.images);
      console.log('Campaign images uploaded:', imageHashes);
    }

    // Create campaign metadata object
    const metadata = {
      name: formData.campaignName,
      mission: formData.missionStatement,
      description: formData.detailedDescription,
      category: formData.category,
      recipient: formData.campaignAddress,
      targetAmount: formData.targetAmount,
      minStake: formData.minStake,
      fundraisingDuration: formData.fundraisingDuration,
      images: imageHashes,
      videos: formData.videos || [],
      teamMembers: formData.teamMembers.filter(m => m.name.trim()),
      impactMetrics: formData.impactMetrics.filter(m => m.name.trim()),
      createdAt: new Date().toISOString(),
      version: '0.5.0',
      // Store metadata about the upload itself
      _ipfs: {
        uploadedAt: new Date().toISOString(),
        uploaderNote: 'Metadata uploaded via GIVE Protocol v0.5 frontend'
      }
    };

    // Upload metadata to IPFS
    console.log('Uploading campaign metadata to IPFS...');
    const metadataHash = await uploadMetadataToIPFS(metadata as any);
    console.log('Campaign metadata uploaded:', metadataHash);

    return {
      metadataHash,
      imageHashes
    };
  } catch (error) {
    console.error('Error creating campaign metadata:', error);
    throw error;
  }
}

/**
 * Store campaign CID mapping in localStorage
 * Key: campaignId, Value: IPFS CID
 */
export function saveCampaignCID(campaignId: string, cid: string): void {
  try {
    const mapping = getCampaignCIDMapping();
    mapping[campaignId] = cid;
    localStorage.setItem('give_campaign_cids', JSON.stringify(mapping));
    console.log('Saved campaign CID mapping:', campaignId, '→', cid);
  } catch (error) {
    console.error('Failed to save campaign CID mapping:', error);
  }
}

/**
 * Get campaign CID from localStorage
 */
export function getCampaignCID(campaignId: string): string | null {
  try {
    const mapping = getCampaignCIDMapping();
    return mapping[campaignId] || null;
  } catch (error) {
    console.error('Failed to get campaign CID:', error);
    return null;
  }
}

/**
 * Get all campaign CID mappings
 */
function getCampaignCIDMapping(): Record<string, string> {
  try {
    const stored = localStorage.getItem('give_campaign_cids');
    return stored ? JSON.parse(stored) : {};
  } catch (error) {
    console.error('Failed to parse campaign CID mapping:', error);
    return {};
  }
}

/**
 * Convert IPFS CID to bytes32 for contract storage
 * Just returns the CID - we'll store the mapping separately
 */
export function cidToBytes32(cid: string): `0x${string}` {
  // For contract compatibility, we still need to return a bytes32
  // But we'll store the actual CID in localStorage
  // Return the keccak256 hash of the CID as a placeholder
  const encoder = new TextEncoder();
  const data = encoder.encode(cid);
  
  // Simple hash function (NOT cryptographic, just for uniqueness)
  const bytes = new Uint8Array(32);
  for (let i = 0; i < data.length; i++) {
    bytes[i % 32] ^= data[i];
  }
  
  const hexString = Array.from(bytes)
    .map(b => b.toString(16).padStart(2, '0'))
    .join('');
  
  return `0x${hexString}` as `0x${string}`;
}

/**
 * Get IPFS URL for a hash using Pinata gateway
 */
export function getIPFSUrl(cid: string): string {
  if (!cid || typeof cid !== 'string') {
    throw new Error('Invalid IPFS hash provided');
  }
  
  // Validate that the hash looks like a valid CID
  if (!isValidCID(cid)) {
    throw new Error(`Invalid IPFS CID format: ${cid}`);
  }
  
  // Use Pinata gateway directly
  const gateway = PINATA_GATEWAY || 'gateway.pinata.cloud';
  const baseGateway = gateway.startsWith('http') ? gateway : `https://${gateway}`;
  const url = `${baseGateway}/ipfs/${cid}`;
  return url;
}

/**
 * Validate if a string is a valid IPFS CID
 */
function isValidCID(cid: string): boolean {
  // Basic CID validation - check common prefixes and length
  if (!cid || typeof cid !== 'string') return false;
  
  // CIDv0 (Qm...) should be 46 characters
  if (cid.startsWith('Qm') && cid.length === 46) return true;
  
  // CIDv1 validation - more flexible length requirements
  // bafk (raw codec) CIDs are typically 32-59 characters
  // bafy (dag-pb codec) CIDs are typically 59+ characters
  // bafz (other codecs) can vary
  if (cid.startsWith('bafk') && cid.length >= 32 && cid.length <= 59) return true;
  if (cid.startsWith('bafy') && cid.length >= 50) return true;
  if (cid.startsWith('bafz') && cid.length >= 32) return true;
  
  // Additional CIDv1 prefixes
  if (cid.startsWith('baf') && cid.length >= 32) return true;
  
  return false;
}

/**
 * Get campaign CID from localStorage, event logs, or try to decode from hex
 */
export async function hexToCid(_hexString: string, campaignId?: string): Promise<string | null> {
  // First try localStorage if campaignId is provided
  if (campaignId) {
    const storedCid = getCampaignCID(campaignId);
    if (storedCid) {
      return storedCid;
    }
    
    // Fallback: Try fetching from event logs
    try {
      const { getCampaignCIDFromLogs } = await import('./campaignEvents');
      const cidFromLogs = await getCampaignCIDFromLogs(campaignId as `0x${string}`);
      if (cidFromLogs) {
        // Cache it for next time
        saveCampaignCID(campaignId, cidFromLogs);
        return cidFromLogs;
      }
    } catch (error) {
      console.error('Error fetching from event logs:', error);
    }
  }
  
  return null;
}

/**
 * Fetch metadata from IPFS using Pinata gateway
 */
export async function fetchMetadataFromIPFS(cid: string): Promise<any | null> {
  try {
    // Validate CID before making request
    if (!isValidCID(cid)) {
      console.error('Invalid CID provided to fetchMetadataFromIPFS:', cid);
      return null;
    }
    
    // Use Pinata gateway URL directly
    const url = getIPFSUrl(cid);
    
    const response = await fetch(url, {
      method: 'GET',
      headers: {
        'Accept': 'application/json',
      },
    });
    
    if (!response.ok) {
      console.error('Failed to fetch metadata:', response.status, response.statusText);
      return null;
    }
    
    const data = await response.json();
    console.log('✅ Metadata loaded from CID:', cid);
    
    return data;
  } catch (error) {
    console.error('Error fetching metadata from IPFS:', error);
    return null;
  }
}

/**
 * Fetch NGO metadata from contract data
 */
export async function fetchNGOMetadata(metadataCid: string): Promise<NGOMetadata | null> {
  try {
    // First try to convert hex to CID if needed
    const cid = await hexToCid(metadataCid);
    
    if (!cid) {
      return null;
    }
    
    // Fetch from IPFS
    return await fetchMetadataFromIPFS(cid);
  } catch (error) {
    console.warn('Failed to fetch NGO metadata:', error);
    return null;
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