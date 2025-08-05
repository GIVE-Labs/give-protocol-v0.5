import { useState } from 'react'
import { X } from 'lucide-react'
import StakingForm from './StakingForm'
import { NGO } from '../../types'

interface StakeModalProps {
  isOpen: boolean
  onClose: () => void
  ngo: NGO
}

export default function StakeModal({ isOpen, onClose, ngo }: StakeModalProps) {
  if (!isOpen) return null

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-white rounded-lg max-w-2xl w-full mx-4 max-h-[90vh] overflow-y-auto">
        <div className="flex justify-between items-center p-6 border-b">
          <div>
            <h2 className="text-2xl font-bold text-gray-900">Stake for {ngo.name}</h2>
            <p className="text-sm text-gray-600 mt-1">Support this NGO while preserving your principal</p>
          </div>
          <button
            onClick={onClose}
            className="p-2 hover:bg-gray-100 rounded-lg transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        <div className="p-6">
          <StakingForm ngo={ngo} onClose={onClose} />
        </div>
      </div>
    </div>
  )
}