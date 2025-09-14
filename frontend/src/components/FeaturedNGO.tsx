import { useState, useEffect } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { ChevronLeft, ChevronRight, Heart, ArrowRight } from 'lucide-react'
import garden1 from '../assets/IMG_4241.jpg'
import garden2 from '../assets/IMG_5543.jpg'
import garden3 from '../assets/IMG_5550.jpg'

const images = [
  { src: garden1, alt: 'Biodynamic Garden Setup' },
  { src: garden2, alt: 'Students Learning Together' },
  { src: garden3, alt: 'Harvest and Community' }
]

export default function FeaturedNGO() {
  const [currentImage, setCurrentImage] = useState(0)

  // Auto-rotate images every 4 seconds
  useEffect(() => {
    const interval = setInterval(() => {
      setCurrentImage((prev) => (prev + 1) % images.length)
    }, 4000)
    return () => clearInterval(interval)
  }, [])

  const nextImage = () => {
    setCurrentImage((prev) => (prev + 1) % images.length)
  }

  const prevImage = () => {
    setCurrentImage((prev) => (prev - 1 + images.length) % images.length)
  }

  return (
    <section className="py-24 bg-gradient-to-br from-white via-emerald-50/30 to-cyan-50/30 relative overflow-hidden">
      {/* Background Effects */}
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
        <motion.div 
          className="absolute bottom-20 left-10 w-48 h-48 bg-gradient-to-r from-cyan-100/30 to-teal-100/30 rounded-full blur-2xl"
          animate={{
            scale: [1.2, 1, 1.2],
            x: [-10, 10, -10]
          }}
          transition={{
            duration: 15,
            repeat: Infinity,
            ease: "easeInOut"
          }}
        />
      </div>
      
      <div className="container mx-auto px-4 relative z-10">

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-16 items-start">
          {/* Image Carousel */}
          <motion.div
            initial={{ opacity: 0, x: -50 }}
            whileInView={{ opacity: 1, x: 0 }}
            transition={{ duration: 0.8 }}
            className="relative"
          >
            <div className="relative aspect-square w-4/5 mx-auto rounded-3xl overflow-hidden bg-white shadow-2xl hover:shadow-3xl transition-all duration-500">
              <AnimatePresence mode="wait">
                <motion.img
                  key={currentImage}
                  src={images[currentImage].src}
                  alt={images[currentImage].alt}
                  initial={{ opacity: 0, scale: 1.1 }}
                  animate={{ opacity: 1, scale: 1 }}
                  exit={{ opacity: 0, scale: 0.9 }}
                  transition={{ duration: 0.6 }}
                  className="w-full h-full object-cover"
                />
              </AnimatePresence>
              
              {/* Navigation Buttons */}
              <button
                onClick={prevImage}
                className="absolute left-4 top-1/2 -translate-y-1/2 w-12 h-12 bg-white/90 hover:bg-white rounded-full flex items-center justify-center transition-all duration-300 shadow-xl hover:scale-110"
              >
                <ChevronLeft className="w-6 h-6 text-gray-700" />
              </button>
              
              <button
                onClick={nextImage}
                className="absolute right-4 top-1/2 -translate-y-1/2 w-12 h-12 bg-white/90 hover:bg-white rounded-full flex items-center justify-center transition-all duration-300 shadow-xl hover:scale-110"
              >
                <ChevronRight className="w-6 h-6 text-gray-700" />
              </button>
              
              {/* Image Indicators */}
              <div className="absolute bottom-6 left-1/2 -translate-x-1/2 flex space-x-3">
                {images.map((_, index) => (
                  <button
                    key={index}
                    onClick={() => setCurrentImage(index)}
                    className={`w-3 h-3 rounded-full transition-all duration-300 ${
                      index === currentImage ? 'bg-emerald-500 scale-125' : 'bg-white/60 hover:bg-white/80'
                    }`}
                  />
                ))}
              </div>
            </div>
          </motion.div>

          {/* Content */}
          <motion.div
            initial={{ opacity: 0, x: 50 }}
            whileInView={{ opacity: 1, x: 0 }}
            transition={{ duration: 0.8 }}
            className="space-y-8"
          >
            {/* Featured NGO Label */}
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.6 }}
              className="inline-flex items-center space-x-2 bg-gradient-to-r from-emerald-100 to-cyan-100 text-emerald-800 px-6 py-3 rounded-full text-sm font-semibold shadow-lg"
            >
              <Heart className="w-4 h-4" />
              <span>Featured NGO Partner</span>
            </motion.div>
            
            <div>
              <motion.h2
                initial={{ opacity: 0, y: 20 }}
                whileInView={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.6, delay: 0.1 }}
                className="text-3xl lg:text-4xl font-bold bg-gradient-to-r from-emerald-600 to-cyan-600 bg-clip-text text-transparent font-unbounded mb-2"
              >
                Nanyang Foundation
              </motion.h2>
              <motion.h3
                initial={{ opacity: 0, y: 20 }}
                whileInView={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.6, delay: 0.2 }}
                className="text-lg font-semibold text-gray-800 font-unbounded mb-4"
              >
                Star Dream Garden: Biodynamic Farming Program
              </motion.h3>
              <motion.p
                 initial={{ opacity: 0, y: 20 }}
                 whileInView={{ opacity: 1, y: 0 }}
                 transition={{ duration: 0.6, delay: 0.3 }}
                 className="text-gray-600 leading-relaxed text-lg mb-8 text-justify"
               >
                 Empower individuals with autism, ADHD, and Down syndrome to grow, learn, and thrive through biodynamic farming. By supporting this initiative, you are providing seeds, tools, equipment, and mentorship that plant hope, nurture life skills, and open doors to independence and community belonging. Every contribution helps participants build confidence, discover purpose, and experience the joy of cultivating both the land and their own potential.
               </motion.p>
            </div>

            {/* Donate CTA */}
             <motion.div
               initial={{ opacity: 0, y: 20 }}
               whileInView={{ opacity: 1, y: 0 }}
               transition={{ duration: 0.6, delay: 0.4 }}
               className="flex justify-center"
             >
               <motion.a
                 href="/campaign/0xe45d65267F0DDA5e6163ED6D476F72049972ce3b"
                 whileHover={{ scale: 1.05, y: -2 }}
                 whileTap={{ scale: 0.95 }}
                 className="bg-gradient-to-r from-green-500 to-emerald-600 text-white px-10 py-4 rounded-2xl font-bold text-lg font-unbounded hover:from-green-600 hover:to-emerald-700 transition-all duration-300 shadow-lg hover:shadow-xl flex items-center space-x-3 group"
               >
                 <Heart className="w-6 h-6 group-hover:scale-110 transition-transform" />
                 <span>Donate Now</span>
                 <ArrowRight className="w-6 h-6 group-hover:translate-x-1 transition-transform" />
               </motion.a>
             </motion.div>
          </motion.div>
        </div>
      </div>
    </section>
  )
}
