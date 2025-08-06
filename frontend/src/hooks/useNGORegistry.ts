import { useState, useEffect } from 'react';
import { useContractRead, useContract } from '@thirdweb-dev/react';
// import { NGORegistry__factory } from '../../../backend/typechain-types';
import { NGO } from '../types';

export const useNGORegistry = (contractAddress: string) => {
  const { contract } = useContract(contractAddress);
  
  const [ngos, setNgos] = useState<NGO[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Fetch all verified NGOs
  const { data: verifiedNGOAddresses, isLoading: verifiedLoading } = useContractRead(
    contract,
    "getNGOsByVerification",
    [true]
  );

  // Fetch all NGO addresses
  const { data: allNGOAddresses, isLoading: allLoading } = useContractRead(
    contract,
    "getAllNGOs"
  );

  // Fetch individual NGO details
  const fetchNGODetails = async (address: string): Promise<NGO> => {
    try {
      const ngoData = await contract?.call("getNGO", [address]);
      
      return {
        ngoAddress: address,
        name: ngoData.name,
        description: ngoData.description,
        website: ngoData.website,
        logoURI: ngoData.logoURI,
        walletAddress: ngoData.walletAddress,
        isVerified: ngoData.isVerified,
        isActive: ngoData.isActive,
        totalYieldReceived: ngoData.totalYieldReceived,
        totalStakers: ngoData.totalStakers,
        causes: ngoData.causes,
        reputationScore: ngoData.reputationScore,
        metadataURI: ngoData.metadataHash,
        id: address,
        location: '', // Will be populated from metadata if available
        category: ngoData.causes[0] || 'General',
        totalStaked: '0', // Will be fetched from staking contract
        impactScore: ngoData.reputationScore,
        activeStakers: Number(ngoData.totalStakers),
      };
    } catch (err) {
      console.error(`Error fetching NGO details for ${address}:`, err);
      throw err;
    }
  };

  // Fetch all NGOs
  const fetchAllNGOs = async (verifiedOnly = false) => {
    if (!contract) return;
    
    setLoading(true);
    setError(null);

    try {
      const addresses = verifiedOnly ? verifiedNGOAddresses : allNGOAddresses;
      
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
    if (!contract) return null;
    
    try {
      return await fetchNGODetails(address);
    } catch (err) {
      console.error(`Error fetching NGO ${address}:`, err);
      return null;
    }
  };

  // Check if NGO is verified and active
  const isVerifiedAndActive = async (address: string): Promise<boolean> => {
    if (!contract) return false;
    
    try {
      return await contract.call("isVerifiedAndActive", [address]);
    } catch (err) {
      console.error(`Error checking verification status for ${address}:`, err);
      return false;
    }
  };

  useEffect(() => {
    if (contract) {
      fetchAllNGOs(true); // Default to verified NGOs only
    }
  }, [contract, verifiedNGOAddresses]);

  return {
    ngos,
    loading: loading || verifiedLoading || allLoading,
    error,
    fetchAllNGOs,
    fetchNGOByAddress,
    isVerifiedAndActive,
    refetch: () => fetchAllNGOs(true),
  };
};