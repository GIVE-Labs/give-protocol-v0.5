import { useState, useEffect } from 'react';
import { NGO } from '../types';


export const useNGORegistry = (contractAddress: string) => {
  const [ngos, setNgos] = useState<NGO[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Fetch individual NGO details
  const fetchNGODetails = async (address: string): Promise<NGO> => {
    try {
      // For now, we'll use mock data since we don't have the actual contract deployed
      // In production, this would use wagmi's useReadContract for individual NGO data
      
      // Mock data for demonstration
      const mockNGOs: { [key: string]: NGO } = {
        '0x1234567890123456789012345678901234567890': {
          ngoAddress: '0x1234567890123456789012345678901234567890',
          name: 'Education For All',
          description: 'Providing quality education to underprivileged children worldwide',
          website: 'https://educationforall.org',
          logoURI: '/assets/ngos/education-for-all-logo.png',
          walletAddress: '0x1234567890123456789012345678901234567890',
          isVerified: true,
          isActive: true,
          totalYieldReceived: 2500n,
          totalStakers: 124n,
          causes: ['Education', 'Children', 'Technology'],
          reputationScore: 85n,
          metadataURI: 'ipfs://educationforall',
          id: '0x1234567890123456789012345678901234567890',
          location: 'Global',
          category: 'Education',
          totalStaked: '0.5 ETH',
          impactScore: 85,
          activeStakers: 124,
        },
        '0x0987654321098765432109876543210987654321': {
          ngoAddress: '0x0987654321098765432109876543210987654321',
          name: 'Clean Water Initiative',
          description: 'Bringing clean water to communities in need',
          website: 'https://cleanwater.org',
          logoURI: '/assets/ngos/clean-water-initiative-logo.png',
          walletAddress: '0x0987654321098765432109876543210987654321',
          isVerified: true,
          isActive: true,
          totalYieldReceived: 1800n,
          totalStakers: 89n,
          causes: ['Environment', 'Health', 'Water'],
          reputationScore: 92n,
          metadataURI: 'ipfs://cleanwater',
          id: '0x0987654321098765432109876543210987654321',
          location: 'Global',
          category: 'Environment',
          totalStaked: '0.3 ETH',
          impactScore: 92,
          activeStakers: 89,
        },
        '0x1111111111111111111111111111111111111111': {
          ngoAddress: '0x1111111111111111111111111111111111111111',
          name: 'Healthcare Access',
          description: 'Improving healthcare access in underserved communities',
          website: 'https://healthcareaccess.org',
          logoURI: '/assets/ngos/healthcare-access-logo.png',
          walletAddress: '0x1111111111111111111111111111111111111111',
          isVerified: true,
          isActive: true,
          totalYieldReceived: 3200n,
          totalStakers: 156n,
          causes: ['Health', 'Technology', 'Community'],
          reputationScore: 78n,
          metadataURI: 'ipfs://healthcareaccess',
          id: '0x1111111111111111111111111111111111111111',
          location: 'Global',
          category: 'Health',
          totalStaked: '0.8 ETH',
          impactScore: 78,
          activeStakers: 156,
        },
      };

      return mockNGOs[address] || mockNGOs['0x1234567890123456789012345678901234567890'];
    } catch (err) {
      console.error(`Error fetching NGO details for ${address}:`, err);
      throw err;
    }
  };

  // Fetch all NGOs
  const fetchAllNGOs = async (verifiedOnly = false) => {
    setLoading(true);
    setError(null);

    try {
      // For now, use mock addresses since we don't have real contract data
      const addresses = verifiedOnly 
        ? ['0x1234567890123456789012345678901234567890', '0x0987654321098765432109876543210987654321', '0x1111111111111111111111111111111111111111']
        : ['0x1234567890123456789012345678901234567890', '0x0987654321098765432109876543210987654321', '0x1111111111111111111111111111111111111111'];
      
      if (!addresses || addresses.length === 0) {
        setNgos([]);
        return;
      }

      const ngoPromises = addresses.map((address: string) => fetchNGODetails(address));
      const ngoData = await Promise.all(ngoPromises);
      
      setNgos(ngoData);
    } catch (err) {
      console.error('Error fetching NGOs:', err);
      setError(err instanceof Error ? err.message : 'Failed to fetch NGOs');
    } finally {
      setLoading(false);
    }
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

  useEffect(() => {
    fetchAllNGOs(false); // Include all NGOs for calculations
  }, [contractAddress]);

  return {
    ngos,
    loading,
    error,
    fetchAllNGOs,
    fetchNGOByAddress,
    refetch: () => fetchAllNGOs(true),
  };
};