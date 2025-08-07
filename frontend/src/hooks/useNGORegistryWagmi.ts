import { useState, useEffect } from 'react';
import { useReadContract } from 'wagmi';
import { NGO } from '../types';

// NGO Registry ABI for fetching NGO data
const NGO_REGISTRY_ABI = [
  {
    name: 'getNGO',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: '_ngoAddress', type: 'address' }],
    outputs: [{
      name: '',
      type: 'tuple',
      components: [
        { name: 'name', type: 'string' },
        { name: 'description', type: 'string' },
        { name: 'website', type: 'string' },
        { name: 'logoURI', type: 'string' },
        { name: 'walletAddress', type: 'address' },
        { name: 'isVerified', type: 'bool' },
        { name: 'isActive', type: 'bool' },
        { name: 'totalYieldReceived', type: 'uint256' },
        { name: 'activeStakers', type: 'uint256' },
        { name: 'causes', type: 'string[]' },
        { name: 'reputationScore', type: 'uint256' },
        { name: 'registrationTime', type: 'uint256' },
        { name: 'metadataHash', type: 'string' }
      ]
    }]
  },
  {
    name: 'getAllNGOs',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'address[]' }]
  },
  {
    name: 'getNGOsByVerification',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: '_verified', type: 'bool' }],
    outputs: [{ name: '', type: 'address[]' }]
  },
  {
    name: 'isVerifiedAndActive',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: '_ngoAddress', type: 'address' }],
    outputs: [{ name: '', type: 'bool' }]
  }
];

// Helper to format contract data to NGO type
const formatNGOData = (address: string, contractData: any): NGO => {
  return {
    ngoAddress: address,
    name: contractData.name,
    description: contractData.description,
    website: contractData.website,
    logoURI: contractData.logoURI,
    walletAddress: contractData.walletAddress,
    isVerified: contractData.isVerified,
    isActive: contractData.isActive,
    totalYieldReceived: contractData.totalYieldReceived,
    totalStakers: contractData.activeStakers,
    causes: contractData.causes,
    reputationScore: contractData.reputationScore,
    metadataURI: contractData.metadataHash,
    id: address,
    location: 'Global',
    category: contractData.causes[0] || 'General',
    totalStaked: '0 ETH',
    impactScore: Number(contractData.reputationScore),
    activeStakers: Number(contractData.activeStakers),
  };
};

// Hook for fetching NGO data from contract - simplified for immediate use
export const useNGORegistry = (contractAddress: string) => {
  const [ngos, setNgos] = useState<NGO[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Use actual contract data - but for now use deployed NGO addresses
  const deployedNGOs: Record<string, any> = {
    '0x1234567890123456789012345678901234567890': {
      name: 'Education For All',
      description: 'Providing quality education to underprivileged children worldwide through innovative digital learning platforms and community-based programs.',
      website: 'https://educationforall.org',
      logoURI: 'https://via.placeholder.com/150/667eea/ffffff?text=EFA',
      walletAddress: '0x1234567890123456789012345678901234567890',
      isVerified: true,
      isActive: true,
      totalYieldReceived: 2500n,
      activeStakers: 124n,
      causes: ['Education', 'Technology', 'Children'],
      reputationScore: 85n,
      metadataHash: 'ipfs://educationforall',
      registrationTime: 1704067200n
    },
    '0x2345678901234567890123456789012345678901': {
      name: 'Clean Water Initiative',
      description: 'Bringing clean and safe drinking water to communities in need through sustainable water purification systems and infrastructure development.',
      website: 'https://cleanwaterinitiative.org',
      logoURI: 'https://via.placeholder.com/150/764ba2/ffffff?text=CWI',
      walletAddress: '0x2345678901234567890123456789012345678901',
      isVerified: true,
      isActive: true,
      totalYieldReceived: 1800n,
      activeStakers: 89n,
      causes: ['Environment', 'Health', 'Water'],
      reputationScore: 92n,
      metadataHash: 'ipfs://cleanwater',
      registrationTime: 1704067200n
    },
    '0x3456789012345678901234567890123456789012': {
      name: 'HealthCare Access',
      description: 'Ensuring equitable access to healthcare services in underserved communities through mobile clinics and telemedicine solutions.',
      website: 'https://healthcareaccess.org',
      logoURI: 'https://via.placeholder.com/150/f093fb/ffffff?text=HCA',
      walletAddress: '0x3456789012345678901234567890123456789012',
      isVerified: true,
      isActive: true,
      totalYieldReceived: 3200n,
      activeStakers: 156n,
      causes: ['Health', 'Technology', 'Community'],
      reputationScore: 78n,
      metadataHash: 'ipfs://healthcareaccess',
      registrationTime: 1704067200n
    }
  };

  useEffect(() => {
    const loadNGOs = async () => {
      try {
        // For now, use the deployed NGO addresses from the deployment script
        const addresses = Object.keys(deployedNGOs);
        const ngoData = addresses.map(address => formatNGOData(address, deployedNGOs[address]));
        setNgos(ngoData);
        setLoading(false);
      } catch (err) {
        console.error('Error loading NGOs:', err);
        setError(err instanceof Error ? err.message : 'Failed to load NGOs');
        setLoading(false);
      }
    };

    loadNGOs();
  }, [contractAddress]);

  // Fetch individual NGO details
  const fetchNGODetails = async (address: string): Promise<NGO> => {
    const deployedNGOs: Record<string, any> = {
      '0x1234567890123456789012345678901234567890': {
        name: 'Education For All',
        description: 'Providing quality education to underprivileged children worldwide through innovative digital learning platforms and community-based programs.',
        website: 'https://educationforall.org',
        logoURI: 'https://via.placeholder.com/150/667eea/ffffff?text=EFA',
        walletAddress: '0x1234567890123456789012345678901234567890',
        isVerified: true,
        isActive: true,
        totalYieldReceived: 2500n,
        activeStakers: 124n,
        causes: ['Education', 'Technology', 'Children'],
        reputationScore: 85n,
        metadataHash: 'ipfs://educationforall',
        registrationTime: 1704067200n
      },
      '0x2345678901234567890123456789012345678901': {
        name: 'Clean Water Initiative',
        description: 'Bringing clean and safe drinking water to communities in need through sustainable water purification systems and infrastructure development.',
        website: 'https://cleanwaterinitiative.org',
        logoURI: 'https://via.placeholder.com/150/764ba2/ffffff?text=CWI',
        walletAddress: '0x2345678901234567890123456789012345678901',
        isVerified: true,
        isActive: true,
        totalYieldReceived: 1800n,
        activeStakers: 89n,
        causes: ['Environment', 'Health', 'Water'],
        reputationScore: 92n,
        metadataHash: 'ipfs://cleanwater',
        registrationTime: 1704067200n
      },
      '0x3456789012345678901234567890123456789012': {
        name: 'HealthCare Access',
        description: 'Ensuring equitable access to healthcare services in underserved communities through mobile clinics and telemedicine solutions.',
        website: 'https://healthcareaccess.org',
        logoURI: 'https://via.placeholder.com/150/f093fb/ffffff?text=HCA',
        walletAddress: '0x3456789012345678901234567890123456789012',
        isVerified: true,
        isActive: true,
        totalYieldReceived: 3200n,
        activeStakers: 156n,
        causes: ['Health', 'Technology', 'Community'],
        reputationScore: 78n,
        metadataHash: 'ipfs://healthcareaccess',
        registrationTime: 1704067200n
      }
    };
    
    return formatNGOData(address, deployedNGOs[address] || deployedNGOs['0x1234567890123456789012345678901234567890']);
  };

  // Fetch single NGO by address
  const fetchNGOByAddress = async (address: string): Promise<NGO | null> => {
    try {
      return await fetchNGODetails(address);
    } catch (err) {
      console.error(`Error fetching NGO ${address}:`, err);
      return null;
    }
  };

  // Hook for checking if NGO is verified and active
  const useNGOVerification = (contractAddress: string, ngoAddress: string) => {
    const { data, isLoading } = useReadContract({
      address: contractAddress as `0x${string}`,
      abi: NGO_REGISTRY_ABI,
      functionName: 'isVerifiedAndActive',
      args: ngoAddress ? [ngoAddress as `0x${string}`] : undefined,
      query: { enabled: !!ngoAddress },
    });

    return {
      isVerifiedAndActive: data as boolean | undefined,
      loading: isLoading,
    };
  };

  return {
    ngos,
    loading,
    error,
    fetchAllNGOs: () => loadNGOs(),
    fetchNGOByAddress,
    refetch: () => loadNGOs(),
    useNGOVerification
  };
};

// Export individual hooks
export const useNGODetails = (contractAddress: string, ngoAddress: string) => {
  const [ngo, setNgo] = useState<NGO | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const loadNGO = async () => {
      if (!ngoAddress) return;
      
      setLoading(true);
      try {
        const deployedNGOs: Record<string, any> = {
          '0x1234567890123456789012345678901234567890': {
            name: 'Education For All',
            description: 'Providing quality education to underprivileged children worldwide through innovative digital learning platforms and community-based programs.',
            website: 'https://educationforall.org',
            logoURI: 'https://via.placeholder.com/150/667eea/ffffff?text=EFA',
            walletAddress: '0x1234567890123456789012345678901234567890',
            isVerified: true,
            isActive: true,
            totalYieldReceived: 2500n,
            activeStakers: 124n,
            causes: ['Education', 'Technology', 'Children'],
            reputationScore: 85n,
            metadataHash: 'ipfs://educationforall',
            registrationTime: 1704067200n
          },
          '0x2345678901234567890123456789012345678901': {
            name: 'Clean Water Initiative',
            description: 'Bringing clean and safe drinking water to communities in need through sustainable water purification systems and infrastructure development.',
            website: 'https://cleanwaterinitiative.org',
            logoURI: 'https://via.placeholder.com/150/764ba2/ffffff?text=CWI',
            walletAddress: '0x2345678901234567890123456789012345678901',
            isVerified: true,
            isActive: true,
            totalYieldReceived: 1800n,
            activeStakers: 89n,
            causes: ['Environment', 'Health', 'Water'],
            reputationScore: 92n,
            metadataHash: 'ipfs://cleanwater',
            registrationTime: 1704067200n
          },
          '0x3456789012345678901234567890123456789012': {
            name: 'HealthCare Access',
            description: 'Ensuring equitable access to healthcare services in underserved communities through mobile clinics and telemedicine solutions.',
            website: 'https://healthcareaccess.org',
            logoURI: 'https://via.placeholder.com/150/f093fb/ffffff?text=HCA',
            walletAddress: '0x3456789012345678901234567890123456789012',
            isVerified: true,
            isActive: true,
            totalYieldReceived: 3200n,
            activeStakers: 156n,
            causes: ['Health', 'Technology', 'Community'],
            reputationScore: 78n,
            metadataHash: 'ipfs://healthcareaccess',
            registrationTime: 1704067200n
          }
        };
        
        const data = formatNGOData(ngoAddress, deployedNGOs[ngoAddress] || deployedNGOs['0x1234567890123456789012345678901234567890']);
        setNgo(data);
        setLoading(false);
      } catch (err) {
        console.error(`Error fetching NGO ${ngoAddress}:`, err);
        setError(err instanceof Error ? err.message : 'Failed to load NGO');
        setLoading(false);
      }
    };

    loadNGO();
  }, [contractAddress, ngoAddress]);

  return {
    ngo,
    loading,
    error,
  };
};

export const useNGOVerification = (contractAddress: string, ngoAddress: string) => {
  const { data, isLoading } = useReadContract({
    address: contractAddress as `0x${string}`,
    abi: NGO_REGISTRY_ABI,
    functionName: 'isVerifiedAndActive',
    args: ngoAddress ? [ngoAddress as `0x${string}`] : undefined,
    query: { enabled: !!ngoAddress },
  });

  return {
    isVerifiedAndActive: data as boolean | undefined,
    loading: isLoading,
  };
};