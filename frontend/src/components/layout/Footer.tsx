import { Heart } from 'lucide-react'

export default function Footer() {
  return (
    <footer className="bg-white border-t mt-16">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="py-8">
          <div className="flex justify-between items-center">
            <div className="flex items-center space-x-2">
              <Heart className="h-5 w-5 text-morph-600" />
              <span className="text-sm text-gray-600">
                © 2024 MorphImpact. Powered by Morph Chain.
              </span>
            </div>
            <div className="flex space-x-6">
              <a href="#" className="text-sm text-gray-600 hover:text-morph-600">
                About
              </a>
              <a href="#" className="text-sm text-gray-600 hover:text-morph-600">
                Docs
              </a>
              <a href="#" className="text-sm text-gray-600 hover:text-morph-600">
                Contact
              </a>
            </div>
          </div>
        </div>
      </div>
    </footer>
  )
}