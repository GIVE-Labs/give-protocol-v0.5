"use client";
import { ConnectButton } from "@rainbow-me/rainbowkit";
import { useAccount, useChainId } from "wagmi";
import { VaultsView } from "../src/components/VaultsView";

export default function Page() {
  const { isConnected } = useAccount();
  const chainId = useChainId();
  return (
    <div className="container">
      <header className="header">
        <div className="row">
          <h2>GIVE Protocol</h2>
          <span className="tag">No-loss Donations · ERC-4626</span>
        </div>
        <ConnectButton />
      </header>
      <VaultsView />
    </div>
  );
}

