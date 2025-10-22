"use client";
import { formatUnits, parseUnits } from "viem";
import { useEffect, useMemo, useState } from "react";
import { useAccount, useBalance, useReadContract, useReadContracts, useWriteContract, useWaitForTransactionReceipt } from "wagmi";
import { SimpleVault4626UpgradeableAbi, ERC20Abi } from "../../contracts/abis/SimpleVault4626Upgradeable";

type Props = { vaultAddress: `0x${string}`; label: string };

export function VaultCard({ vaultAddress, label }: Props) {
  const { address } = useAccount();
  const [amount, setAmount] = useState("");
  const [mode, setMode] = useState<"deposit" | "withdraw">("deposit");

  const { data: vaultInfo } = useReadContracts({
    contracts: [
      { address: vaultAddress, abi: SimpleVault4626UpgradeableAbi, functionName: "name" },
      { address: vaultAddress, abi: SimpleVault4626UpgradeableAbi, functionName: "symbol" },
      { address: vaultAddress, abi: SimpleVault4626UpgradeableAbi, functionName: "decimals" },
      { address: vaultAddress, abi: SimpleVault4626UpgradeableAbi, functionName: "asset" },
      { address: vaultAddress, abi: SimpleVault4626UpgradeableAbi, functionName: "donationPercentBps" },
      { address: vaultAddress, abi: SimpleVault4626UpgradeableAbi, functionName: "protocolFeeBps" },
      { address: vaultAddress, abi: SimpleVault4626UpgradeableAbi, functionName: "totalAssets" },
      { address: vaultAddress, abi: SimpleVault4626UpgradeableAbi, functionName: "totalSupply" },
      { address: vaultAddress, abi: SimpleVault4626UpgradeableAbi, functionName: "currentNGO" },
      { address: vaultAddress, abi: SimpleVault4626UpgradeableAbi, functionName: "maxDeposit", args: [address || "0x0000000000000000000000000000000000000000"] }
    ],
    allowFailure: false
  });

  const [name, symbol, shareDecimals, assetAddress, donationBps, feeBps, totalAssets, totalSupply, currentNGO, maxDeposit] =
    (vaultInfo || ["", "", 18, "0x0000000000000000000000000000000000000000", 0, 0, 0n, 0n, "0x0000000000000000000000000000000000000000", 0n]) as [
      string,
      string,
      number,
      `0x${string}`,
      number,
      number,
      bigint,
      bigint,
      `0x${string}`,
      bigint
    ];

  const { data: assetInfo } = useReadContracts({
    contracts: [
      { address: assetAddress, abi: ERC20Abi, functionName: "symbol" },
      { address: assetAddress, abi: ERC20Abi, functionName: "decimals" },
      { address: assetAddress, abi: ERC20Abi, functionName: "balanceOf", args: [address || "0x0000000000000000000000000000000000000000"] },
      { address: assetAddress, abi: ERC20Abi, functionName: "allowance", args: [address || "0x0000000000000000000000000000000000000000", vaultAddress] }
    ],
    query: { enabled: assetAddress !== "0x0000000000000000000000000000000000000000" },
    allowFailure: false
  });

  const [assetSymbol, assetDecimals, walletAssetBal, allowance] =
    (assetInfo || ["", 18, 0n, 0n]) as [string, number, bigint, bigint];

  const userShares = useReadContract({
    address: vaultAddress,
    abi: SimpleVault4626UpgradeableAbi,
    functionName: "balanceOf",
    args: [address || "0x0000000000000000000000000000000000000000"]
  });

  const parsed = useMemo(() => {
    const clean = amount.trim();
    if (!clean) return 0n;
    try {
      return parseUnits(clean, assetDecimals ?? 18);
    } catch {
      return 0n;
    }
  }, [amount, assetDecimals]);

  const needsApproval = mode === "deposit" && parsed > (allowance || 0n);

  const { writeContract, data: hash, isPending } = useWriteContract();
  const receipt = useWaitForTransactionReceipt({ hash });

  const sharePrice = useMemo(() => {
    if (!totalSupply || totalSupply === 0n) return 1;
    return Number(totalAssets) / Number(totalSupply);
  }, [totalAssets, totalSupply]);

  function onApprove() {
    if (!parsed || parsed <= 0n) return;
    writeContract({ address: assetAddress, abi: ERC20Abi, functionName: "approve", args: [vaultAddress, parsed] });
  }

  function onDeposit() {
    if (!parsed || parsed <= 0n) return;
    writeContract({ address: vaultAddress, abi: SimpleVault4626UpgradeableAbi, functionName: "deposit", args: [parsed, address!] });
  }

  function onWithdraw() {
    if (!parsed || parsed <= 0n) return;
    writeContract({ address: vaultAddress, abi: SimpleVault4626UpgradeableAbi, functionName: "withdraw", args: [parsed, address!, address!] });
  }

  function onHarvest() {
    writeContract({ address: vaultAddress, abi: SimpleVault4626UpgradeableAbi, functionName: "harvest", args: [currentNGO] });
  }

  return (
    <div className="stack" style={{ gap: 12 }}>
      <div className="row" style={{ justifyContent: "space-between" }}>
        <div className="stack">
          <strong>{label}</strong>
          <span className="muted" style={{ fontSize: 13 }}>{name || "Vault"} · Token: {symbol}</span>
        </div>
        <span className="tag">Donation split: {donationBps / 100}% · Fee: {feeBps / 100}%</span>
      </div>

      <div className="grid">
        <div className="card">
          <div className="row" style={{ justifyContent: "space-between" }}>
            <div className="stack">
              <span className="muted">TVL</span>
              <strong>{formatUnits(totalAssets || 0n, assetDecimals || 18)} {assetSymbol}</strong>
            </div>
            <div className="stack">
              <span className="muted">Share Price</span>
              <strong>{sharePrice.toFixed(6)} {assetSymbol} / share</strong>
            </div>
            <div className="stack">
              <span className="muted">Your Shares</span>
              <strong>{formatUnits((userShares.data as bigint) || 0n, shareDecimals || 18)}</strong>
            </div>
            <div className="stack">
              <span className="muted">Current NGO</span>
              <strong>{currentNGO === "0x0000000000000000000000000000000000000000" ? "—" : `${currentNGO.slice(0,6)}…${currentNGO.slice(-4)}`}</strong>
            </div>
          </div>
        </div>
      </div>

      <div className="row" style={{ gap: 8 }}>
        <button className={`btn ${mode === "deposit" ? "primary" : ""}`} onClick={() => setMode("deposit")}>Deposit</button>
        <button className={`btn ${mode === "withdraw" ? "primary" : ""}`} onClick={() => setMode("withdraw")}>Withdraw</button>
        <div style={{ flex: 1 }} />
        <button className="btn" onClick={onHarvest} disabled={!currentNGO || currentNGO === "0x0000000000000000000000000000000000000000" || isPending}>Harvest</button>
      </div>

      <div className="row" style={{ gap: 12 }}>
        <input className="input" value={amount} onChange={(e) => setAmount(e.target.value)} placeholder={`Amount (${assetSymbol})`} />
        {mode === "deposit" && (
          <button className="btn" onClick={() => setAmount(formatUnits(walletAssetBal || 0n, assetDecimals || 18))}>Max</button>
        )}
        {mode === "withdraw" && (
          <button className="btn" onClick={() => setAmount(formatUnits((userShares.data as bigint) || 0n, shareDecimals || 18))}>Max</button>
        )}
        {mode === "deposit" ? (
          needsApproval ? (
            <button className="btn primary" onClick={onApprove} disabled={isPending || parsed === 0n}>Approve</button>
          ) : (
            <button className="btn primary" onClick={onDeposit} disabled={isPending || parsed === 0n || parsed > (maxDeposit || 0n)}>Deposit</button>
          )
        ) : (
          <button className="btn primary" onClick={onWithdraw} disabled={isPending || parsed === 0n}>Withdraw</button>
        )}
      </div>

      {hash && (
        <div className="muted">Submitted: {hash.slice(0, 10)}…</div>
      )}
      {receipt.isSuccess && <div className="muted">Tx confirmed in block {receipt.data?.blockNumber?.toString()}</div>}
      {receipt.isError && <div className="muted">Tx failed</div>}
    </div>
  );
}

