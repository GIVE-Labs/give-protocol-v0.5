import { Link } from 'react-router-dom'
import { DotLottieReact } from '@lottiefiles/dotlottie-react'
import { ArrowRight, Heart, Sparkles, Zap, Globe } from 'lucide-react'
import { motion } from 'framer-motion'

export default function Home() {
  const containerVariants = {
    hidden: { opacity: 0 },
    visible: {
      opacity: 1,
      transition: {
        staggerChildren: 0.2,
        delayChildren: 0.1
      }
    }
  }

  const itemVariants = {
    hidden: { opacity: 0, y: 30 },
    visible: {
      opacity: 1,
      y: 0,
      transition: {
        duration: 0.6,
        ease: "easeOut"
      }
    }
  }

  const floatingVariants = {
    animate: {
      y: [-10, 10, -10],
      transition: {
        duration: 6,
        repeat: Infinity,
        ease: "easeInOut"
      }
    }
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-emerald-50 via-cyan-50 to-teal-50 relative overflow-hidden">
      {/* Animated Background Elements */}
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        <motion.div 
          className="absolute top-20 left-10 w-32 h-32 bg-gradient-to-r from-emerald-200/30 to-cyan-200/30 rounded-full blur-xl"
          animate={{ 
            scale: [1, 1.2, 1],
            rotate: [0, 180, 360]
          }}
          transition={{
            duration: 20,
            repeat: Infinity,
            ease: "linear"
          }}
        />
        <motion.div 
          className="absolute top-40 right-20 w-24 h-24 bg-gradient-to-r from-teal-200/30 to-blue-200/30 rounded-full blur-xl"
          animate={{ 
            scale: [1.2, 1, 1.2],
            rotate: [360, 180, 0]
          }}
          transition={{
            duration: 15,
            repeat: Infinity,
            ease: "linear"
          }}
        />
        <motion.div 
          className="absolute bottom-20 left-1/3 w-40 h-40 bg-gradient-to-r from-cyan-200/20 to-emerald-200/20 rounded-full blur-2xl"
          animate={{ 
            scale: [1, 1.3, 1],
            x: [-20, 20, -20]
          }}
          transition={{
            duration: 25,
            repeat: Infinity,
            ease: "easeInOut"
          }}
        />
      </div>

      {/* Hero Section */}
      <motion.div 
        className="container mx-auto px-4 pt-16 pb-16 lg:pt-24 lg:pb-24 relative z-10" // Reduced top padding
        variants={containerVariants}
        initial="hidden"
        animate="visible"
      >
        <div className="grid lg:grid-cols-2 gap-16 items-center min-h-[calc(100vh-8rem)]">
          {/* Left Side - Animation */}
          <motion.div 
            className="flex justify-center lg:justify-start order-2 lg:order-1"
            variants={itemVariants}
          >
            <motion.div 
              className="w-full max-w-4xl lg:max-w-5xl xl:max-w-6xl" // Further increased max-width
              variants={floatingVariants}
              animate="animate"
            >
              <div className="relative scale-150"> {/* Increased scale from 125 to 150 */}
                <div className="absolute inset-0 bg-gradient-to-r from-emerald-400/20 to-cyan-400/20 rounded-full blur-3xl scale-110"></div>
                <DotLottieReact
                  src="https://lottie.host/2bfaedac-1035-4b85-b6ca-e3e74c5bc2fd/O921DJK0lU.lottie"
                  loop
                  autoplay
                  className="w-full h-auto relative z-10 drop-shadow-2xl"
                />
              </div>
            </motion.div>
          </motion.div>

          {/* Right Side - Content */}
          <motion.div 
            className="space-y-10 order-1 lg:order-2"
            variants={itemVariants}
          >
            <motion.div className="space-y-8" variants={itemVariants}>
              <motion.h1 
                className="text-5xl lg:text-6xl xl:text-6xl font-bold leading-tight font-unbounded"
                variants={itemVariants}
              >
                <span className="text-gray-900">Giving Without</span>
                <motion.span 
                  className="block text-transparent bg-gradient-to-r from-emerald-600 via-cyan-600 to-teal-600 bg-clip-text pb-1"
                  animate={{
                    backgroundPosition: ['0% 50%', '100% 50%', '0% 50%']
                  }}
                  transition={{
                    duration: 5,
                    repeat: Infinity,
                    ease: "linear"
                  }}
                  style={{
                    backgroundSize: '200% 200%'
                  }}
                >
                  Losing
                </motion.span>
              </motion.h1>
              
              <motion.p 
                className="text-xl lg:text-2xl text-gray-700 leading-relaxed font-medium flex flex-col gap-2 font-unbounded"
                variants={itemVariants}
              >
                <span>Donate while keeping your principal.</span>
                <span className="font-bold text-transparent bg-gradient-to-r from-emerald-600 to-cyan-600 bg-clip-text">
                  Distribute yield for good causes.
                </span>
              </motion.p>
            </motion.div>

            {/* CTA Buttons */}
            <motion.div 
              className="flex flex-col sm:flex-row gap-6"
              variants={itemVariants}
            >
              <motion.div
                whileHover={{ scale: 1.05 }}
                whileTap={{ scale: 0.95 }}
              >
                <Link
                  to="/demo"
                  className="group relative bg-gradient-to-r from-emerald-600 via-cyan-600 to-teal-600 text-white px-10 py-5 rounded-2xl font-bold text-xl hover:from-emerald-700 hover:via-cyan-700 hover:to-teal-700 transition-all duration-300 flex items-center justify-center space-x-3 shadow-2xl hover:shadow-emerald-500/25 overflow-hidden"
                >
                  <div className="absolute inset-0 bg-gradient-to-r from-white/20 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-300"></div>
                  <Sparkles className="w-6 h-6 relative z-10" />
                  <span className="relative z-10">Try Demo</span>
                  <ArrowRight className="w-6 h-6 group-hover:translate-x-2 transition-transform relative z-10" />
                </Link>
              </motion.div>
              
              <motion.div
                whileHover={{ scale: 1.05 }}
                whileTap={{ scale: 0.95 }}
              >
                <Link
                  to="/discover"
                  className="group border-3 border-emerald-600 text-emerald-700 px-10 py-5 rounded-2xl font-bold text-xl hover:bg-emerald-600 hover:text-white transition-all duration-300 flex items-center justify-center space-x-3 shadow-lg hover:shadow-xl bg-white/80 backdrop-blur-sm"
                >
                  <Globe className="w-6 h-6" />
                  <span>Explore NGOs</span>
                </Link>
              </motion.div>
            </motion.div>

            {/* Stats */}
            <div className="grid grid-cols-3 gap-8 pt-10 border-t border-emerald-200/50">
              {[
                { value: "$50K+", label: "Yield Generated", color: "text-emerald-600" },
                { value: "25+", label: "NGOs Supported", color: "text-cyan-600" },
                { value: "100%", label: "Principal Safe", color: "text-teal-600" }
              ].map((stat, index) => (
                <div 
                  key={stat.label}
                  className="text-center group"
                >
                  <div className={`text-3xl lg:text-4xl font-bold ${stat.color} mb-2`}>
                    {stat.value}
                  </div>
                  <div className="text-sm font-medium text-gray-600 group-hover:text-gray-800 transition-colors">
                    {stat.label}
                  </div>
                </div>
              ))}
            </div>
          </motion.div>
        </div>
      </motion.div>

      {/* How It Works Section */}
      <motion.div 
        className="bg-gradient-to-br from-white via-emerald-50/30 to-cyan-50/30 py-24 relative overflow-hidden"
        initial={{ opacity: 0 }}
        whileInView={{ opacity: 1 }}
        transition={{ duration: 0.8 }}
        viewport={{ once: true }}
      >
        {/* Background decoration */}
        <div className="absolute inset-0 overflow-hidden pointer-events-none">
          <motion.div 
            className="absolute top-10 right-10 w-64 h-64 bg-gradient-to-r from-emerald-100/40 to-cyan-100/40 rounded-full blur-3xl"
            animate={{
              scale: [1, 1.2, 1],
              rotate: [0, 90, 0]
            }}
            transition={{
              duration: 20,
              repeat: Infinity,
              ease: "easeInOut"
            }}
          />
        </div>

        <div className="container mx-auto px-4 relative z-10">
          <motion.div 
            className="text-center mb-20"
            initial={{ opacity: 0, y: 30 }}
            whileInView={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6 }}
            viewport={{ once: true }}
          >
            <motion.h2 
              className="text-4xl lg:text-5xl font-bold mb-6 font-unbounded"
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.6, delay: 0.2 }}
              viewport={{ once: true }}
            >
              <span className="text-gray-900">The more you give, the more you gain</span>
            </motion.h2>
            <motion.p 
                className="text-xl lg:text-2xl text-gray-600 max-w-3xl mx-auto font-medium text-justify"
                initial={{ opacity: 0, y: 20 }}
                whileInView={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.6, delay: 0.4 }}
                viewport={{ once: true }}
              >
                Simple steps to start making impact without losing your principal
              </motion.p>
          </motion.div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-12 max-w-6xl mx-auto">
            {[
              {
                step: 1,
                title: "Stake",
                description: "Deposit your assets into our secure vault",
                icon: "💰",
                color: "from-emerald-500 to-teal-500",
                bgColor: "from-emerald-50 to-teal-50"
              },
              {
                step: 2,
                title: "Earn Yield",
                description: "Accumulate yield from DeFi strategies",
                icon: "📈",
                color: "from-cyan-500 to-blue-500",
                bgColor: "from-cyan-50 to-blue-50"
              },
              {
                step: 3,
                title: "Create Impact",
                description: "Distribute 50 / 75 / 100% of your yield to fund initiatives",
                icon: "❤️",
                color: "from-teal-500 to-emerald-500",
                bgColor: "from-teal-50 to-emerald-50"
              }
            ].map((item, index) => (
              <motion.div
                key={item.step}
                className="group relative"
                initial={{ opacity: 0, y: 50 }}
                whileInView={{ opacity: 1, y: 0 }}
                transition={{ 
                  duration: 0.6, 
                  delay: index * 0.2 + 0.3,
                  ease: "easeOut"
                }}
                viewport={{ once: true }}
                whileHover={{ y: -10 }}
              >
                <div className={`relative bg-gradient-to-br ${item.bgColor} rounded-3xl p-8 shadow-lg hover:shadow-2xl transition-all duration-500 border border-white/50 backdrop-blur-sm h-full`}>
                  {/* Step number */}
                  <motion.div 
                    className={`absolute -top-4 -left-4 w-12 h-12 bg-gradient-to-r ${item.color} rounded-2xl flex items-center justify-center shadow-lg`}
                    whileHover={{ 
                      scale: 1.1,
                      rotate: 5
                    }}
                    transition={{ type: "spring", stiffness: 300 }}
                  >
                    <span className="text-white font-bold text-xl">{item.step}</span>
                  </motion.div>

                  {/* Icon */}
                  <motion.div 
                    className="text-6xl mb-6 text-center"
                    animate={{
                      scale: [1, 1.1, 1]
                    }}
                    transition={{
                      duration: 3,
                      repeat: Infinity,
                      delay: index * 0.5
                    }}
                  >
                    {item.icon}
                  </motion.div>

                  {/* Content */}
                  <div className="text-center space-y-4">
                    <h3 className="text-2xl font-bold text-gray-900 group-hover:text-gray-800 transition-colors font-unbounded">
                      {item.title}
                    </h3>
                    <p className="text-gray-600 leading-relaxed text-lg group-hover:text-gray-700 transition-colors">
                      {item.description}
                    </p>
                  </div>

                  {/* Connecting line for desktop */}
                  {index < 2 && (
                    <motion.div 
                      className="hidden md:block absolute top-1/2 -right-6 w-12 h-0.5 bg-gradient-to-r from-emerald-300 to-cyan-300"
                      initial={{ scaleX: 0 }}
                      whileInView={{ scaleX: 1 }}
                      transition={{ duration: 0.8, delay: index * 0.2 + 0.8 }}
                      viewport={{ once: true }}
                    >
                      <motion.div 
                        className="absolute right-0 top-1/2 transform -translate-y-1/2 w-2 h-2 bg-cyan-400 rounded-full"
                        animate={{
                          scale: [1, 1.5, 1],
                          opacity: [0.7, 1, 0.7]
                        }}
                        transition={{
                          duration: 2,
                          repeat: Infinity,
                          delay: index * 0.3
                        }}
                      />
                    </motion.div>
                  )}
                </div>
              </motion.div>
            ))}
          </div>

          {/* Call to action */}
          <motion.div 
            className="text-center mt-16"
            initial={{ opacity: 0, y: 30 }}
            whileInView={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6, delay: 0.8 }}
            viewport={{ once: true }}
          >
            <motion.div
              whileHover={{ scale: 1.05 }}
              whileTap={{ scale: 0.95 }}
            >
              <Link
                to="/stake"
                className="group inline-flex items-center space-x-3 bg-gradient-to-r from-emerald-600 to-cyan-600 text-white px-8 py-4 rounded-2xl font-bold text-lg hover:from-emerald-700 hover:to-cyan-700 transition-all duration-300 shadow-xl hover:shadow-2xl"
              >
                <Heart className="w-6 h-6" />
                <span>Start Giving Today!</span>
                <ArrowRight className="w-5 h-5 group-hover:translate-x-1 transition-transform" />
              </Link>
            </motion.div>
          </motion.div>
        </div>
      </motion.div>
    </div>
  )
}
