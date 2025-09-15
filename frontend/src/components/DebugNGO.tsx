import { useReadContract } from 'wagmi';
import { CONTRACT_ADDRESSES } from '../config/contracts';
import NGORegistryABI from '../abis/NGORegistry.json';

export function DebugNGO() {
  const { data: approvedNGOs, isLoading, error } = useReadContract({
    address: CONTRACT_ADDRESSES.NGO_REGISTRY as `0x${string}`,
    abi: NGORegistryABI,
    functionName: 'getApprovedNGOs',
  });

  return (
    <div className="p-4 bg-gray-100 rounded-lg">
      <h3 className="font-bold mb-2">Debug NGO Data</h3>
      <div className="space-y-2">
        <p><strong>Contract Address:</strong> {CONTRACT_ADDRESSES.NGO_REGISTRY}</p>
        <p><strong>Loading:</strong> {isLoading ? 'Yes' : 'No'}</p>
        <p><strong>Error:</strong> {error ? error.message : 'None'}</p>
        <p><strong>Data:</strong></p>
        <pre className="bg-white p-2 rounded text-xs overflow-auto">
          {JSON.stringify(approvedNGOs, null, 2)}
        </pre>
      </div>
    </div>
  );
}