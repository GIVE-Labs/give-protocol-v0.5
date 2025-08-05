import { TrendingUp, Users, Heart, DollarSign } from 'lucide-react'

interface DashboardStatsProps {
  totalStaked: string
  totalYield: string
  activeNGOs: number
  totalDonated: string
}

export default function DashboardStats({ totalStaked, totalYield, activeNGOs, totalDonated }: DashboardStatsProps) {
  const stats = [
    {
      name: 'Total Staked',
      value: totalStaked,
      icon: DollarSign,
      color: 'text-blue-600',
      bgColor: 'bg-blue-50'
    },
    {
      name: 'Total Yield Generated',
      value: totalYield,
      icon: TrendingUp,
      color: 'text-green-600',
      bgColor: 'bg-green-50'
    },
    {
      name: 'Active NGOs',
      value: activeNGOs.toString(),
      icon: Users,
      color: 'text-purple-600',
      bgColor: 'bg-purple-50'
    },
    {
      name: 'Total Donated',
      value: totalDonated,
      icon: Heart,
      color: 'text-red-600',
      bgColor: 'bg-red-50'
    }
  ]

  return (
    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
      {stats.map((stat) => (
        <div key={stat.name} className="bg-white rounded-lg shadow-md p-6">
          <div className="flex items-center">
            <div className={`p-3 rounded-lg ${stat.bgColor}`}>
              <stat.icon className={`w-6 h-6 ${stat.color}`} />
            </div>
            <div className="ml-4">
              <p className="text-sm font-medium text-gray-600">{stat.name}</p>
              <p className="text-2xl font-bold text-gray-900">{stat.value}</p>
            </div>
          </div>
        </div>
      ))}
    </div>
  )
}