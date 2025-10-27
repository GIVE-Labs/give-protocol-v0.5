import { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import { useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { CheckCircle, Pause, Play, Ban, AlertCircle } from 'lucide-react';
import { Link } from 'react-router-dom';
import campaignRegistryABI from '../../abis/CampaignRegistry.json';
import { hexToCid, fetchMetadataFromIPFS } from '../../services/ipfs';
import { CONTRACT_ADDRESSES } from '../../config/contracts';

const CAMPAIGN_REGISTRY_ADDRESS = (CONTRACT_ADDRESSES as any).CAMPAIGN_REGISTRY;

// Campaign Status Enum (matches Solidity)
const CampaignStatus = {
  Unknown: 0,
  Submitted: 1,
  Approved: 2,
  Active: 3,
  Paused: 4,
  Completed: 5,
  Cancelled: 6,
};

const statusConfig = {
  [CampaignStatus.Submitted]: {
    label: 'Pending Approval',
    color: 'yellow',
    bgClass: 'bg-yellow-100',
    textClass: 'text-yellow-800',
    borderClass: 'border-yellow-200',
    icon: AlertCircle,
  },
  [CampaignStatus.Approved]: {
    label: 'Approved',
    color: 'blue',
    bgClass: 'bg-blue-100',
    textClass: 'text-blue-800',
    borderClass: 'border-blue-200',
    icon: CheckCircle,
  },
  [CampaignStatus.Active]: {
    label: 'Active',
    color: 'emerald',
    bgClass: 'bg-emerald-100',
    textClass: 'text-emerald-800',
    borderClass: 'border-emerald-200',
    icon: Play,
  },
  [CampaignStatus.Paused]: {
    label: 'Paused',
    color: 'orange',
    bgClass: 'bg-orange-100',
    textClass: 'text-orange-800',
    borderClass: 'border-orange-200',
    icon: Pause,
  },
  [CampaignStatus.Completed]: {
    label: 'Completed',
    color: 'purple',
    bgClass: 'bg-purple-100',
    textClass: 'text-purple-800',
    borderClass: 'border-purple-200',
    icon: CheckCircle,
  },
  [CampaignStatus.Cancelled]: {
    label: 'Cancelled',
    color: 'red',
    bgClass: 'bg-red-100',
    textClass: 'text-red-800',
    borderClass: 'border-red-200',
    icon: Ban,
  },
};

interface CampaignAdminControlsProps {
  campaignId: `0x${string}`;
  index: number;
  statusFilter: string;
}

export default function CampaignAdminControls({ campaignId, index, statusFilter }: CampaignAdminControlsProps) {
  const [metadata, setMetadata] = useState<any>(null);
  const [isLoadingMetadata, setIsLoadingMetadata] = useState(false);
  const [curatorAddress, setCuratorAddress] = useState('');
  const [showCuratorInput, setShowCuratorInput] = useState(false);

  // Fetch campaign data
  const { data: campaignData, refetch: refetchCampaign } = useReadContract({
    address: CAMPAIGN_REGISTRY_ADDRESS as `0x${string}`,
    abi: campaignRegistryABI,
    functionName: 'getCampaign',
    args: [campaignId],
  });

  // Contract writes - MUST be called before any early returns
  const { writeContract: approveCampaign, data: approveHash, isPending: isApproving } = useWriteContract();
  const { writeContract: updateStatus, data: statusHash, isPending: isUpdatingStatus } = useWriteContract();

  const { isSuccess: isApproveSuccess } = useWaitForTransactionReceipt({ hash: approveHash });
  const { isSuccess: isStatusSuccess } = useWaitForTransactionReceipt({ hash: statusHash });

  const campaign = campaignData as any;
  const status = campaign?.status || 0;

  // Fetch IPFS metadata
  useEffect(() => {
    const loadMetadata = async () => {
      if (!campaign) return;
      
      const metadataHash = campaign.metadataHash;
      if (!metadataHash || metadataHash === '0x0000000000000000000000000000000000000000000000000000000000000000') {
        return;
      }
      
      setIsLoadingMetadata(true);
      
      try {
        const cid = await hexToCid(metadataHash, campaignId);
        if (!cid) return;
        
        const data = await fetchMetadataFromIPFS(cid);
        if (data) {
          setMetadata(data);
        }
      } catch (error) {
        console.error('Error loading metadata:', error);
      } finally {
        setIsLoadingMetadata(false);
      }
    };
    
    loadMetadata();
  }, [campaign, campaignId]);

  // Refetch on success
  useEffect(() => {
    if (isApproveSuccess || isStatusSuccess) {
      refetchCampaign();
    }
  }, [isApproveSuccess, isStatusSuccess, refetchCampaign]);

  // Filter by status - check AFTER all hooks
  const filterStatus = statusFilter === 'submitted' ? CampaignStatus.Submitted
    : statusFilter === 'approved' ? CampaignStatus.Approved
    : statusFilter === 'active' ? CampaignStatus.Active
    : statusFilter === 'paused' ? CampaignStatus.Paused
    : statusFilter === 'completed' ? CampaignStatus.Completed
    : statusFilter === 'cancelled' ? CampaignStatus.Cancelled
    : null;

  // Hide cancelled campaigns unless specifically filtering for them
  if (status === CampaignStatus.Cancelled && statusFilter !== 'cancelled') {
    return null;
  }

  // Hide if doesn't match filter - AFTER all hooks are called
  if (statusFilter !== 'all' && filterStatus !== null && status !== filterStatus) {
    return null;
  }

  const handleApprove = async () => {
    if (!curatorAddress) {
      alert('Please enter curator address');
      return;
    }

    try {
      await approveCampaign({
        address: CAMPAIGN_REGISTRY_ADDRESS as `0x${string}`,
        abi: campaignRegistryABI,
        functionName: 'approveCampaign',
        args: [campaignId, curatorAddress as `0x${string}`],
      });
    } catch (error) {
      console.error('Error approving campaign:', error);
    }
  };

  const handleStatusChange = async (newStatus: number) => {
    try {
      await updateStatus({
        address: CAMPAIGN_REGISTRY_ADDRESS as `0x${string}`,
        abi: campaignRegistryABI,
        functionName: 'setCampaignStatus',
        args: [campaignId, newStatus],
      });
    } catch (error) {
      console.error('Error updating status:', error);
    }
  };

  const config = statusConfig[status] || statusConfig[CampaignStatus.Submitted];
  const StatusIcon = config.icon;

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ delay: index * 0.05 }}
      className={`bg-white/80 backdrop-blur-sm rounded-2xl shadow-lg border-2 ${config.borderClass} p-6 hover:shadow-xl transition-all`}
    >
      <div className="flex flex-col lg:flex-row gap-6">
        {/* Left: Campaign Info */}
        <div className="flex-1">
          <div className="flex items-start gap-4 mb-4">
            {/* Status Badge */}
            <div className={`${config.bgClass} ${config.textClass} px-3 py-1.5 rounded-full text-xs font-semibold flex items-center gap-1.5`}>
              <StatusIcon className="w-3.5 h-3.5" />
              {config.label}
            </div>

            {metadata?.category && (
              <span className="bg-gray-100 text-gray-700 px-3 py-1.5 rounded-full text-xs font-medium">
                {metadata.category}
              </span>
            )}
          </div>

          <Link to={`/campaigns/${campaignId}`}>
            <h3 className="text-xl font-bold text-gray-900 mb-2 hover:text-emerald-600 transition-colors font-unbounded">
              {isLoadingMetadata ? 'Loading...' : metadata?.name || 'Unnamed Campaign'}
            </h3>
          </Link>

          <p className="text-gray-600 text-sm mb-3 line-clamp-2">
            {metadata?.mission || 'No description available'}
          </p>

          <div className="grid grid-cols-2 gap-3 text-sm">
            <div>
              <span className="text-gray-500">Campaign ID:</span>
              <div className="font-mono text-xs text-gray-900">{campaignId.slice(0, 10)}...</div>
            </div>
            <div>
              <span className="text-gray-500">Proposer:</span>
              <div className="font-mono text-xs text-gray-900">{campaign?.proposer?.slice(0, 10)}...</div>
            </div>
            {campaign?.curator !== '0x0000000000000000000000000000000000000000' && (
              <div>
                <span className="text-gray-500">Curator:</span>
                <div className="font-mono text-xs text-gray-900">{campaign?.curator?.slice(0, 10)}...</div>
              </div>
            )}
            <div>
              <span className="text-gray-500">Recipient:</span>
              <div className="font-mono text-xs text-gray-900">{campaign?.payoutRecipient?.slice(0, 10)}...</div>
            </div>
          </div>
        </div>

        {/* Right: Admin Actions */}
        <div className="lg:w-80 border-t lg:border-t-0 lg:border-l border-gray-200 pt-4 lg:pt-0 lg:pl-6">
          <h4 className="font-semibold text-gray-900 mb-3 font-unbounded">Admin Actions</h4>
          
          <div className="space-y-2">
            {/* Approve Campaign */}
            {status === CampaignStatus.Submitted && (
              <div className="space-y-2">
                {showCuratorInput ? (
                  <>
                    <input
                      type="text"
                      value={curatorAddress}
                      onChange={(e) => setCuratorAddress(e.target.value)}
                      placeholder="Curator address (0x...)"
                      className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-emerald-500 focus:border-transparent"
                    />
                    <div className="flex gap-2">
                      <button
                        onClick={handleApprove}
                        disabled={isApproving || !curatorAddress}
                        className="flex-1 bg-gradient-to-r from-emerald-500 to-teal-500 text-white px-4 py-2 rounded-lg text-sm font-semibold hover:from-emerald-600 hover:to-teal-600 disabled:opacity-50 disabled:cursor-not-allowed transition-all flex items-center justify-center gap-2"
                      >
                        <CheckCircle className="w-4 h-4" />
                        {isApproving ? 'Approving...' : 'Approve'}
                      </button>
                      <button
                        onClick={() => setShowCuratorInput(false)}
                        className="px-4 py-2 bg-gray-200 text-gray-700 rounded-lg text-sm font-semibold hover:bg-gray-300 transition-all"
                      >
                        Cancel
                      </button>
                    </div>
                  </>
                ) : (
                  <button
                    onClick={() => setShowCuratorInput(true)}
                    className="w-full bg-gradient-to-r from-emerald-500 to-teal-500 text-white px-4 py-2 rounded-lg text-sm font-semibold hover:from-emerald-600 hover:to-teal-600 transition-all flex items-center justify-center gap-2"
                  >
                    <CheckCircle className="w-4 h-4" />
                    Approve Campaign
                  </button>
                )}
              </div>
            )}

            {/* Activate (from Approved) */}
            {status === CampaignStatus.Approved && (
              <button
                onClick={() => handleStatusChange(CampaignStatus.Active)}
                disabled={isUpdatingStatus}
                className="w-full bg-gradient-to-r from-blue-500 to-cyan-500 text-white px-4 py-2 rounded-lg text-sm font-semibold hover:from-blue-600 hover:to-cyan-600 disabled:opacity-50 transition-all flex items-center justify-center gap-2"
              >
                <Play className="w-4 h-4" />
                {isUpdatingStatus ? 'Activating...' : 'Activate Campaign'}
              </button>
            )}

            {/* Pause (from Active) */}
            {status === CampaignStatus.Active && (
              <button
                onClick={() => handleStatusChange(CampaignStatus.Paused)}
                disabled={isUpdatingStatus}
                className="w-full bg-gradient-to-r from-orange-500 to-amber-500 text-white px-4 py-2 rounded-lg text-sm font-semibold hover:from-orange-600 hover:to-amber-600 disabled:opacity-50 transition-all flex items-center justify-center gap-2"
              >
                <Pause className="w-4 h-4" />
                {isUpdatingStatus ? 'Pausing...' : 'Pause Campaign'}
              </button>
            )}

            {/* Resume (from Paused) */}
            {status === CampaignStatus.Paused && (
              <button
                onClick={() => handleStatusChange(CampaignStatus.Active)}
                disabled={isUpdatingStatus}
                className="w-full bg-gradient-to-r from-emerald-500 to-teal-500 text-white px-4 py-2 rounded-lg text-sm font-semibold hover:from-emerald-600 hover:to-teal-600 disabled:opacity-50 transition-all flex items-center justify-center gap-2"
              >
                <Play className="w-4 h-4" />
                {isUpdatingStatus ? 'Resuming...' : 'Resume Campaign'}
              </button>
            )}

            {/* Complete (from Active) */}
            {status === CampaignStatus.Active && (
              <button
                onClick={() => handleStatusChange(CampaignStatus.Completed)}
                disabled={isUpdatingStatus}
                className="w-full bg-gradient-to-r from-purple-500 to-indigo-500 text-white px-4 py-2 rounded-lg text-sm font-semibold hover:from-purple-600 hover:to-indigo-600 disabled:opacity-50 transition-all flex items-center justify-center gap-2"
              >
                <CheckCircle className="w-4 h-4" />
                {isUpdatingStatus ? 'Completing...' : 'Mark Complete'}
              </button>
            )}

            {/* Cancel (from Submitted/Approved/Active/Paused) */}
            {[CampaignStatus.Submitted, CampaignStatus.Approved, CampaignStatus.Active, CampaignStatus.Paused].includes(status) && (
              <button
                onClick={() => handleStatusChange(CampaignStatus.Cancelled)}
                disabled={isUpdatingStatus}
                className="w-full bg-gradient-to-r from-red-500 to-red-600 text-white px-4 py-2 rounded-lg text-sm font-semibold hover:from-red-600 hover:to-red-700 disabled:opacity-50 transition-all flex items-center justify-center gap-2"
              >
                <Ban className="w-4 h-4" />
                {isUpdatingStatus ? 'Cancelling...' : 'Cancel Campaign'}
              </button>
            )}

            {/* View Details */}
            <Link
              to={`/campaigns/${campaignId}`}
              className="w-full bg-gray-100 text-gray-700 px-4 py-2 rounded-lg text-sm font-semibold hover:bg-gray-200 transition-all flex items-center justify-center gap-2"
            >
              View Details →
            </Link>
          </div>
        </div>
      </div>
    </motion.div>
  );
}
