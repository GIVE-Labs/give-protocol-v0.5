import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi'
import { useEffect, useMemo, useState } from 'react'
import { keccak256, toBytes, stringToHex } from 'viem'
import { CONTRACT_ADDRESSES } from '../config/contracts'
import NGORegistryABI from '../abis/NGORegistry.json'

export default function CreateNGO() {
  const { address, isConnected } = useAccount()
  const [ngoAddress, setNgoAddress] = useState<string>('')
  const [name, setName] = useState('')
  const [description, setDescription] = useState('')
  const [website, setWebsite] = useState('')
  const [logoUrl, setLogoUrl] = useState('')

  const registry = CONTRACT_ADDRESSES.NGO_REGISTRY as `0x${string}`
  const NGO_MANAGER_ROLE = useMemo(() => keccak256(toBytes('NGO_MANAGER_ROLE')), [])

  // Role check: only managers can add NGOs
  const { data: isManager } = useReadContract({
    address: registry,
    abi: NGORegistryABI,
    functionName: 'hasRole',
    args: address ? [NGO_MANAGER_ROLE as `0x${string}`, address] : undefined,
    query: { enabled: !!address },
  })

  const { writeContract, data: txHash, isPending, error } = useWriteContract()
  const { isLoading: confirming, isSuccess: confirmed } = useWaitForTransactionReceipt({ hash: txHash })

  useEffect(() => {
    if (isConnected && !ngoAddress) setNgoAddress(address!)
  }, [isConnected, address, ngoAddress])

  const canSubmit = !!name && !!description && !!ngoAddress && isManager

  const onSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    if (!canSubmit) return
    
    // Create metadata object and convert to bytes32
    const metadata = JSON.stringify({ name, description, website, logoUrl })
    const metadataCid = stringToHex(metadata, { size: 32 })
    const kycHash = keccak256(toBytes('mock-kyc-hash')) // Mock KYC hash for development
    
    writeContract({
      address: registry,
      abi: NGORegistryABI,
      functionName: 'addNGO',
      args: [ngoAddress as `0x${string}`, metadataCid, kycHash, address as `0x${string}`],
    })
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-emerald-50 via-cyan-50 to-teal-50 relative overflow-hidden">
      {/* Animated Background Elements */}
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        <div className="absolute top-20 left-10 w-32 h-32 bg-gradient-to-r from-emerald-200/30 to-cyan-200/30 rounded-full blur-xl" />
        <div className="absolute top-40 right-20 w-24 h-24 bg-gradient-to-r from-teal-200/30 to-blue-200/30 rounded-full blur-xl" />
      </div>
      
      <div className="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 py-12 relative z-10">
        <div className="mb-8">
          <h1 className="text-3xl font-bold font-unbounded text-gray-900">Register New NGO</h1>
          <p className="text-gray-600 mt-1 font-medium font-unbounded">Submit NGO details. Only admins can approve on-chain.</p>
        </div>

      <form onSubmit={onSubmit} className="bg-white rounded-lg border p-6 space-y-5">
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-2">NGO Address</label>
          <input
            type="text"
            value={ngoAddress}
            onChange={(e) => setNgoAddress(e.target.value)}
            placeholder="0x…"
            className="w-full px-3 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-brand-500 font-mono"
          />
          <p className="text-xs text-gray-500 mt-1">Defaulted to your wallet. Admins may set a different receiving address.</p>
        </div>
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-2">NGO Name</label>
          <input
            type="text"
            value={name}
            onChange={(e) => setName(e.target.value)}
            placeholder="e.g., Clean Water Initiative"
            className="w-full px-3 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-brand-500"
          />
        </div>
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-2">Description</label>
          <textarea
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            placeholder="Brief description of your mission and impact."
            className="w-full px-3 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-brand-500"
            rows={4}
          />
        </div>
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-2">Website URL</label>
          <input
            type="url"
            value={website}
            onChange={(e) => setWebsite(e.target.value)}
            placeholder="https://your-ngo-website.org"
            className="w-full px-3 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-brand-500"
          />
        </div>
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-2">Logo URL</label>
          <input
            type="url"
            value={logoUrl}
            onChange={(e) => setLogoUrl(e.target.value)}
            placeholder="https://your-logo-url.com/logo.png"
            className="w-full px-3 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-brand-500"
          />
        </div>

        <div className="flex items-center justify-between">
          <div className="text-sm text-gray-600">
            {isManager ? (
              <span className="text-emerald-700">You have admin rights to approve NGOs.</span>
            ) : (
              <span className="text-gray-600">Only admins can approve NGOs on-chain.</span>
            )}
          </div>
          <button
            type="submit"
            disabled={!canSubmit || isPending || confirming}
            className="px-4 py-2 rounded-lg text-white bg-brand-600 hover:bg-brand-700 disabled:opacity-60"
          >
            {isPending || confirming ? 'Submitting…' : 'Register NGO'}
          </button>
        </div>

        {error && (
          <div className="text-sm text-rose-700 bg-rose-50 border border-rose-200 rounded-md p-3">{error.message}</div>
        )}
        {confirmed && (
          <div className="text-sm text-emerald-700 bg-emerald-50 border border-emerald-200 rounded-md p-3">NGO approved successfully.</div>
        )}
      </form>

      {!isManager && (
        <div className="mt-6 bg-white rounded-lg border p-4 text-sm text-gray-700">
          <div className="font-medium mb-1">Not an admin?</div>
          Share your details with an admin to be added:
          <ul className="list-disc ml-5 mt-2">
            <li>NGO Address: {ngoAddress || '(fill above)'}</li>
            <li>Name: {name || '(fill above)'}</li>
            <li>Description: {description || '(fill above)'}</li>
            <li>Website: {website || '(fill above)'}</li>
            <li>Logo URL: {logoUrl || '(fill above)'}</li>
          </ul>
        </div>
      )}
      </div>
    </div>
  )
}
