/**
 * FeaturedCampaign Component
 * Showcases a featured campaign with image carousel
 */

import { useState, useEffect } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { ChevronLeft, ChevronRight, Heart, ArrowRight, Loader } from 'lucide-react'
import { useNavigate } from 'react-router-dom'
import { useReadContract } from 'wagmi'
import campaignRegistryABI from '../../abis/CampaignRegistry.json'
import { hexToCid, fetchMetadataFromIPFS, getIPFSUrl } from '../../services/ipfs'
import { CONTRACT_ADDRESSES } from '../../config/contracts'

const CAMPAIGN_REGISTRY_ADDRESS = (CONTRACT_ADDRESSES as any).CAMPAIGN_REGISTRY

// 🎯 FEATURED CAMPAIGN ID - Change this to switch the featured campaign on the home page
// Updated to new campaign submitted with v3 upgrade (includes depositAmount in event)
const FEATURED_CAMPAIGN_ID = '0x50fb6b175639347dc05cb8398175eb1e1f3a01b4c3cf90b2cada866148678b74'

interface FeaturedCampaignProps {
  campaignId?: string
}

export default function FeaturedCampaign({ campaignId = FEATURED_CAMPAIGN_ID }: FeaturedCampaignProps) {
  const [currentImage, setCurrentImage] = useState(0)
  const [metadata, setMetadata] = useState<any>(null)
  const [isLoadingMetadata, setIsLoadingMetadata] = useState(false)
  const navigate = useNavigate()

  // Fetch campaign data from contract
  const { data: campaignData } = useReadContract({
    address: CAMPAIGN_REGISTRY_ADDRESS as `0x${string}`,
    abi: campaignRegistryABI,
    functionName: 'getCampaign',
    args: campaignId ? [campaignId as `0x${string}`] : undefined,
    query: { enabled: !!campaignId }
  })

  // Fetch IPFS metadata when campaign data loads
  useEffect(() => {
    const loadMetadata = async () => {
      if (!campaignData) return
      
      const campaign = campaignData as any
      const metadataHash = campaign.metadataHash
      
      if (!metadataHash || metadataHash === '0x0000000000000000000000000000000000000000000000000000000000000000') {
        return
      }
      
      setIsLoadingMetadata(true)
      
      try {
        const cid = await hexToCid(metadataHash, campaignId || undefined)
        
        if (!cid) {
          return
        }
        
        const data = await fetchMetadataFromIPFS(cid)
        
        if (data) {
          setMetadata(data)
        }
      } catch (error) {
        console.error('Error loading campaign metadata:', error)
      } finally {
        setIsLoadingMetadata(false)
      }
    }
    
    loadMetadata()
  }, [campaignData, campaignId])

  // Campaign images - use metadata if available, fallback to local images
  const campaignImages = metadata?.images?.length > 0 
    ? metadata.images.map((hash: string) => getIPFSUrl(hash))
    : []

  // Auto-rotate images every 4 seconds
  useEffect(() => {
    if (campaignImages.length <= 1) return
    
    const interval = setInterval(() => {
      setCurrentImage((prev) => (prev + 1) % campaignImages.length)
    }, 4000)
    return () => clearInterval(interval)
  }, [campaignImages.length])

  const nextImage = () => {
    setCurrentImage((prev) => (prev + 1) % campaignImages.length)
  }

  const prevImage = () => {
    setCurrentImage((prev) => (prev - 1 + campaignImages.length) % campaignImages.length)
  }

  // Loading state
  if (isLoadingMetadata || !metadata) {
    return (
      <section className="py-24 bg-gradient-to-br from-white via-emerald-50/30 to-cyan-50/30 relative overflow-hidden">
        <div className="container mx-auto px-4 relative z-10">
          <div className="flex justify-center items-center py-20">
            <div className="text-center">
              <Loader className="w-12 h-12 animate-spin text-cyan-500 mx-auto mb-4" />
              <p className="text-gray-600">Loading featured campaign...</p>
            </div>
          </div>
        </div>
      </section>
    )
  }

  // Don't render if no images available
  if (campaignImages.length === 0) {
    return null
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
                  src={campaignImages[currentImage]}
                  alt={`${metadata?.name || 'Campaign'} - Image ${currentImage + 1}`}
                  initial={{ opacity: 0, scale: 1.1 }}
                  animate={{ opacity: 1, scale: 1 }}
                  exit={{ opacity: 0, scale: 0.9 }}
                  transition={{ duration: 0.6 }}
                  className="w-full h-full object-cover"
                />
              </AnimatePresence>
              
              {/* Navigation Buttons - only show if multiple images */}
              {campaignImages.length > 1 && (
                <>
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
                    {campaignImages.map((_: string, index: number) => (
                      <button
                        key={index}
                        onClick={() => setCurrentImage(index)}
                        className={`w-3 h-3 rounded-full transition-all duration-300 ${
                          index === currentImage ? 'bg-emerald-500 scale-125' : 'bg-white/60 hover:bg-white/80'
                        }`}
                      />
                    ))}
                  </div>
                </>
              )}
            </div>
          </motion.div>

          {/* Content */}
          <motion.div
            initial={{ opacity: 0, x: 50 }}
            whileInView={{ opacity: 1, x: 0 }}
            transition={{ duration: 0.8 }}
            className="space-y-8"
          >
            {/* Featured Campaign Label */}
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.6 }}
              className="inline-flex items-center space-x-2 bg-gradient-to-r from-emerald-100 to-cyan-100 text-emerald-800 px-6 py-3 rounded-full text-sm font-semibold shadow-lg"
            >
              <Heart className="w-4 h-4" />
              <span>Featured Campaign</span>
            </motion.div>
            
            <div>
              <motion.h2
                initial={{ opacity: 0, y: 20 }}
                whileInView={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.6, delay: 0.1 }}
                className="text-3xl lg:text-4xl font-bold bg-gradient-to-r from-emerald-600 to-cyan-600 bg-clip-text text-transparent font-unbounded mb-2"
              >
                {metadata?.organization || 'Featured Organization'}
              </motion.h2>
              <motion.h3
                initial={{ opacity: 0, y: 20 }}
                whileInView={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.6, delay: 0.2 }}
                className="text-lg font-semibold text-gray-800 font-unbounded mb-4"
              >
                {metadata?.name || 'Campaign Name'}
              </motion.h3>
              <motion.p
                initial={{ opacity: 0, y: 20 }}
                whileInView={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.6, delay: 0.3 }}
                className="text-gray-600 leading-relaxed text-lg mb-8 text-justify"
              >
                {metadata?.description || metadata?.mission || 'Support this campaign to make a difference.'}
              </motion.p>
            </div>

            {/* Donate CTA */}
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.6, delay: 0.4 }}
              className="flex justify-center"
            >
              <motion.button
                onClick={() => {
                  navigate(`/campaigns/${campaignId}`);
                }}
                whileHover={{ scale: 1.05, y: -2 }}
                whileTap={{ scale: 0.95 }}
                className="bg-gradient-to-r from-green-500 to-emerald-600 text-white px-10 py-4 rounded-2xl font-bold text-lg font-unbounded hover:from-green-600 hover:to-emerald-700 transition-all duration-300 shadow-lg hover:shadow-xl flex items-center space-x-3 group cursor-pointer"
              >
                <Heart className="w-6 h-6 group-hover:scale-110 transition-transform" />
                <span>Donate Now</span>
                <ArrowRight className="w-6 h-6 group-hover:translate-x-1 transition-transform" />
              </motion.button>
            </motion.div>
          </motion.div>
        </div>
      </div>
    </section>
  )
}
