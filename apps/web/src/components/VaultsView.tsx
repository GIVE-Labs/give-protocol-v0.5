"use client";
import { useMemo } from "react";
import { useAccount, useChainId } from "wagmi";
import { ADDRESSES } from "../config/addresses";
import { VaultCard } from "./vault/VaultCard";

export function VaultsView() {
  const chainId = useChainId();
  const { address } = useAccount();
  const set = ADDRESSES[chainId] || {};

  const vaults = useMemo(() => {
    return [
      set.vault50 ? { address: set.vault50, label: "GIVE-50", splitBps: 5000 } : null,
      set.vault75 ? { address: set.vault75, label: "GIVE-75", splitBps: 7500 } : null,
      set.vault100 ? { address: set.vault100, label: "GIVE-100", splitBps: 10_000 } : null
    ].filter(Boolean) as { address: `0x${string}`; label: string; splitBps: number }[];
  }, [set]);

  if (!set.vault50 && !set.vault75 && !set.vault100) {
    return (
      <div className="card">
        <div className="stack">
          <h3>Unsupported Network</h3>
          <p className="muted">Switch to Anvil, Base Sepolia, or Base Mainnet. Configure addresses in .env.local.</p>
        </div>
      </div>
    );
  }

  return (
    <div className="grid">
      {vaults.map((v) => (
        <div className="card half" key={v.address}>
          <VaultCard vaultAddress={v.address} label={v.label} />
        </div>
      ))}
    </div>
  );
}

