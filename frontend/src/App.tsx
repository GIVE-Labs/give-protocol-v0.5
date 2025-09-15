import { BrowserRouter as Router, Routes, Route } from 'react-router-dom'
import Header from './components/layout/Header'
import Footer from './components/Footer'
import Home from './pages/Home'
// import Discover from './pages/ngo'
import NGOsPage from './pages/NGOs'
import Dashboard from './pages/Dashboard'
import NGODetails from './pages/NGODetails'
import CreateNGO from './pages/CreateNGO'
import CreateCampaign from './pages/CreateCampaign'
import CampaignStaking from './pages/CampaignStaking'

function App() {
  return (
    <Router>
      <div className="min-h-screen">
        <Header />
        <main>
          <Routes>
            <Route path="/" element={<Home />} />
            <Route path="/ngo" element={<NGOsPage />} />
            <Route path="/dashboard" element={<Dashboard />} />
            <Route path="/ngo/:address" element={<NGODetails />} />
            <Route path="/campaign/:ngoAddress" element={<CampaignStaking />} />
            <Route path="/create-ngo" element={<CreateNGO />} />
            <Route path="/create-campaign" element={<CreateCampaign />} />
          </Routes>
        </main>
        <Footer />
      </div>
    </Router>
  )
}

export default App
