import { BrowserRouter as Router, Routes, Route } from 'react-router-dom'
import Header from './components/layout/Header'
import Footer from './components/layout/Footer'
import Home from './pages/Home'
import Discover from './pages/Discover'
import Dashboard from './pages/Dashboard'
import NGODetails from './pages/NGODetails'
import CreateNGO from './pages/CreateNGO'

function App() {
  return (
    <Router>
      <div className="min-h-screen bg-gray-50">
        <Header />
        <main>
          <Routes>
            <Route path="/" element={<Home />} />
            <Route path="/discover" element={<Discover />} />
            <Route path="/dashboard" element={<Dashboard />} />
            <Route path="/ngo/:address" element={<NGODetails />} />
            <Route path="/create-ngo" element={<CreateNGO />} />
          </Routes>
        </main>
        <Footer />
      </div>
    </Router>
  )
}

export default App