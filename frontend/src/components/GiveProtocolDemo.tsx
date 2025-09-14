import { useState } from 'react';
import { useAccount, useConnect, useDisconnect } from 'wagmi';
import { formatUnits } from 'viem';
import { useVault, useUSDC, useNGORegistry, useDonationRouter, useStrategyManager } from '../hooks/useContracts';

export function GiveProtocolDemo() {
  const { address, isConnected } = useAccount();
  const { connect, connectors } = useConnect();
  const { disconnect } = useDisconnect();
  
  const [depositAmount, setDepositAmount] = useState('100');
  const [withdrawAmount, setWithdrawAmount] = useState('50');
  
  const vault = useVault();
  const usdc = useUSDC();
  const ngoRegistry = useNGORegistry();
  const donationRouter = useDonationRouter();
  const strategyManager = useStrategyManager();

  if (!isConnected) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="bg-white p-8 rounded-lg shadow-lg max-w-md w-full">
          <h1 className="text-2xl font-bold text-center mb-6">GIVE Protocol</h1>
          <p className="text-gray-600 text-center mb-6">
            Connect your wallet to start earning yield for NGOs
          </p>
          <div className="space-y-3">
            {connectors.map((connector) => (
              <button
                key={connector.uid}
                onClick={() => connect({ connector })}
                className="w-full bg-blue-500 hover:bg-blue-600 text-white font-medium py-2 px-4 rounded-lg transition-colors"
              >
                Connect {connector.name}
              </button>
            ))}
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50 p-4">
      <div className="max-w-6xl mx-auto">
        {/* Header */}
        <div className="bg-white rounded-lg shadow-sm p-6 mb-6">
          <div className="flex justify-between items-center">
            <h1 className="text-3xl font-bold text-gray-900">GIVE Protocol Dashboard</h1>
            <div className="flex items-center space-x-4">
              <span className="text-sm text-gray-600">
                {address?.slice(0, 6)}...{address?.slice(-4)}
              </span>
              <button
                onClick={() => disconnect()}
                className="bg-red-500 hover:bg-red-600 text-white px-4 py-2 rounded-lg text-sm transition-colors"
              >
                Disconnect
              </button>
            </div>
          </div>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {/* Wallet & Vault Stats */}
          <div className="space-y-6">
            {/* Wallet Info */}
            <div className="bg-white rounded-lg shadow-sm p-6">
              <h2 className="text-xl font-semibold mb-4">Wallet Balance</h2>
              <div className="space-y-2">
                <div className="flex justify-between">
                  <span className="text-gray-600">USDC Balance:</span>
                  <span className="font-medium">{usdc.balance} USDC</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-600">Vault Allowance:</span>
                  <span className="font-medium">{usdc.allowance} USDC</span>
                </div>
              </div>
              
              <button
                onClick={() => usdc.approve('10000')}
                disabled={usdc.isPending}
                className="w-full mt-4 bg-blue-500 hover:bg-blue-600 disabled:bg-gray-400 text-white py-2 px-4 rounded-lg transition-colors"
              >
                {usdc.isPending ? 'Approving...' : 'Approve 10,000 USDC'}
              </button>
            </div>

            {/* Vault Stats */}
            <div className="bg-white rounded-lg shadow-sm p-6">
              <h2 className="text-xl font-semibold mb-4">Vault Statistics</h2>
              <div className="space-y-2">
                <div className="flex justify-between">
                  <span className="text-gray-600">Total Assets:</span>
                  <span className="font-medium">{vault.totalAssets} USDC</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-600">Cash Balance:</span>
                  <span className="font-medium">{vault.cashBalance} USDC</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-600">Adapter Assets:</span>
                  <span className="font-medium">{vault.adapterAssets} USDC</span>
                </div>
              </div>
              
              {vault.harvestStats && (
                <div className="mt-4 pt-4 border-t">
                  <h3 className="font-medium mb-2">Harvest Statistics</h3>
                  <div className="space-y-1 text-sm">
                    <div className="flex justify-between">
                      <span className="text-gray-600">Total Profit:</span>
                      <span className="text-green-600">
                        {formatUnits(vault.harvestStats[0], 6)} USDC
                      </span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-gray-600">Total Loss:</span>
                      <span className="text-red-600">
                        {formatUnits(vault.harvestStats[1], 6)} USDC
                      </span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-gray-600">Last Harvest:</span>
                      <span>
                        {new Date(Number(vault.harvestStats[2]) * 1000).toLocaleDateString()}
                      </span>
                    </div>
                  </div>
                </div>
              )}
            </div>
          </div>

          {/* Actions & NGOs */}
          <div className="space-y-6">
            {/* Vault Actions */}
            <div className="bg-white rounded-lg shadow-sm p-6">
              <h2 className="text-xl font-semibold mb-4">Vault Actions</h2>
              
              {/* Deposit */}
              <div className="mb-4">
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Deposit Amount (USDC)
                </label>
                <div className="flex space-x-2">
                  <input
                    type="number"
                    value={depositAmount}
                    onChange={(e) => setDepositAmount(e.target.value)}
                    className="flex-1 border border-gray-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
                    placeholder="100"
                  />
                  <button
                    onClick={() => vault.deposit(depositAmount, address!)}
                    disabled={vault.isPending || !address}
                    className="bg-green-500 hover:bg-green-600 disabled:bg-gray-400 text-white px-4 py-2 rounded-lg transition-colors"
                  >
                    {vault.isPending ? 'Depositing...' : 'Deposit'}
                  </button>
                </div>
              </div>
              
              {/* Withdraw */}
              <div className="mb-4">
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Withdraw Amount (USDC)
                </label>
                <div className="flex space-x-2">
                  <input
                    type="number"
                    value={withdrawAmount}
                    onChange={(e) => setWithdrawAmount(e.target.value)}
                    className="flex-1 border border-gray-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
                    placeholder="50"
                  />
                  <button
                    onClick={() => vault.withdraw(withdrawAmount, address!, address!)}
                    disabled={vault.isPending || !address}
                    className="bg-orange-500 hover:bg-orange-600 disabled:bg-gray-400 text-white px-4 py-2 rounded-lg transition-colors"
                  >
                    {vault.isPending ? 'Withdrawing...' : 'Withdraw'}
                  </button>
                </div>
              </div>
              
              {/* Harvest */}
              <button
                onClick={() => vault.harvest()}
                disabled={vault.isPending}
                className="w-full bg-purple-500 hover:bg-purple-600 disabled:bg-gray-400 text-white py-2 px-4 rounded-lg transition-colors"
              >
                {vault.isPending ? 'Harvesting...' : 'Harvest Yield for NGOs'}
              </button>
            </div>

            {/* Strategy Management */}
            <div className="bg-white rounded-lg shadow-sm p-6">
              <h2 className="text-xl font-semibold mb-4">Strategy Management</h2>
              <div className="space-y-2 mb-4">
                <div className="flex justify-between">
                  <span className="text-gray-600">Active Adapter:</span>
                  <span className="font-mono text-xs">
                    {vault.activeAdapter?.slice(0, 10)}...
                  </span>
                </div>
              </div>
              
              <div className="space-y-2">
                <button
                  onClick={() => strategyManager.harvestAll()}
                  disabled={strategyManager.isPending}
                  className="w-full bg-indigo-500 hover:bg-indigo-600 disabled:bg-gray-400 text-white py-2 px-4 rounded-lg transition-colors"
                >
                  {strategyManager.isPending ? 'Harvesting...' : 'Strategy Harvest All'}
                </button>
              </div>
            </div>

            {/* NGO Information */}
            <div className="bg-white rounded-lg shadow-sm p-6">
              <h2 className="text-xl font-semibold mb-4">NGO Registry</h2>
              
              {ngoRegistry.verifiedNGOs && ngoRegistry.verifiedNGOs.length > 0 ? (
                <div>
                  <p className="text-sm text-gray-600 mb-2">
                    {ngoRegistry.verifiedNGOs.length} verified NGO(s)
                  </p>
                  <div className="space-y-2">
                    {ngoRegistry.verifiedNGOs.slice(0, 3).map((ngo, index) => (
                      <div key={index} className="bg-gray-50 p-2 rounded text-xs font-mono">
                        {(ngo as any).ngoAddress}
                      </div>
                    ))}
                  </div>
                </div>
              ) : (
                <p className="text-gray-500 text-sm">No verified NGOs found</p>
              )}
              
              {donationRouter.donationStats && (
                <div className="mt-4 pt-4 border-t">
                  <h3 className="font-medium mb-2">Distribution Stats</h3>
                  <div className="space-y-1 text-sm">
                    <div className="flex justify-between">
                      <span className="text-gray-600">Total Donated:</span>
                      <span className="text-green-600">
                        {formatUnits(donationRouter.donationStats[0], 6)} USDC
                      </span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-gray-600">Total Fees:</span>
                      <span>
                        {formatUnits(donationRouter.donationStats[1], 6)} USDC
                      </span>
                    </div>
                  </div>
                </div>
              )}
            </div>
          </div>
        </div>

        {/* Transaction Status */}
        {(vault.error || usdc.error || strategyManager.error) && (
          <div className="mt-6 bg-red-50 border border-red-200 rounded-lg p-4">
            <h3 className="text-red-800 font-medium mb-2">Transaction Error</h3>
            <p className="text-red-700 text-sm">
              {vault.error?.message || usdc.error?.message || strategyManager.error?.message}
            </p>
          </div>
        )}
        
        {(vault.isConfirmed || usdc.isConfirmed || strategyManager.isConfirmed) && (
          <div className="mt-6 bg-green-50 border border-green-200 rounded-lg p-4">
            <h3 className="text-green-800 font-medium mb-2">Transaction Confirmed</h3>
            <p className="text-green-700 text-sm">
              Your transaction has been successfully confirmed on the blockchain.
            </p>
          </div>
        )}
      </div>
    </div>
  );
}
