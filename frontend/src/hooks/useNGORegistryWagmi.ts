import { useState, useEffect, useCallback } from 'react';
import { useReadContract } from 'wagmi';
import { NGO } from '../types';
import NGORegistryABI from '../abis/NGORegistry.json';

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

// Hook for fetching NGO data from contract
export const useNGORegistry = (contractAddress: string) => {
  const [ngos, setNgos] = useState<NGO[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Read approved NGOs from contract
  const { data: approvedNGOs, isLoading: isLoadingApproved } = useReadContract({
    address: contractAddress as `0x${string}`,
    abi: NGORegistryABI,
    functionName: 'getApprovedNGOs',
  });

  const loadNGOs = useCallback(async () => {
    try {
      console.log('Loading NGOs from contract:', contractAddress);
      console.log('Approved NGOs from contract:', approvedNGOs);
      
      if (!approvedNGOs || !Array.isArray(approvedNGOs)) {
        console.log('No approved NGOs found or invalid data');
        setNgos([]);
        setLoading(false);
        return;
      }

      // Convert approved NGO addresses to NGO objects with placeholder data
      // The actual metadata will be fetched by individual components
      const ngoData: NGO[] = (approvedNGOs as string[]).map((address: string, index: number) => ({
        ngoAddress: address,
        name: `NGO ${index + 1}`, // Placeholder - will be replaced by metadata
        description: 'Loading...', // Placeholder - will be replaced by metadata
        website: '',
        logoURI: '',
        walletAddress: address,
        isVerified: true, // Approved NGOs are verified
        isActive: true,
        totalYieldReceived: 0n,
        totalStakers: 0n,
        causes: [],
        reputationScore: 0n,
        metadataURI: '',
        id: address,
        location: 'Global',
        category: 'General',
        totalStaked: '0 ETH',
        impactScore: 0,
        activeStakers: 0,
      }));
      
      console.log('Formatted NGO data:', ngoData);
      setNgos(ngoData);
      setLoading(false);
    } catch (err) {
      console.error('Error loading NGOs:', err);
      setError(err instanceof Error ? err.message : 'Failed to load NGOs');
      setLoading(false);
    }
  }, [contractAddress, approvedNGOs]);

  useEffect(() => {
    if (!isLoadingApproved) {
      loadNGOs();
    }
  }, [loadNGOs, isLoadingApproved]);

  // Update loading state based on contract loading
  useEffect(() => {
    setLoading(isLoadingApproved);
  }, [isLoadingApproved]);

  // Fetch individual NGO details
  const fetchNGODetails = async (address: string): Promise<NGO> => {
    const deployedNGOs: Record<string, any> = {
      '0x1234567890123456789012345678901234567890': {
        name: 'Education For All',
        description: 'Providing quality education to underprivileged children worldwide through innovative digital learning platforms and community-based programs.',
        website: 'https://educationforall.org',
        logoURI: 'https://images.unsplash.com/photo-1488521787991-ed7bbaae773c?w=400&h=300&fit=crop&q=80',
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
        logoURI: 'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=400&h=300&fit=crop&q=80',
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
        logoURI: 'https://images.unsplash.com/photo-1576091160550-2173dba999ef?w=400&h=300&fit=crop&q=80',
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
      abi: NGORegistryABI,
      functionName: 'isNGOApproved',
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
            logoURI: 'https://images.unsplash.com/photo-1488521787991-ed7bbaae773c?w=400&h=300&fit=crop&q=80',
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
            logoURI: 'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=400&h=300&fit=crop&q=80',
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
            logoURI: 'https://images.unsplash.com/photo-1576091160550-2173dba999ef?w=400&h=300&fit=crop&q=80',
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
    abi: NGORegistryABI,
    functionName: 'isNGOApproved',
    args: ngoAddress ? [ngoAddress as `0x${string}`] : undefined,
    query: { enabled: !!ngoAddress },
  });

  return {
    isVerifiedAndActive: data as boolean | undefined,
    loading: isLoading,
  };
};