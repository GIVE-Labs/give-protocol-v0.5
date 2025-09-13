import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { CONTRACT_ADDRESSES } from '../config/contracts';
import { NGO_REGISTRY_ABI } from '../abis/NGORegistry';
import { formatUnits } from 'viem';
import { keccak256, toBytes } from 'viem';

function NGOItem({ address, isManager, isCurrent, onAfterSetCurrent }: { address: `0x${string}`, isManager?: boolean, isCurrent?: boolean, onAfterSetCurrent?: () => void }) {
  const { data: info, isLoading } = useReadContract({
    address: CONTRACT_ADDRESSES.NGO_REGISTRY as `0x${string}`,
    abi: NGO_REGISTRY_ABI,
    functionName: 'getNGOInfo',
    args: [address],
  });

  const { writeContract, data: txHash, isPending } = useWriteContract();
  const { isLoading: confirming, isSuccess } = useWaitForTransactionReceipt({ hash: txHash });

  if (isLoading) {
    return (
      <div className="p-4 rounded-lg border bg-white animate-pulse h-24" />
    );
  }

  const [name, description, approvalTime, totalReceived, isActive] = (info || []) as any[];

  return (
    <div className="p-5 rounded-lg border bg-white">
      <div className="flex items-center justify-between">
        <div>
          <h3 className="text-lg font-semibold">{name || 'NGO'}</h3>
          <p className="text-sm text-gray-600 mt-1 line-clamp-2">{description}</p>
        </div>
        <div className="text-right text-sm">
          <div className="flex items-center gap-2 justify-end">
            <div className={`inline-block px-2 py-1 rounded-full ${isActive ? 'bg-green-100 text-green-700' : 'bg-gray-100 text-gray-600'}`}>{isActive ? 'Active' : 'Inactive'}</div>
            {isCurrent && (
              <div className="inline-block px-2 py-1 rounded-full bg-brand-100 text-brand-700">Current</div>
            )}
          </div>
          <div className="mt-2 font-mono text-xs text-gray-500">{address.slice(0, 6)}…{address.slice(-4)}</div>
        </div>
      </div>
      <div className="mt-3 grid grid-cols-2 gap-4 text-sm">
        <div>
          <div className="text-gray-500">Total Received</div>
          <div className="font-medium">{totalReceived ? formatUnits(totalReceived as bigint, 6) : '0.00'} USDC</div>
        </div>
        <div>
          <div className="text-gray-500">Approved Since</div>
          <div className="font-medium">{approvalTime ? new Date(Number(approvalTime) * 1000).toLocaleDateString() : '-'}</div>
        </div>
      </div>
      {isManager && !isCurrent && (
        <div className="mt-4 flex justify-end">
          <button
            onClick={() => {
              writeContract({
                address: CONTRACT_ADDRESSES.NGO_REGISTRY as `0x${string}`,
                abi: NGO_REGISTRY_ABI,
                functionName: 'setCurrentNGO',
                args: [address],
              }, {
                onSuccess: () => {
                  onAfterSetCurrent && onAfterSetCurrent();
                }
              });
            }}
            disabled={isPending || confirming}
            className="px-3 py-2 rounded-md bg-brand-600 hover:bg-brand-700 text-white disabled:opacity-60"
          >
            {isPending || confirming ? 'Setting…' : 'Set as Current'}
          </button>
        </div>
      )}
    </div>
  );
}

export default function NGOsPage() {
  const { isConnected } = useAccount();
  const NGO_MANAGER_ROLE = keccak256(toBytes('NGO_MANAGER_ROLE')) as `0x${string}`;
  const { address } = useAccount();

  const { data: approvedNGOs, isLoading: loadingList } = useReadContract({
    address: CONTRACT_ADDRESSES.NGO_REGISTRY as `0x${string}`,
    abi: NGO_REGISTRY_ABI,
    functionName: 'getApprovedNGOs',
  });

  const { data: stats, refetch: refetchStats } = useReadContract({
    address: CONTRACT_ADDRESSES.NGO_REGISTRY as `0x${string}`,
    abi: NGO_REGISTRY_ABI,
    functionName: 'getRegistryStats',
  });

  const { data: isManager } = useReadContract({
    address: CONTRACT_ADDRESSES.NGO_REGISTRY as `0x${string}`,
    abi: NGO_REGISTRY_ABI,
    functionName: 'hasRole',
    args: address ? [NGO_MANAGER_ROLE, address] : undefined,
    query: { enabled: !!address },
  });

  const totalApproved = stats ? (stats as any[])[0] as bigint : 0n;
  const currentNGO = stats ? (stats as any[])[1] as `0x${string}` : undefined;
  const totalDonations = stats ? (stats as any[])[2] as bigint : 0n;

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-10">
      <div className="mb-6">
        <h1 className="text-3xl font-bold">NGOs</h1>
        <p className="text-gray-600 mt-1">Browse approved NGOs. Yield from the vault is routed to the current NGO.</p>
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
            <NGOItem key={addr} address={addr} isManager={Boolean(isManager)} isCurrent={currentNGO === addr} onAfterSetCurrent={() => refetchStats()} />
          ))}
        </div>
      ) : (
        <div className="bg-white rounded-lg border p-8 text-center text-gray-600">No approved NGOs found.</div>
      )}
    </div>
  );
}
