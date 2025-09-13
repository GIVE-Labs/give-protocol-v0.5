import { useAccount, useReadContract } from 'wagmi';
import { useNavigate } from 'react-router-dom';
import { CONTRACT_ADDRESSES } from '../config/contracts';
import { NGO_REGISTRY_ABI } from '../abis/NGORegistry';

import { formatUnits } from 'viem';
import { keccak256, toBytes } from 'viem';

function CampaignCard({ address }: { address: `0x${string}` }) {
  const navigate = useNavigate();
  
  const { data: ngoInfo, isLoading } = useReadContract({
    address: CONTRACT_ADDRESSES.NGO_REGISTRY,
    abi: NGO_REGISTRY_ABI,
    functionName: 'getNGOInfo',
    args: [address],
  });

  // Removed staking contract call - no longer using MORPH_IMPACT_STAKING
  const totalStaked = BigInt(0);

  // Calculate current APY (this would typically come from the vault)
  const calculateAPY = (): number => {
    const baseAPY = 5.0; // 5% base APY
    const lockMultiplier = 1.2; // 12 month default
    return baseAPY * lockMultiplier;
  };

  const handleStakeClick = () => {
    navigate(`/campaign/${address}`);
  };

  if (isLoading) {
    return <div className="p-6 rounded-lg border bg-white animate-pulse h-64" />;
  }

  if (!ngoInfo) {
    return null;
  }

  const name = (ngoInfo as any)?.name || 'Unknown Campaign';
    const description = (ngoInfo as any)?.description || 'No description available';
    const isActive = (ngoInfo as any)?.isActive || false;
  const currentAPY = calculateAPY();

  return (
    <div className="bg-white rounded-lg border hover:shadow-lg transition-all duration-200 cursor-pointer group"
         onClick={handleStakeClick}>
      <div className="p-6">
        <div className="flex justify-between items-start mb-4">
          <h3 className="font-bold text-xl text-gray-900 group-hover:text-blue-600 transition-colors">
            {name}
          </h3>
          <span className={`px-3 py-1 text-xs rounded-full font-medium ${
            isActive ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'
          }`}>
            {isActive ? 'Active' : 'Inactive'}
          </span>
        </div>
        
        <p className="text-gray-600 text-sm mb-4 line-clamp-2">{description}</p>
        
        {/* Campaign Stats */}
        <div className="grid grid-cols-2 gap-4 mb-4">
          <div className="bg-blue-50 p-3 rounded-lg">
            <div className="text-xs text-blue-600 font-medium">Current APY</div>
            <div className="text-lg font-bold text-blue-700">{currentAPY.toFixed(1)}%</div>
          </div>
          <div className="bg-green-50 p-3 rounded-lg">
            <div className="text-xs text-green-600 font-medium">Total Staked</div>
            <div className="text-lg font-bold text-green-700">
              {totalStaked ? formatUnits(totalStaked, 18).slice(0, 6) : '0'} ETH
            </div>
          </div>
        </div>
        

        
        <div className="flex justify-between items-center">
          <div className="text-xs text-gray-500">
            {address.slice(0, 6)}...{address.slice(-4)}
          </div>
          <button className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors text-sm font-medium group-hover:bg-blue-700">
            Stake Now →
          </button>
        </div>
      </div>
    </div>
  );
}

export default function NGOsPage() {
  useAccount();
  const NGO_MANAGER_ROLE = keccak256(toBytes('NGO_MANAGER_ROLE')) as `0x${string}`;
  const { address } = useAccount();

  const { data: approvedNGOs, isLoading: loadingList } = useReadContract({
    address: CONTRACT_ADDRESSES.NGO_REGISTRY as `0x${string}`,
    abi: NGO_REGISTRY_ABI,
    functionName: 'getApprovedNGOs',
  });

  const { data: stats } = useReadContract({
    address: CONTRACT_ADDRESSES.NGO_REGISTRY as `0x${string}`,
    abi: NGO_REGISTRY_ABI,
    functionName: 'getRegistryStats',
  });

  useReadContract({
    address: CONTRACT_ADDRESSES.NGO_REGISTRY as `0x${string}`,
    abi: NGO_REGISTRY_ABI,
    functionName: 'hasRole',
    args: address ? [NGO_MANAGER_ROLE, address] : undefined,
    query: { enabled: !!address },
  });

  const registryStats = stats as readonly [bigint, `0x${string}`, bigint] | undefined;
  const totalApproved = registryStats ? registryStats[0] : 0n;
  const currentNGO = registryStats ? registryStats[1] : undefined;
  const totalDonations = registryStats ? registryStats[2] : 0n;

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-10">
      <div className="mb-6">
        <h1 className="text-3xl font-bold">Discover Campaigns</h1>
        <p className="text-gray-600 mt-1">Stake your assets and generate yield for impactful causes</p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
        <div className="bg-white rounded-lg border p-4">
          <div className="text-sm text-gray-500">Approved NGOs</div>
          <div className="text-2xl font-semibold">{totalApproved?.toString?.() || '0'}</div>
        </div>
        <div className="bg-white rounded-lg border p-4">
          <div className="text-sm text-gray-500">Current NGO</div>
          <div className="text-sm font-mono text-gray-700">{currentNGO ? `${currentNGO.slice(0,6)}…${currentNGO.slice(-4)}` : '—'}</div>
        </div>
        <div className="bg-white rounded-lg border p-4">
          <div className="text-sm text-gray-500">Total Donated</div>
          <div className="text-2xl font-semibold">{formatUnits(totalDonations, 6)} USDC</div>
        </div>
      </div>

      {loadingList ? (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {Array.from({ length: 6 }).map((_, i) => (
            <div key={i} className="p-5 rounded-lg border bg-white animate-pulse h-32" />
          ))}
        </div>
      ) : approvedNGOs && (approvedNGOs as string[]).length > 0 ? (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {(approvedNGOs as `0x${string}`[]).map((addr) => (
            <CampaignCard key={addr} address={addr} />
          ))}
        </div>
      ) : (
        <div className="bg-white rounded-lg border p-8 text-center text-gray-600">No approved NGOs found.</div>
      )}
    </div>
  );
}
