import { ConnectButton } from '@rainbow-me/rainbowkit'
import { Link, useLocation } from 'react-router-dom'
import { Heart, Menu } from 'lucide-react'
import { useMemo, useState } from 'react'
import { useAccount, useReadContract } from 'wagmi'
import { CONTRACT_ADDRESSES } from '../../config/contracts'
import NGORegistryABI from '../../abis/NGORegistry.json'
import { keccak256, toBytes } from 'viem'

export default function Header() {
  const location = useLocation()
  const [isMenuOpen, setIsMenuOpen] = useState(false)
  const { address } = useAccount()
  const NGO_MANAGER_ROLE = useMemo(() => keccak256(toBytes('NGO_MANAGER_ROLE')) as `0x${string}` , [])
  const { data: isManager } = useReadContract({
    address: CONTRACT_ADDRESSES.NGO_REGISTRY as `0x${string}`,
    abi: NGORegistryABI,
    functionName: 'hasRole',
    args: address ? [NGO_MANAGER_ROLE, address] : undefined,
    query: { enabled: !!address },
  })

  const navItems = [
    { path: '/', label: 'Home' },
    { path: '/ngo', label: 'NGOs' },
    { path: '/dashboard', label: 'Dashboard' },
  ]

  return (
    <header className="bg-white shadow-sm border-b">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex justify-between items-center h-16">
          <div className="flex items-center">
            <Link to="/" className="flex items-center space-x-2">
              <Heart className="h-8 w-8 text-brand-600" />
              <span className="text-xl font-bold text-gradient">GIVE Protocol</span>
            </Link>
          </div>

          <nav className="hidden md:flex space-x-8">
            {navItems.map((item) => (
              <Link
                key={item.path}
                to={item.path}
                className={`text-sm font-medium transition-colors ${
                  location.pathname === item.path
                    ? 'text-brand-600'
                    : 'text-gray-700 hover:text-brand-600'
                }`}
              >
                {item.label}
              </Link>
            ))}
          </nav>

          <div className="flex items-center space-x-4">
            {/* {Boolean(isManager) && (
              <Link
                to="/create-campaign"
                className="hidden sm:inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-brand-600 hover:bg-brand-700"
              >
                Register Camapign
              </Link>
            )} */}
            <ConnectButton
              accountStatus={{
                smallScreen: 'avatar',
                largeScreen: 'full',
              }}
              showBalance={{
                smallScreen: false,
                largeScreen: true,
              }}
              chainStatus={{
                smallScreen: 'none',
                largeScreen: 'icon',
              }}
              label="Connect Wallet"
            />
            <button
              className="md:hidden"
              onClick={() => setIsMenuOpen(!isMenuOpen)}
            >
              <Menu className="h-6 w-6" />
            </button>
          </div>
        </div>

        {isMenuOpen && (
          <div className="md:hidden">
            <div className="px-2 pt-2 pb-3 space-y-1 sm:px-3">
              {navItems.map((item) => (
                <Link
                  key={item.path}
                  to={item.path}
                  className={`block px-3 py-2 text-base font-medium rounded-md ${
                    location.pathname === item.path
                    ? 'text-brand-600 bg-brand-50'
                    : 'text-gray-700 hover:text-brand-600 hover:bg-gray-50'
                  }`}
                  onClick={() => setIsMenuOpen(false)}
                >
                  {item.label}
                </Link>
              ))}
              {Boolean(isManager) && (
                <Link
                  to="/create-ngo"
                  className="block px-3 py-2 text-base font-medium rounded-md text-brand-600 hover:bg-gray-50"
                  onClick={() => setIsMenuOpen(false)}
                >
                  Register NGO
                </Link>
              )}
            </div>
          </div>
        )}
      </div>
    </header>
  )
}
