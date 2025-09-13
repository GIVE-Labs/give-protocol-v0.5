import { Link } from 'react-router-dom'
import { ArrowRight, Heart } from 'lucide-react'

export default function Footer() {
  return (
    <footer className="bg-gradient-to-br from-gray-900 via-slate-800 to-gray-900 relative overflow-hidden">
      {/* Background Effects */}
      <div className="absolute inset-0 bg-gradient-to-r from-emerald-900/20 via-cyan-900/20 to-teal-900/20"></div>
      <div className="absolute top-0 left-1/4 w-96 h-96 bg-emerald-500/10 rounded-full blur-3xl"></div>
      <div className="absolute bottom-0 right-1/4 w-96 h-96 bg-cyan-500/10 rounded-full blur-3xl"></div>
      
      <div className="container mx-auto px-4 relative z-10 py-16">
        <div className="grid grid-cols-1 md:grid-cols-4 gap-12">
          <div className="space-y-5">
            <div className="flex items-center space-x-3">
              <div className="w-8 h-8 bg-gradient-to-r from-emerald-500 to-cyan-500 rounded-xl flex items-center justify-center flex-shrink-0">
                <Heart className="w-5 h-5 text-white" />
              </div>
              <h3 className="text-xl font-bold bg-gradient-to-r from-emerald-400 to-cyan-400 bg-clip-text text-transparent font-unbounded">
                GIVE Protocol
              </h3>
            </div>
            <p className="text-gray-300 leading-relaxed text-lg">
              Revolutionizing charitable <br /> giving through DeFi innovation. Make impact without losing <br/>your principal.
            </p>
          </div>
          
          <div className="space-y-6">
            <h4 className="text-xl font-bold text-emerald-400 font-unbounded">Product</h4>
            <ul className="space-y-3">
              {[
                { name: "Stake", to: "/stake" },
                { name: "NGOs", to: "/ngos" },
                { name: "Dashboard", to: "/dashboard" }
              ].map((item) => (
                <li key={item.name}>
                  <Link 
                    to={item.to} 
                    className="text-gray-300 hover:text-emerald-400 transition-colors duration-300 text-lg group flex items-center space-x-2 "
                  >
                    <span>{item.name}</span>
                    <ArrowRight className="w-4 h-4 opacity-0 group-hover:opacity-100 group-hover:translate-x-1 transition-all duration-300" />
                  </Link>
                </li>
              ))}
            </ul>
          </div>
          
          <div className="space-y-6">
            <h4 className="text-xl font-bold text-cyan-400 font-unbounded">Resources</h4>
            <ul className="space-y-3">
              {[
                "Documentation",
                "Whitepaper",
                "Blog",
                "Security Audit"
              ].map((item) => (
                <li key={item}>
                  <a 
                    href="#" 
                    className="text-gray-300 hover:text-cyan-400 transition-colors duration-300 text-lg group flex items-center space-x-2 "
                  >
                    <span>{item}</span>
                    <ArrowRight className="w-4 h-4 opacity-0 group-hover:opacity-100 group-hover:translate-x-1 transition-all duration-300" />
                  </a>
                </li>
              ))}
            </ul>
          </div>
          
          <div className="space-y-6">
            <h4 className="text-xl font-bold text-teal-400 font-unbounded">Community</h4>
            <ul className="space-y-3">
              {[
                "Discord",
                "Twitter",
                "GitHub",
                "Newsletter"
              ].map((item) => (
                <li key={item}>
                  <a 
                    href="#" 
                    className="text-gray-300 hover:text-teal-400 transition-colors duration-300 text-lg group flex items-center space-x-2 "
                  >
                    <span>{item}</span>
                    <ArrowRight className="w-4 h-4 opacity-0 group-hover:opacity-100 group-hover:translate-x-1 transition-all duration-300" />
                  </a>
                </li>
              ))}
            </ul>
          </div>
        </div>
        
        <div className="border-t border-gradient-to-r from-emerald-800/30 via-cyan-800/30 to-teal-800/30 mt-16 pt-8">
          <div className="flex flex-col md:flex-row justify-between items-center space-y-4 md:space-y-0">
            <p className="text-gray-400 text-lg ">
              &copy; 2025 Give Protocol. All rights reserved.
            </p>
            <div className="flex items-center space-x-2 text-gray-400 ">
              <span>Built with</span>
              <span className="text-red-400 text-xl">❤️</span>
              <span>for a better world</span>
            </div>
          </div>
        </div>
      </div>
    </footer>
  )
}