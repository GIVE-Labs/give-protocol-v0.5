# Frontend Application - GIVE Protocol

## 🎨 Frontend Overview

The GIVE Protocol frontend is a modern React application built with Vite, providing users with an intuitive interface for no-loss giving through yield-generating vaults.

## 🛠️ Technology Stack

### **Core Framework**:
- **React 18.3.1** - UI library with hooks and modern features
- **Vite 5.3.4** - Fast build tool and development server
- **TypeScript 5.2.2** - Type safety and developer experience

### **Web3 Integration**:
- **wagmi 2.12.0** - React hooks for Ethereum
- **RainbowKit 2.1.6** - Wallet connection interface
- **viem 2.17.5** - TypeScript Ethereum library
- **Tanstack Query 5.51.11** - Data fetching and caching

### **UI & Styling**:
- **TailwindCSS 3.4.7** - Utility-first CSS framework
- **Framer Motion 11.18.2** - Animation library
- **Lucide React 0.417.0** - Icon library
- **Lottie React 0.16.1** - Animation assets

### **Development Tools**:
- **ESLint 9.7.0** - Code linting
- **TypeScript ESLint 7.17.0** - TypeScript-specific linting
- **PostCSS 8.4.40** - CSS processing
- **Autoprefixer 10.4.19** - CSS vendor prefixes

## 📁 Project Structure

```
frontend/
├── src/
│   ├── components/          # Reusable UI components
│   │   ├── ui/             # Basic UI elements (buttons, inputs)
│   │   ├── layout/         # Layout components (header, footer)
│   │   ├── ngo/            # NGO-specific components
│   │   ├── portfolio/      # Portfolio/dashboard components
│   │   └── staking/        # Staking-related components
│   ├── pages/              # Route components
│   ├── hooks/              # Custom React hooks
│   ├── config/             # Configuration files
│   ├── services/           # External service integrations
│   ├── types/              # TypeScript type definitions
│   ├── data/               # Mock data and constants
│   ├── assets/             # Static assets (images, tokens)
│   └── abis/               # Smart contract ABIs
├── public/                 # Static public assets
├── dist/                   # Build output
└── package.json            # Dependencies and scripts
```

## 🧩 Core Components

### **Layout Components**

#### **Header.tsx**
**Location**: `src/components/layout/Header.tsx`

Main navigation header with wallet connection and routing.

**Features**:
- Responsive navigation menu
- Wallet connection button (RainbowKit)
- Network status indicator
- Active route highlighting

#### **Footer.tsx**
**Location**: `src/components/Footer.tsx`

Site footer with links and project information.

### **UI Components**

#### **Button.tsx**
**Location**: `src/components/ui/Button.tsx`

Reusable button component with variants and states.

```tsx
interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'secondary' | 'outline' | 'ghost';
  size?: 'sm' | 'md' | 'lg';
  loading?: boolean;
  children: React.ReactNode;
}
```

### **NGO Components**

#### **NGOCard.tsx**
**Location**: `src/components/ngo/NGOCard.tsx`

Display component for NGO information cards.

**Features**:
- NGO metadata display (name, description, images)
- Donation statistics
- Call-to-action buttons
- Responsive design

#### **FeaturedNGO.tsx**
**Location**: `src/components/FeaturedNGO.tsx`

Highlighted NGO showcase component for homepage.

### **Portfolio Components**

#### **DashboardStats.tsx**
**Location**: `src/components/portfolio/DashboardStats.tsx`

User portfolio statistics and metrics.

**Features**:
- Total staked amount
- Yield generated
- Active positions
- Historical performance

#### **PortfolioCard.tsx**
**Location**: `src/components/portfolio/PortfolioCard.tsx`

Individual vault position display.

## 📄 Page Components

### **Home.tsx**
**Location**: `src/pages/Home.tsx`

Landing page with project overview and featured content.

**Features**:
- Hero section with animated elements
- Value proposition explanation
- Featured NGO showcase
- Call-to-action sections
- Responsive design with Framer Motion animations

### **CampaignStaking.tsx**
**Location**: `src/pages/CampaignStaking.tsx`

Main staking interface for vault interactions.

**Key Features**:
- Token selection (USDC, ETH, WETH)
- Stake amount input with validation
- Lock period selection (6, 12, 24 months)
- Yield sharing ratio (50%, 75%, 100%)
- Real-time balance checking
- Transaction status handling
- Responsive design

**Core Functionality**:
```tsx
// Staking form state
const [stakeAmount, setStakeAmount] = useState('0');
const [lockPeriod, setLockPeriod] = useState<number>(12);
const [yieldSharingRatio, setYieldSharingRatio] = useState<number>(75);
const [selectedToken, setSelectedToken] = useState<string>(tokens[0].address);

// Web3 hooks
const { address, isConnected } = useAccount();
const { writeContract } = useWriteContract();

// Smart contract interactions
const handleStake = async () => {
  // Approval and deposit logic
};
```

### **Dashboard.tsx**
**Location**: `src/pages/Dashboard.tsx`

User portfolio management interface.

**Features**:
- Portfolio overview
- Active positions
- Yield tracking
- Transaction history
- Withdrawal interface

### **NGOs.tsx**
**Location**: `src/pages/NGOs.tsx`

NGO directory and selection interface.

**Features**:
- NGO grid display
- Search and filtering
- Detailed NGO information
- Selection for staking

### **NGODetails.tsx**
**Location**: `src/pages/NGODetails.tsx`

Detailed NGO information page.

**Features**:
- Comprehensive NGO profile
- Donation statistics
- Image gallery
- Verification status
- Direct staking interface

### **CreateNGO.tsx**
**Location**: `src/pages/CreateNGO.tsx`

NGO registration interface for new organizations.

**Features**:
- Multi-step form
- IPFS metadata upload
- KYC information collection
- Form validation

## ⚙️ Configuration

### **Web3 Configuration**
**Location**: `src/config/web3.ts`

```tsx
import { getDefaultConfig } from '@rainbow-me/rainbowkit';
import { scroll, scrollSepolia } from 'wagmi/chains';

export const config = getDefaultConfig({
  appName: 'GIVE Protocol',
  projectId: 'YOUR_PROJECT_ID',
  chains: [scrollSepolia, scroll],
  ssr: false,
});
```

### **Contract Configuration**
**Location**: `src/config/contracts.ts`

Environment-based contract addresses and network configuration.

```tsx
export const NETWORK_CONFIG = {
  LOCAL: {
    chainId: 31337,
    name: 'Anvil Local',
    contracts: LOCAL_CONTRACT_ADDRESSES
  },
  SEPOLIA: {
    chainId: 11155111,
    name: 'Sepolia Testnet',
    contracts: SEPOLIA_CONTRACT_ADDRESSES
  }
};

// Environment-based selection
export const CONTRACT_ADDRESSES = isDevelopment 
  ? LOCAL_CONTRACT_ADDRESSES 
  : SEPOLIA_CONTRACT_ADDRESSES;
```

## 🎣 Custom Hooks

### **useContracts.ts**
**Location**: `src/hooks/useContracts.ts`

Centralized contract interaction hooks.

```tsx
export function useContracts() {
  const { data: ngoInfo } = useReadContract({
    address: NGO_REGISTRY,
    abi: NGORegistryABI,
    functionName: 'ngoInfo',
    args: [ngoAddress],
  });

  const { writeContract: depositToVault } = useWriteContract();

  return {
    ngoInfo,
    depositToVault,
    // ... other contract functions
  };
}
```

### **useNGORegistryWagmi.ts**
**Location**: `src/hooks/useNGORegistryWagmi.ts`

NGO Registry specific interactions.

```tsx
export function useNGORegistry() {
  const { data: currentNGO } = useReadContract({
    address: NGO_REGISTRY,
    abi: NGORegistryABI,
    functionName: 'currentNGO',
  });

  const { data: isApproved } = useReadContract({
    address: NGO_REGISTRY,
    abi: NGORegistryABI,
    functionName: 'isApproved',
    args: [ngoAddress],
  });

  return { currentNGO, isApproved };
}
```

## 📡 Services

### **IPFS Service**
**Location**: `src/services/ipfs.ts`

IPFS integration for metadata storage and retrieval.

```tsx
export interface NGOMetadata {
  name: string;
  description: string;
  images: string[];
  website?: string;
  contact?: string;
  verification?: {
    kycProvider: string;
    attestationId: string;
  };
}

export async function fetchMetadataFromIPFS(cid: string): Promise<NGOMetadata> {
  const response = await fetch(`https://gateway.pinata.cloud/ipfs/${cid}`);
  return response.json();
}

export async function uploadMetadataToIPFS(metadata: NGOMetadata): Promise<string> {
  // Pinata integration for uploading
}
```

## 🎨 Styling & Design System

### **TailwindCSS Configuration**
**Location**: `tailwind.config.js`

```js
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        primary: {
          50: '#ecfdf5',
          500: '#10b981',
          900: '#064e3b',
        },
      },
      fontFamily: {
        'unbounded': ['Unbounded', 'sans-serif'],
      },
    },
  },
  plugins: [],
}
```

### **Design Tokens**
- **Primary Colors**: Emerald/Green theme for financial growth
- **Secondary Colors**: Cyan/Teal for technology feel
- **Typography**: Clean, modern fonts with good readability
- **Spacing**: Consistent 4px grid system
- **Animations**: Smooth transitions with Framer Motion

## 📱 Responsive Design

The application is fully responsive with breakpoints:
- **Mobile**: < 640px
- **Tablet**: 640px - 1024px
- **Desktop**: > 1024px

Key responsive features:
- Adaptive navigation menu
- Flexible grid layouts
- Touch-friendly interaction areas
- Optimized content hierarchy

## 🔧 Development Scripts

```json
{
  "scripts": {
    "dev": "vite",
    "build": "tsc -b && vite build",
    "lint": "eslint .",
    "preview": "vite preview",
    "sync-abis": "cd ../backend && forge inspect ... > ../frontend/src/abis/...",
    "build:contracts": "cd ../backend && forge build && pnpm sync-abis"
  }
}
```

## 🔄 State Management

### **React Query Integration**
- Automatic caching of blockchain data
- Background refetching
- Optimistic updates
- Error handling

### **Wagmi State Management**
- Wallet connection state
- Network switching
- Transaction status
- Contract call results

## 🧪 Testing Strategy

### **Component Testing**
- Unit tests for individual components
- Integration tests for user flows
- Mock Web3 providers for testing

### **E2E Testing**
- Complete user journeys
- Cross-browser testing
- Mobile responsiveness testing

---

*This frontend documentation provides comprehensive guidance for developers working on the GIVE Protocol user interface.*