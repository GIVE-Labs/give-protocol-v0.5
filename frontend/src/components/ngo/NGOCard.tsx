import { NGO } from '../../types'
import { Link } from 'react-router-dom'

interface NGOCardProps {
  ngo: NGO
}

export const NGOCard: React.FC<NGOCardProps> = ({ ngo }) => {
  const formatYield = (yieldAmount: bigint) => {
    return Number(yieldAmount).toLocaleString()
  }

  return (
    <div className="bg-white rounded-xl shadow-lg overflow-hidden hover:shadow-xl transition-shadow duration-300">
      <div className="h-48 bg-gradient-to-br from-purple-500 to-pink-500 flex items-center justify-center">
        <img 
          src={ngo.logoURI} 
          alt={ngo.name}
          className="w-24 h-24 rounded-full object-cover border-4 border-white"
        />
      </div>
      
      <div className="p-6">
        <div className="flex items-center justify-between mb-2">
          <h3 className="text-xl font-bold text-gray-900">{ngo.name}</h3>
          {ngo.isVerified && (
            <span className="bg-green-100 text-green-800 text-xs font-semibold px-2 py-1 rounded-full">
              Verified
            </span>
          )}
        </div>
        
        <p className="text-gray-600 mb-4 line-clamp-2">{ngo.description}</p>
        
        <div className="flex flex-wrap gap-2 mb-4">
          {ngo.causes.slice(0, 3).map((cause) => (
            <span 
              key={cause}
              className="bg-purple-100 text-purple-800 text-xs px-2 py-1 rounded-full"
            >
              {cause}
            </span>
          ))}
        </div>
        
        <div className="grid grid-cols-2 gap-4 mb-4 text-sm">
          <div>
            <span className="text-gray-500">Total Stakers</span>
            <p className="font-bold text-gray-900">{Number(ngo.totalStakers)}</p>
          </div>
          <div>
            <span className="text-gray-500">Yield Received</span>
            <p className="font-bold text-green-600">${formatYield(ngo.totalYieldReceived)}</p>
          </div>
        </div>
        
        <Link 
          to={`/ngo/${ngo.ngoAddress}`}
          className="block w-full text-center bg-purple-600 text-white py-2 px-4 rounded-lg hover:bg-purple-700 transition-colors duration-200"
        >
          View Details
        </Link>
      </div>
    </div>
  )
}