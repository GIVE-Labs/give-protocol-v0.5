/**
 * VaultStats Component
 * Display vault TVL, share price, and asset allocation
 * Design: Preserves existing cyan/emerald gradient theme
 */

import { motion } from 'framer-motion';
import { TrendingUp, Wallet, PieChart, Coins } from 'lucide-react';
import { useGiveVault } from '../../hooks/v05';

interface VaultStatsProps {
  vaultAddress?: `0x${string}`;
}

export default function VaultStats({ vaultAddress }: VaultStatsProps) {
  const {
    totalAssets,
    adapterAssets,
    cashBalance,
    sharePrice,
  } = useGiveVault(vaultAddress);

  const stats = [
    {
      label: 'Total Value Locked',
      value: `${totalAssets} WETH`,
      icon: Wallet,
      color: 'from-emerald-500 to-teal-500',
      bgColor: 'from-emerald-50 to-teal-50',
    },
    {
      label: 'Share Price',
      value: `${parseFloat(sharePrice).toFixed(4)} WETH`,
      icon: TrendingUp,
      color: 'from-cyan-500 to-blue-500',
      bgColor: 'from-cyan-50 to-blue-50',
    },
    {
      label: 'In Yield Adapter',
      value: `${adapterAssets} WETH`,
      icon: PieChart,
      color: 'from-teal-500 to-emerald-500',
      bgColor: 'from-teal-50 to-emerald-50',
    },
    {
      label: 'Cash Buffer',
      value: `${cashBalance} WETH`,
      icon: Coins,
      color: 'from-emerald-500 to-cyan-500',
      bgColor: 'from-emerald-50 to-cyan-50',
    },
  ];

  const containerVariants = {
    hidden: { opacity: 0 },
    visible: {
      opacity: 1,
      transition: {
        staggerChildren: 0.1,
      }
    }
  };

  const itemVariants = {
    hidden: { opacity: 0, y: 20 },
    visible: {
      opacity: 1,
      y: 0,
      transition: {
        duration: 0.5,
        ease: "easeOut"
      }
    }
  };

  return (
    <motion.div
      className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6"
      variants={containerVariants}
      initial="hidden"
      animate="visible"
    >
      {stats.map((stat, index) => {
        const Icon = stat.icon;
        return (
          <motion.div
            key={stat.label}
            variants={itemVariants}
            whileHover={{ y: -5, scale: 1.02 }}
            className="group"
          >
            <div className={`relative bg-gradient-to-br ${stat.bgColor} rounded-2xl p-6 shadow-lg hover:shadow-2xl transition-all duration-500 border border-white/50 backdrop-blur-sm`}>
              {/* Icon */}
              <motion.div
                className={`w-12 h-12 bg-gradient-to-r ${stat.color} rounded-xl flex items-center justify-center mb-4 shadow-md`}
                whileHover={{ rotate: 5, scale: 1.1 }}
                transition={{ type: "spring", stiffness: 300 }}
              >
                <Icon className="w-6 h-6 text-white" />
              </motion.div>

              {/* Label */}
              <p className="text-sm font-medium text-gray-600 mb-2">{stat.label}</p>

              {/* Value */}
              <p className="text-2xl font-bold text-gray-900 group-hover:text-gray-800 transition-colors">
                {stat.value}
              </p>

              {/* Decorative element */}
              <motion.div
                className={`absolute bottom-0 right-0 w-16 h-16 bg-gradient-to-r ${stat.color} opacity-10 rounded-tl-full`}
                animate={{
                  scale: [1, 1.2, 1],
                }}
                transition={{
                  duration: 3,
                  repeat: Infinity,
                  delay: index * 0.2
                }}
              />
            </div>
          </motion.div>
        );
      })}
    </motion.div>
  );
}
