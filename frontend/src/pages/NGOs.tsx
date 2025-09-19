import { useReadContract } from 'wagmi';
import { useNavigate } from 'react-router-dom';
import { CONTRACT_ADDRESSES } from '../config/contracts';
import NGORegistryABI from '../abis/NGORegistry.json';
import { motion } from 'framer-motion';
import { Heart, MapPin, Users, Search } from 'lucide-react';
import { useState, useEffect } from 'react';
import { fetchMetadataFromIPFS, getIPFSUrl } from '../services/ipfs';


// Type definition for NGO info from contract
interface NGOInfo {
  metadataCid: string; // string CID from contract
  kycHash: `0x${string}`;
  attestor: `0x${string}`;
  createdAt: bigint;
  updatedAt: bigint;
  version: bigint;
  totalReceived: bigint;
  isActive: boolean;
}

// Type definition for NGO metadata
interface NGOMetadata {
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



function CampaignCard({ address, index, onMetadataLoad }: { 
  address: `0x${string}`, 
  index: number,
  onMetadataLoad?: (address: string, metadata: NGOMetadata | null) => void
}) {
  const navigate = useNavigate();
  const [metadata, setMetadata] = useState<NGOMetadata | null>(null);
  const [, setMetadataLoading] = useState(false);
  
  const { data: ngoInfo, isLoading } = useReadContract({
    address: CONTRACT_ADDRESSES.NGO_REGISTRY,
    abi: NGORegistryABI,
    functionName: 'getNGOInfo',
    args: [address],
  });



  // Fetch metadata from IPFS when ngoInfo is available
  useEffect(() => {
    async function loadMetadata() {
      console.log('NGO Info for', address, ':', ngoInfo);
      if (!ngoInfo || !(ngoInfo as NGOInfo).metadataCid) {
        console.log('No ngoInfo or metadataCid for', address);
        return;
      }
      
      const metadataCid = (ngoInfo as NGOInfo).metadataCid;
      console.log('Raw metadataCid for', address, ':', metadataCid, 'Type:', typeof metadataCid);
      
      setMetadataLoading(true);
      try {
        // metadataCid is now a string CID directly from contract
        console.log('Using CID directly:', metadataCid);
        
        if (!metadataCid || metadataCid.trim() === '') {
          console.warn('Empty metadataCid');
          return;
        }
        
        const fetchedMetadata = await fetchMetadataFromIPFS(metadataCid);
        console.log('Fetched metadata for', address, ':', fetchedMetadata);
        setMetadata(fetchedMetadata);
        
        // Call parent callback to update metadata in parent component
        if (onMetadataLoad) {
          onMetadataLoad(address, fetchedMetadata);
        }
      } catch (error) {
        console.warn('Failed to fetch metadata for NGO:', address, error);
      } finally {
        setMetadataLoading(false);
      }
    }
    
    loadMetadata();
  }, [ngoInfo, address]);

  // Get actual values from metadata or use fallbacks
  const fundingGoal = metadata?.fundingGoal ? parseFloat(metadata.fundingGoal) : 20000;
  const totalReceived = Number((ngoInfo as NGOInfo)?.totalReceived || 0n) / 1e18; // Convert from wei
  const progress = fundingGoal > 0 ? Math.min((totalReceived / fundingGoal) * 100, 100) : 0;
  
  // Use actual images from metadata or fallback
  const campaignImages = metadata?.images && metadata.images.length > 0 
    ? metadata.images.map(hash => getIPFSUrl(hash))
    : ['/src/assets/IMG_4241.jpg', '/src/assets/IMG_5543.jpg', '/src/assets/IMG_5550.jpg'];
  
  // Mock supporters count (this would come from contract events in a real implementation)
  const mockSupporters = [234, 156, 89, 445, 67, 523][index % 6];

  const handleDonateClick = () => {
    navigate(`/campaign/${address}`);
  };

  if (isLoading) {
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

  if (!ngoInfo) {
    return null;
  }

  // Use fetched metadata or fallback values
  const name = metadata?.name || 'Unknown Campaign';

  
  const isActive = (ngoInfo as NGOInfo)?.isActive || false;

  return (
    <motion.div 
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ delay: index * 0.1 }}
      className="bg-white rounded-xl shadow-sm border overflow-hidden hover:shadow-lg transition-all duration-300 cursor-pointer group flex flex-col h-full"
      onClick={handleDonateClick}
    >
      {/* Campaign Image */}
      <div className="relative h-48 overflow-hidden">
        <img 
          src={campaignImages[index % campaignImages.length]} 
          alt={name}
          className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
        />
        <div className="absolute top-3 right-3">
          <span className={`px-2 py-1 text-xs rounded-full font-medium backdrop-blur-sm ${
            isActive ? 'bg-green-500/90 text-white' : 'bg-red-500/90 text-white'
          }`}>
            {isActive ? 'Active' : 'Inactive'}
          </span>
        </div>
        <div className="absolute bottom-3 left-3">
          <div className="flex items-center text-white text-xs bg-black/50 backdrop-blur-sm px-2 py-1 rounded-full">
            <MapPin className="w-3 h-3 mr-1" />
            {metadata?.category || 'General'}
          </div>
        </div>
      </div>

      {/* Campaign Content */}
  <div className="p-6 flex flex-col flex-1">
        <div className="flex items-center justify-between mb-3">
          <span className="px-3 py-1 bg-emerald-100 text-emerald-800 text-xs font-medium rounded-full">
            {metadata?.category || 'General'}
          </span>
          <Heart className="w-5 h-5 text-gray-400 hover:text-red-500 cursor-pointer transition-colors" />
        </div>
        
        <h3 className="text-justify font-bold text-lg text-gray-900 mb-2 group-hover:text-emerald-600 transition-colors whitespace-normal break-words font-unbounded">
          {metadata?.name || 'Unnamed NGO'}
        </h3>
        
        <p className="text-gray-600 text-sm mb-4 line-clamp-2 leading-relaxed">
          {metadata?.description || metadata?.missionStatement || 'No description available'}
        </p>
        
        {/* Progress Bar and CTA - pushed to bottom for consistent alignment */}
        <div className="mt-auto">
          <div className="mb-4">
          <div className="flex justify-between items-center mb-2">
            <span className="text-sm font-semibold text-gray-900">
              ${totalReceived.toLocaleString()} raised
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
            <span>${fundingGoal.toLocaleString()} goal</span>
            <div className="flex items-center">
              <Users className="w-3 h-3 mr-1" />
              {mockSupporters} supporters
            </div>
          </div>
          </div>
          
          {/* Donate Button */}
          <button className="w-full bg-gradient-to-r from-emerald-500 to-teal-500 text-white py-3 px-4 rounded-lg hover:from-emerald-600 hover:to-teal-600 transition-all duration-200 font-semibold text-sm group-hover:shadow-lg flex items-center justify-center">
            <Heart className="w-4 h-4 mr-2" />
            Support This Cause
          </button>
        </div>
      </div>
    </motion.div>
  );
}

export default function NGOsPage() {
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedCategory, setSelectedCategory] = useState('All Causes');
  const [ngoMetadata, setNgoMetadata] = useState<Record<string, NGOMetadata | null>>({});
  
  const { data: approvedNGOs, isLoading: loadingList } = useReadContract({
    address: CONTRACT_ADDRESSES.NGO_REGISTRY as `0x${string}`,
    abi: NGORegistryABI,
    functionName: 'getApprovedNGOs',
  });

  // Callback to receive metadata from CampaignCard components
  const handleMetadataLoad = (address: string, metadata: NGOMetadata | null) => {
    setNgoMetadata(prev => ({
      ...prev,
      [address]: metadata
    }));
  };

  // Filter NGOs based on search query and category
  const filteredNGOs = approvedNGOs ? (approvedNGOs as any[]).filter((ngoAddress) => {
    const metadata = ngoMetadata[ngoAddress];
    
    // Search filter
    if (searchQuery.trim()) {
      const query = searchQuery.toLowerCase();
      const name = metadata?.name?.toLowerCase() || '';
      const description = metadata?.description?.toLowerCase() || '';
      const missionStatement = metadata?.missionStatement?.toLowerCase() || '';
      const category = metadata?.category?.toLowerCase() || '';
      
      const matchesSearch = name.includes(query) || 
                           description.includes(query) || 
                           missionStatement.includes(query) ||
                           category.includes(query);
      
      if (!matchesSearch) return false;
    }
    
    // Category filter
    if (selectedCategory !== 'All Causes') {
      const ngoCategory = metadata?.category || '';
      // Map display names to potential metadata categories
      const categoryMap: Record<string, string[]> = {
        'Education': ['Education', 'education'],
        'Healthcare': ['Healthcare', 'Health', 'healthcare', 'health'],
        'Environment': ['Environment', 'environmental', 'environment'],
        'Poverty': ['Poverty Alleviation', 'Poverty', 'poverty'],
        'Emergency': ['Emergency', 'emergency', 'disaster', 'relief']
      };
      
      const allowedCategories = categoryMap[selectedCategory] || [selectedCategory];
      if (!allowedCategories.some(cat => ngoCategory.toLowerCase().includes(cat.toLowerCase()))) {
        return false;
      }
    }
    
    return true;
  }) : [];

  // Debug logging
  console.log('NGO Registry Address:', CONTRACT_ADDRESSES.NGO_REGISTRY);
  console.log('Approved NGOs:', approvedNGOs);
  console.log('Loading:', loadingList);

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
      </div>

      {/* Hero Section */}
      <div className="bg-gradient-to-r from-emerald-600 via-cyan-600 to-teal-600 text-white relative z-10">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-16">
          <motion.div 
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            className="text-center"
          >
            <h1 className="text-4xl md:text-5xl font-bold mb-4 font-unbounded">
              Discover Amazing Causes
            </h1>
            <p className="text-xl text-emerald-100 mb-8 max-w-2xl mx-auto font-medium font-unbounded">
              Support impactful campaigns and help make a difference in the world. Every contribution matters.
            </p>
            
            {/* Search Bar */}
            <div className="max-w-md mx-auto relative">
              <div className="relative">
                <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 w-5 h-5" />
                <input 
                  type="text" 
                  placeholder="Search campaigns..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  className="w-full pl-10 pr-4 py-3 rounded-2xl text-gray-900 placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-emerald-300 shadow-lg bg-white/90 backdrop-blur-sm"
                />
              </div>
            </div>
          </motion.div>
        </div>
      </div>



      {/* Campaigns Grid */}
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        {/* Categories Filter */}
        <motion.div 
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.2 }}
          className="flex flex-wrap gap-3 mb-8 justify-center"
        >
          {['All Causes', 'Education', 'Healthcare', 'Environment', 'Poverty', 'Emergency'].map((category) => (
            <button 
              key={category}
              onClick={() => setSelectedCategory(category)}
              className={`px-4 py-2 rounded-full text-sm font-medium transition-all ${
                selectedCategory === category 
                  ? 'bg-emerald-500 text-white shadow-lg' 
                  : 'bg-white text-gray-600 border border-gray-200 hover:border-emerald-300 hover:text-emerald-600'
              }`}
            >
              {category}
            </button>
          ))}
        </motion.div>

        {/* Featured Campaign Banner */}
        {/* <motion.div 
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.3 }}
          className="bg-gradient-to-r from-blue-500 to-purple-600 rounded-2xl p-8 mb-12 text-white relative overflow-hidden"
        >
          <div className="relative z-10">
            <div className="flex items-center mb-4">
              <TrendingUp className="w-6 h-6 mr-2" />
              <span className="text-sm font-semibold bg-white/20 px-3 py-1 rounded-full">Featured Campaign</span>
            </div>
            <h2 className="text-3xl font-bold mb-2">Emergency Relief Fund</h2>
            <p className="text-blue-100 mb-4 max-w-2xl">Help provide immediate assistance to communities affected by natural disasters worldwide.</p>
            <div className="flex items-center space-x-6">
              <div>
                <div className="text-2xl font-bold">$45,230</div>
                <div className="text-blue-200 text-sm">raised of $60,000</div>
              </div>
              <div>
                <div className="text-2xl font-bold">1,234</div>
                <div className="text-blue-200 text-sm">supporters</div>
              </div>
            </div>
          </div>
          <div className="absolute top-0 right-0 w-64 h-64 bg-white/10 rounded-full -mr-32 -mt-32" />
          <div className="absolute bottom-0 right-0 w-48 h-48 bg-white/5 rounded-full -mr-24 -mb-24" />
        </motion.div> */}

        {/* Campaigns Grid */}
        {loadingList ? (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
            {Array.from({ length: 6 }).map((_, i) => (
              <motion.div 
                key={i}
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: i * 0.1 }}
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
            ))}
          </div>
        ) : filteredNGOs.length > 0 ? (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
            {filteredNGOs.map((ngo, index) => (
              <CampaignCard 
                key={ngo} 
                address={ngo} 
                index={index} 
                onMetadataLoad={handleMetadataLoad}
              />
            ))}
          </div>
        ) : approvedNGOs && (approvedNGOs as any[]).length > 0 ? (
          <motion.div 
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            className="bg-white rounded-xl border p-12 text-center"
          >
            <div className="w-16 h-16 bg-gray-100 rounded-full flex items-center justify-center mx-auto mb-4">
              <Search className="w-8 h-8 text-gray-400" />
            </div>
            <h3 className="text-lg font-semibold text-gray-900 mb-2">No campaigns match your search</h3>
            <p className="text-gray-600">Try adjusting your search terms or category filter!</p>
          </motion.div>
        ) : (
          <motion.div 
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            className="bg-white rounded-xl border p-12 text-center"
          >
            <div className="w-16 h-16 bg-gray-100 rounded-full flex items-center justify-center mx-auto mb-4">
              <Heart className="w-8 h-8 text-gray-400" />
            </div>
            <h3 className="text-lg font-semibold text-gray-900 mb-2">No campaigns found</h3>
            <p className="text-gray-600">Check back soon for new campaigns to support!</p>
          </motion.div>
        )}
      </div>
    </div>
  );
}
