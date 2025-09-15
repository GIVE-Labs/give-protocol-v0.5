import { useEffect, useMemo, useState } from 'react';
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { parseUnits, formatUnits } from 'viem';
import { CONTRACT_ADDRESSES } from '../../config/contracts';
import { erc20Abi } from '../../abis/erc20';
import GiveVault4626ABI from '../../abis/GiveVault4626.json';
import NGORegistryABI from '../../abis/NGORegistry.json';
import DonationRouterABI from '../../abis/DonationRouter.json';
import { motion } from 'framer-motion';

export default function StakeWETH() {
  const { address } = useAccount();
  const [amount, setAmount] = useState('');
  const [unstakeAmount, setUnstakeAmount] = useState('');
  const [mode, setMode] = useState<'stake' | 'unstake'>('stake');
  const [selectedNGO, setSelectedNGO] = useState<`0x${string}` | ''>('');

  const weth = CONTRACT_ADDRESSES.TOKENS.WETH as `0x${string}`;
  const vault = CONTRACT_ADDRESSES.VAULT as `0x${string}`;
  const registry = CONTRACT_ADDRESSES.NGO_REGISTRY as `0x${string}`;
  const router = CONTRACT_ADDRESSES.DONATION_ROUTER as `0x${string}`;

  // Reads: balances and allowance
  const { data: balance } = useReadContract({
    address: weth,
    abi: erc20Abi,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    query: { enabled: !!address },
  });

  const { data: allowance, refetch: refetchAllowance } = useReadContract({
    address: weth,
    abi: erc20Abi,
    functionName: 'allowance',
    args: address ? [address, vault] : undefined,
    query: { enabled: !!address },
  });

  // Reads: vault stats and user position
  const { data: totalAssets } = useReadContract({
    address: vault,
    abi: GiveVault4626ABI,
    functionName: 'totalAssets',
  });

  const { data: userShares } = useReadContract({
    address: vault,
    abi: erc20Abi,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    query: { enabled: !!address },
  });

  const { data: userAssets } = useReadContract({
    address: vault,
    abi: GiveVault4626ABI,
    functionName: 'convertToAssets',
    args: userShares ? [userShares as bigint] : undefined,
    query: { enabled: !!userShares },
  });

  // Note: These functions don't exist in the current ABIs
  // Commenting out until proper functions are available
  // const { data: activeAdapter } = useReadContract({
  //   address: manager,
  //   abi: StrategyManagerABI,
  //   functionName: 'getActiveAdapter',
  // });

  // const { data: aaveInfo } = useReadContract({
  //   address: (activeAdapter as `0x${string}`) || undefined,
  //   abi: AaveAdapterABI,
  //   functionName: 'getAaveInfo',
  //   query: { enabled: !!activeAdapter },
  // });

  // Placeholder APR calculation - replace when proper functions are available
  const aprPct = useMemo(() => {
    // Return a placeholder APR for now
    return "4.50";
  }, []);

  // NGO list + router stats
  const { data: allNGOs } = useReadContract({
    address: registry,
    abi: NGORegistryABI,
    functionName: 'getApprovedNGOs',
  });

  const { data: donationStats } = useReadContract({
    address: router,
    abi: DonationRouterABI,
    functionName: 'getDonationStats',
    args: selectedNGO ? [BigInt(0)] : undefined, // Using ngoId 0 as placeholder
    query: { enabled: !!selectedNGO },
  });

  // Selected NGO info
  const { data: selectedInfo } = useReadContract({
    address: registry,
    abi: NGORegistryABI,
    functionName: 'getNGOInfo',
    args: selectedNGO ? [selectedNGO as `0x${string}`] : undefined,
    query: { enabled: !!selectedNGO },
  });

  // Writes: approve and deposit
  const { writeContract: writeApprove, data: approveHash, isPending: isApproving } = useWriteContract();
  const { writeContract: writeDeposit, data: depositHash, isPending: isDepositing } = useWriteContract();
  const { writeContract: writeWithdraw, data: withdrawHash, isPending: isWithdrawing } = useWriteContract();

  const { isLoading: approvingTxLoading, isSuccess: approveConfirmed } = useWaitForTransactionReceipt({ hash: approveHash });
  const { isLoading: depositingTxLoading } = useWaitForTransactionReceipt({ hash: depositHash });

  const decimals = 18; // WETH
  const amountBI = amount ? parseUnits(amount, decimals) : 0n;
  const unstakeAmountBI = unstakeAmount ? parseUnits(unstakeAmount, decimals) : 0n;
  const needsApproval = allowance !== undefined && amountBI > 0n && (allowance as bigint) < amountBI;

  const onMax = () => {
    const bal = balance ? formatUnits(balance as bigint, decimals) : '0';
    setAmount(bal);
  };

  const onApprove = () => {
    if (!amountBI || !address) return;
    writeApprove({
      address: weth,
      abi: erc20Abi,
      functionName: 'approve',
      args: [vault, amountBI],
    });
  };

  const onDeposit = () => {
    if (!amountBI || !address) return;
    writeDeposit({
      address: vault,
      abi: GiveVault4626ABI,
      functionName: 'deposit',
      args: [amountBI, address],
    });
  };

  const onUnstakeMax = () => {
    const ua = userAssets ? formatUnits(userAssets as bigint, decimals) : '0';
    setUnstakeAmount(ua);
  };

  const onWithdraw = () => {
    if (!unstakeAmountBI || !address) return;
    writeWithdraw({
      address: vault,
      abi: GiveVault4626ABI,
      functionName: 'withdraw',
      args: [unstakeAmountBI, address, address],
    });
  };

  useEffect(() => {
    if (approveConfirmed) {
      refetchAllowance();
      // proceed to deposit automatically
      onDeposit();
    }
  }, [approveConfirmed, refetchAllowance]);

  const isBusy = isApproving || isDepositing || approvingTxLoading || depositingTxLoading || isWithdrawing;

  const hasStake = (userAssets as bigint | undefined) && (userAssets as bigint) > 0n;

  useEffect(() => {
    if (!hasStake && mode === 'unstake') {
      setMode('stake');
    }
  }, [hasStake, mode]);

  useEffect(() => {
    if (!selectedNGO && allNGOs && Array.isArray(allNGOs) && allNGOs.length > 0) {
      // Select the first active NGO as default
      const firstActiveNGO = allNGOs.find((ngo: any) => ngo.isActive);
      if (firstActiveNGO) {
        setSelectedNGO(firstActiveNGO.ngoAddress as `0x${string}`);
      }
    }
  }, [allNGOs, selectedNGO]);

  return (
    <div className="max-w-3xl mx-auto space-y-6">
      {/* KPI cards */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <motion.div initial={{opacity:0, y:12}} animate={{opacity:1, y:0}} className="bg-white rounded-lg border p-4">
          <div className="text-sm text-gray-500">TVL</div>
          <div className="text-2xl font-semibold">{totalAssets ? formatUnits(totalAssets as bigint, decimals) : '0.00'} WETH</div>
        </motion.div>
        <motion.div initial={{opacity:0, y:12}} animate={{opacity:1, y:0}} transition={{delay:0.05}} className="bg-white rounded-lg border p-4">
          <div className="text-sm text-gray-500">APR (Aave)</div>
          <div className="text-2xl font-semibold">{aprPct ? `${aprPct}%` : '—'}</div>
        </motion.div>
        <motion.div initial={{opacity:0, y:12}} animate={{opacity:1, y:0}} transition={{delay:0.1}} className="bg-white rounded-lg border p-4">
          <div className="text-sm text-gray-500">My Stake</div>
          <div className="text-2xl font-semibold">{userAssets ? formatUnits(userAssets as bigint, decimals) : '0.00'} WETH</div>
        </motion.div>
      </div>

      {/* Stake/Unstake card */}
      <motion.div initial={{opacity:0, y:12}} animate={{opacity:1, y:0}} className="bg-white rounded-lg border p-6">
        {/* Simple mode toggles: hide Unstake if no position */}
        {hasStake ? (
          <div className="flex gap-2 mb-4">
            <button onClick={() => setMode('stake')} className={`px-4 py-2 rounded-lg ${mode==='stake' ? 'bg-brand-600 text-white' : 'bg-gray-100 text-gray-800'}`}>Stake</button>
            <button onClick={() => setMode('unstake')} className={`px-4 py-2 rounded-lg ${mode==='unstake' ? 'bg-brand-600 text-white' : 'bg-gray-100 text-gray-800'}`}>Unstake</button>
          </div>
        ) : null}

        {/* NGO selection (minimal) */}
        <div className="mb-3">
          <label className="block text-sm font-medium text-gray-700 mb-2">NGO</label>
          <select
            value={selectedNGO}
            onChange={(e) => setSelectedNGO(e.target.value as `0x${string}`)}
            className="w-full px-3 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-brand-500"
          >
            <option value="">Choose NGO…</option>
            {(allNGOs as any[] | undefined)?.map((ngo) => (
              <option key={ngo.ngoAddress} value={ngo.ngoAddress}>{ngo.name || `${ngo.ngoAddress.slice(0,6)}…${ngo.ngoAddress.slice(-4)}`}</option>
            ))}
          </select>
          <div className="text-xs text-gray-500 mt-2">Selected NGO: {selectedInfo ? (selectedInfo as any).name : '—'} · Donations: {donationStats ? `${(donationStats as any).totalDonations || 0}` : '—'}</div>
        </div>

        <div className="flex items-center justify-between mb-3">
          {mode === 'stake' ? (
            <>
              <h3 className="text-lg font-semibold">Stake WETH</h3>
              <div className="text-sm text-gray-500">Balance: {balance ? formatUnits(balance as bigint, decimals) : '0.00'} WETH</div>
            </>
          ) : (
            <>
              <h3 className="text-lg font-semibold">Unstake WETH</h3>
              <div className="text-sm text-gray-500">Available: {userAssets ? formatUnits(userAssets as bigint, decimals) : '0.00'} WETH</div>
            </>
          )}
        </div>
        {mode === 'stake' ? (
          <div className="flex gap-2">
            <input
              type="number"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              placeholder="0.0"
              className="flex-1 px-3 py-3 border rounded-lg focus:outline-none focus:ring-2 focus:ring-brand-500"
              min="0"
              step="0.01"
            />
            <button onClick={onMax} className="px-3 py-2 border rounded-lg text-sm hover:bg-gray-50">Max</button>
          </div>
        ) : (
          <div className="flex gap-2">
            <input
              type="number"
              value={unstakeAmount}
              onChange={(e) => setUnstakeAmount(e.target.value)}
              placeholder="0.0"
              className="flex-1 px-3 py-3 border rounded-lg focus:outline-none focus:ring-2 focus:ring-brand-500"
              min="0"
              step="0.01"
            />
            <button onClick={onUnstakeMax} className="px-3 py-2 border rounded-lg text-sm hover:bg-gray-50">Max</button>
          </div>
        )}

        {mode === 'stake' ? (
          <div className="mt-4">
            <button
              onClick={() => {
                if (!amount) return;
                if (needsApproval) onApprove(); else onDeposit();
              }}
              disabled={isBusy || !amount}
              className={`w-full px-4 py-3 rounded-lg text-white ${needsApproval ? 'bg-brand-600 hover:bg-brand-700' : 'bg-emerald-600 hover:bg-emerald-700'} disabled:opacity-60`}
            >
              {isApproving || approvingTxLoading
                ? 'Approving WETH…'
                : isDepositing || depositingTxLoading
                ? 'Staking…'
                : 'Stake WETH'}
            </button>
            {amount && (
              <div className="mt-2 text-xs text-gray-500">{needsApproval ? 'Approving then staking…' : 'Submitting stake…'}</div>
            )}
          </div>
        ) : (
          <div className="mt-4">
            <button
              onClick={onWithdraw}
              disabled={isBusy || !unstakeAmount}
              className="w-full px-4 py-3 rounded-lg text-white bg-rose-600 hover:bg-rose-700 disabled:opacity-60"
            >
              {isWithdrawing ? 'Unstaking…' : 'Unstake WETH'}
            </button>
          </div>
        )}

        {(approveHash || depositHash || withdrawHash) && (
          <div className="mt-4 text-sm text-gray-600">
            {approveHash && (
              <div>Approve tx: <a className="text-blue-600 underline" href={`https://sepolia.etherscan.io/tx/${approveHash}`} target="_blank" rel="noreferrer">{approveHash.slice(0, 10)}…</a></div>
            )}
            {depositHash && (
              <div>Deposit tx: <a className="text-blue-600 underline" href={`https://sepolia.etherscan.io/tx/${depositHash}`} target="_blank" rel="noreferrer">{depositHash.slice(0, 10)}…</a></div>
            )}
            {withdrawHash && (
              <div>Withdraw tx: <a className="text-blue-600 underline" href={`https://sepolia.etherscan.io/tx/${withdrawHash}`} target="_blank" rel="noreferrer">{withdrawHash.slice(0, 10)}…</a></div>
            )}
          </div>
        )}
      </motion.div>
    </div>
  );
}
