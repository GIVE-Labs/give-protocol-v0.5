"use client";
import "./globals.css";
import { ReactNode } from "react";
import { RainbowKitProvider, getDefaultConfig, darkTheme } from "@rainbow-me/rainbowkit";
import "@rainbow-me/rainbowkit/styles.css";
import { WagmiProvider, http } from "wagmi";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { base, baseSepolia } from "viem/chains";
import { createConfig } from "wagmi";
import { anvil } from "../src/config/chains";

const projectId = process.env.NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID || "";

const config = createConfig(
  getDefaultConfig({
    appName: "GIVE Protocol",
    projectId,
    chains: [anvil, baseSepolia, base],
    transports: {
      [anvil.id]: http(process.env.NEXT_PUBLIC_ANVIL_RPC || "http://127.0.0.1:8545"),
      [baseSepolia.id]: http(process.env.NEXT_PUBLIC_BASE_SEPOLIA_RPC || "https://sepolia.base.org"),
      [base.id]: http(process.env.NEXT_PUBLIC_BASE_MAINNET_RPC || "https://mainnet.base.org")
    },
    ssr: true
  })
);

const qc = new QueryClient();

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en">
      <body>
        <WagmiProvider config={config}>
          <QueryClientProvider client={qc}>
            <RainbowKitProvider theme={darkTheme({ accentColor: "#5cd3ff" })}>{children}</RainbowKitProvider>
          </QueryClientProvider>
        </WagmiProvider>
      </body>
    </html>
  );
}

