/**
 * CampaignCard Component
 * Display individual campaign with image and progress
 * Design: Glass-card style with emerald/cyan gradients, clickable to campaign details
 */

import { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import { Heart, MapPin, Users } from 'lucide-react';
import { useCampaignRegistry } from '../../hooks/v05';
import { useNavigate } from 'react-router-dom';

interface CampaignCardProps {
  campaignId: `0x${string}`;
  index?: number;
}

interface CampaignMetadata {
  name?: string;
  description?: string;
  category?: string;
  image?: string;
  images?: string[];
}

export default function CampaignCard({ campaignId, index = 0 }: CampaignCardProps) {
  const navigate = useNavigate();
  const { getCampaign } = useCampaignRegistry();
  const { data: campaign } = getCampaign(campaignId);
  const [metadata, setMetadata] = useState<CampaignMetadata | null>(null);

  // Fetch metadata from IPFS
  useEffect(() => {
    const fetchMetadata = async () => {
      if (!campaign) return;
      
      const campaignData = campaign as any;
      const metadataHash = campaignData?.metadataHash;
      
      console.log('Campaign ID:', campaignId);
      console.log('Raw metadata hash:', metadataHash);
      
      if (!metadataHash || metadataHash === '0x' + '0'.repeat(64)) {
        console.log('No metadata hash found');
        return; // No metadata
      }

      try {
        // Try to decode as UTF-8 string (for IPFS CID stored as string)
        const hashBytes = metadataHash.replace('0x', '');
        let hashString = '';
        
        for (let i = 0; i < hashBytes.length; i += 2) {
          const byte = parseInt(hashBytes.substr(i, 2), 16);
          if (byte === 0) break; // Stop at null terminator
          // Only include printable ASCII/UTF-8 characters
          if (byte >= 32 && byte <= 126) {
            hashString += String.fromCharCode(byte);
          }
        }
        
        console.log('Decoded hash string:', hashString);
        
        // Check if it looks like a valid IPFS CID (starts with Qm or b)
        if (!hashString || (!hashString.startsWith('Qm') && !hashString.startsWith('b'))) {
          console.log('Hash does not look like IPFS CID, trying as raw bytes32');
          // If not a string CID, use the full hash as-is (might be CIDv1 bytes)
          hashString = metadataHash;
        }
        
        // Get Pinata gateway from env
        const pinataGateway = import.meta.env.VITE_PINATA_GATEWAY || 'gateway.pinata.cloud';
        
        // Try IPFS gateways (use your Pinata gateway first!)
        const gateways = [
          `https://${pinataGateway}/ipfs/${hashString}`,
          `https://gateway.pinata.cloud/ipfs/${hashString}`,
          `https://ipfs.io/ipfs/${hashString}`
        ];
        
        for (const url of gateways) {
          console.log('Trying IPFS gateway:', url);
          try {
            const response = await fetch(url, { 
              method: 'GET',
              headers: { 'Accept': 'application/json' }
            });
            
            if (response.ok) {
              const data = await response.json();
              console.log('✅ Metadata fetched successfully:', data);
              setMetadata(data);
              return;
            } else {
              console.log('❌ Gateway failed:', response.status, response.statusText);
            }
          } catch (err) {
            console.log('❌ Gateway error:', err);
            continue;
          }
        }
        
        console.error('❌ All IPFS gateways failed for hash:', hashString);
      } catch (error) {
        console.error('Failed to fetch campaign metadata:', error);
      }
    };

    fetchMetadata();
  }, [campaign, campaignId]);

  if (!campaign) {
    // Loading skeleton
    return (
      <motion.div 
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ delay: index * 0.1 }}
        className="bg-white rounded-xl shadow-sm border overflow-hidden animate-pulse"
      >
        <div className="h-48 bg-gray-200" />
        <div className="p-6">
          <div className="h-4 bg-gray-200 rounded mb-2" />
          <div className="h-3 bg-gray-200 rounded mb-4" />
          <div className="h-2 bg-gray-200 rounded mb-4" />
          <div className="h-8 bg-gray-200 rounded" />
        </div>
      </motion.div>
    );
  }

  // Type the campaign data properly
  const campaignData = campaign as any; // TODO: Add proper type definition

  // Calculate progress
  const targetAmount = Number(campaignData?.targetStake || 0) / 1e18;
  const totalStaked = Number(campaignData?.totalStaked || 0) / 1e18;
  const progress = targetAmount > 0 ? Math.min((totalStaked / targetAmount) * 100, 100) : 0;

  // Mock data for display
  const mockSupporters = [234, 156, 89][index % 3] || 100;
  const defaultImages = [
    '/src/assets/IMG_4241.jpg',
    '/src/assets/IMG_5543.jpg',
    '/src/assets/IMG_5550.jpg'
  ];

  // Use metadata or fallback to defaults
  const campaignName = metadata?.name || 'Test Campaign';
  const campaignDescription = metadata?.description || 'Supporting sustainable impact through no-loss giving';
  const campaignCategory = metadata?.category || 'Climate Action';
  const campaignImage = metadata?.image || metadata?.images?.[0] || defaultImages[index % defaultImages.length];

  const handleClick = () => {
    navigate(`/campaigns/${campaignId}`);
  };

  const isActive = campaignData?.status === 2;

  return (
    <motion.div 
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ delay: index * 0.1 }}
      className="bg-white rounded-xl shadow-sm border overflow-hidden hover:shadow-lg transition-all duration-300 cursor-pointer group flex flex-col h-full"
      onClick={handleClick}
    >
      {/* Campaign Image */}
      <div className="relative h-48 overflow-hidden">
        <img 
          src={campaignImage} 
          alt={campaignName}
          className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
        />
        <div className="absolute top-3 right-3">
          <span className={`px-2 py-1 text-xs rounded-full font-medium backdrop-blur-sm ${
            isActive ? 'bg-green-500/90 text-white' : 'bg-gray-500/90 text-white'
          }`}>
            {isActive ? 'Active' : 'Inactive'}
          </span>
        </div>
        <div className="absolute bottom-3 left-3">
          <div className="flex items-center text-white text-xs bg-black/50 backdrop-blur-sm px-2 py-1 rounded-full">
            <MapPin className="w-3 h-3 mr-1" />
            {campaignCategory}
          </div>
        </div>
      </div>

      {/* Campaign Content */}
      <div className="p-6 flex flex-col flex-1">
        <div className="flex items-center justify-between mb-3">
          <span className="px-3 py-1 bg-emerald-100 text-emerald-800 text-xs font-medium rounded-full">
            {campaignCategory}
          </span>
          <Heart className="w-5 h-5 text-gray-400 hover:text-red-500 cursor-pointer transition-colors" onClick={(e) => { e.stopPropagation(); }} />
        </div>
        
        <h3 className="text-justify font-bold text-lg text-gray-900 mb-2 group-hover:text-emerald-600 transition-colors whitespace-normal break-words font-unbounded">
          {campaignName}
        </h3>
        
        <p className="text-gray-600 text-sm mb-4 line-clamp-2 leading-relaxed">
          {campaignDescription}
        </p>
        
        {/* Progress Bar and CTA - pushed to bottom for consistent alignment */}
        <div className="mt-auto">
          <div className="mb-4">
            <div className="flex justify-between items-center mb-2">
              <span className="text-sm font-semibold text-gray-900">
                {totalStaked.toFixed(2)} ETH raised
              </span>
              <span className="text-sm text-gray-500">
                {Math.round(progress)}%
              </span>
            </div>
            <div className="w-full bg-gray-200 rounded-full h-2">
              <div 
                className="bg-gradient-to-r from-emerald-500 to-teal-500 h-2 rounded-full transition-all duration-500"
                style={{ width: `${progress}%` }}
              />
            </div>
            <div className="flex justify-between items-center mt-2 text-xs text-gray-500">
              <span>{targetAmount.toFixed(2)} ETH goal</span>
              <div className="flex items-center">
                <Users className="w-3 h-3 mr-1" />
                {mockSupporters} supporters
              </div>
            </div>
          </div>
          
          {/* Support Button */}
          <button className="w-full bg-gradient-to-r from-emerald-500 to-teal-500 text-white py-3 px-4 rounded-lg hover:from-emerald-600 hover:to-teal-600 transition-all duration-200 font-semibold text-sm group-hover:shadow-lg flex items-center justify-center">
            <Heart className="w-4 h-4 mr-2" />
            Support This Cause
          </button>
        </div>
      </div>
    </motion.div>
  );
}
