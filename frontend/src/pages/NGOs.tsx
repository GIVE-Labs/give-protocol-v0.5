import { useReadContract } from 'wagmi';
import { useNavigate } from 'react-router-dom';
import { CONTRACT_ADDRESSES } from '../config/contracts';
import NGORegistryABI from '../abis/NGORegistry.json';
import { motion } from 'framer-motion';
import { Heart, MapPin, Users, Search } from 'lucide-react';
import { hexToString } from 'viem';

function CampaignCard({ address, index }: { address: `0x${string}`, index: number }) {
  const navigate = useNavigate();
  
  const { data: ngoInfo, isLoading } = useReadContract({
    address: CONTRACT_ADDRESSES.NGO_REGISTRY,
    abi: NGORegistryABI,
    functionName: 'getNGOInfo',
    args: [address],
  });

  // Using local images from assets folder
  const campaignImages = [
    '/src/assets/IMG_4241.jpg',
    '/src/assets/IMG_5543.jpg',
    '/src/assets/IMG_5550.jpg',
    '/src/assets/IMG_4241.jpg',
    '/src/assets/IMG_5543.jpg',
    '/src/assets/IMG_5550.jpg'
  ];

  const mockProgress = [65, 78, 45, 89, 34, 92][index % 6];
  const mockRaised = [12500, 8900, 3400, 15600, 2100, 18900][index % 6];
  const mockTarget = [20000, 12000, 8000, 18000, 6000, 22000][index % 6];
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

  // Parse metadata from metadataCid
  let name = 'Unknown Campaign';
  let description = 'Help us make a difference in the world';
  
  try {
    const metadataString = hexToString((ngoInfo as any).metadataCid, { size: 32 });
    const metadata = JSON.parse(metadataString.replace(/\0/g, ''));
    name = metadata.name || name;
    description = metadata.description || description;
  } catch (error) {
    console.warn('Failed to parse NGO metadata:', error);
  }
  
  const isActive = (ngoInfo as any)?.isActive || false;

  return (
    <motion.div 
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ delay: index * 0.1 }}
      className="bg-white rounded-xl shadow-sm border overflow-hidden hover:shadow-lg transition-all duration-300 cursor-pointer group"
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
            Education
          </div>
        </div>
      </div>

      {/* Campaign Content */}
      <div className="p-6">
        <h3 className="font-bold text-lg text-gray-900 mb-2 group-hover:text-emerald-600 transition-colors line-clamp-1 font-unbounded">
          {name}
        </h3>
        
        <p className="text-gray-600 text-sm mb-4 line-clamp-2 leading-relaxed">
          {description}
        </p>
        
        {/* Progress Bar */}
        <div className="mb-4">
          <div className="flex justify-between items-center mb-2">
            <span className="text-sm font-semibold text-gray-900">
              ${mockRaised.toLocaleString()} raised
            </span>
            <span className="text-sm text-gray-500">
              {mockProgress}%
            </span>
          </div>
          <div className="w-full bg-gray-200 rounded-full h-2">
            <div 
              className="bg-gradient-to-r from-emerald-500 to-teal-500 h-2 rounded-full transition-all duration-500"
              style={{ width: `${mockProgress}%` }}
            />
          </div>
          <div className="flex justify-between items-center mt-2 text-xs text-gray-500">
            <span>${mockTarget.toLocaleString()} goal</span>
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
    </motion.div>
  );
}

export default function NGOsPage() {
  const { data: approvedNGOs, isLoading: loadingList } = useReadContract({
    address: CONTRACT_ADDRESSES.NGO_REGISTRY as `0x${string}`,
    abi: NGORegistryABI,
    functionName: 'getApprovedNGOs',
  });

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
          {['All Causes', 'Education', 'Healthcare', 'Environment', 'Poverty', 'Emergency'].map((category, index) => (
            <button 
              key={category}
              className={`px-4 py-2 rounded-full text-sm font-medium transition-all ${
                index === 0 
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
        ) : approvedNGOs && (approvedNGOs as any[]).length > 0 ? (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
            {(approvedNGOs as any[]).map((ngo, index) => (
              <CampaignCard key={ngo} address={ngo} index={index} />
            ))}
          </div>
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
