import { lazy, Suspense } from 'react'
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom'
import Header from './components/layout/Header'
import Footer from './components/Footer'

// Code-split route components to reduce initial bundle size
const Home = lazy(() => import('./pages/Home'))
const Campaigns = lazy(() => import('./pages/Campaigns'))
const CampaignDetails = lazy(() => import('./pages/CampaignDetails'))
const Dashboard = lazy(() => import('./pages/Dashboard'))
const CreateCampaign = lazy(() => import('./pages/CreateCampaign'))

// Loading fallback component
function RouteLoader() {
  return (
    <div className="min-h-screen flex items-center justify-center">
      <div className="text-center">
        <div className="w-16 h-16 border-4 border-cyan-500 border-t-transparent rounded-full animate-spin mx-auto mb-4"></div>
        <p className="text-gray-400">Loading...</p>
      </div>
    </div>
  )
}

function App() {
  return (
    <Router>
      <div className="min-h-screen">
        <Header />
        <main>
          <Suspense fallback={<RouteLoader />}>
            <Routes>
              <Route path="/" element={<Home />} />
              <Route path="/campaigns" element={<Campaigns />} />
              <Route path="/campaigns/create" element={<CreateCampaign />} />
              <Route path="/campaigns/:campaignId" element={<CampaignDetails />} />
              <Route path="/dashboard" element={<Dashboard />} />
            </Routes>
          </Suspense>
        </main>
        <Footer />
      </div>
    </Router>
  )
}

export default App
