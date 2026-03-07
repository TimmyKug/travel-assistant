import { Outlet, NavLink, useNavigate } from 'react-router-dom'
import { useAuth } from '../AuthContext'

export default function Layout() {
  const { user, logout } = useAuth()
  const navigate = useNavigate()

  const navClass = ({ isActive }) =>
    `flex items-center gap-2 px-3 py-2 rounded-lg text-sm font-medium transition-colors ${
      isActive ? 'bg-brand-600 text-white' : 'text-gray-600 hover:bg-gray-100'
    }`

  return (
    <div className="flex h-screen bg-gray-50">
      <aside className="w-56 flex flex-col bg-white border-r border-gray-200 py-4 px-3">
        <div className="flex items-center gap-2 px-2 mb-6">
          <span className="text-2xl">✈️</span>
          <span className="font-bold text-gray-900 text-lg">TravelAI</span>
        </div>
        <nav className="flex flex-col gap-1 flex-1">
          <NavLink to="/"      end className={navClass}>💬 Chat</NavLink>
          <NavLink to="/trips"     className={navClass}>🗺️ My Trips</NavLink>
        </nav>
        <div className="border-t border-gray-200 pt-3">
          <p className="text-xs text-gray-500 px-2 mb-2 truncate">{user?.name}</p>
          <button onClick={() => { logout(); navigate('/login') }}
            className="w-full text-left px-3 py-2 text-sm text-red-600 hover:bg-red-50 rounded-lg transition-colors">
            Sign out
          </button>
        </div>
      </aside>
      <main className="flex-1 overflow-hidden"><Outlet /></main>
    </div>
  )
}
