import { useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { Plane } from 'lucide-react'
import { useAuth } from '../AuthContext'
import api from '../api'

export default function Login() {
  const { login } = useAuth()
  const navigate = useNavigate()
  const [form, setForm]       = useState({ email: '', password: '' })
  const [error, setError]     = useState('')
  const [loading, setLoading] = useState(false)

  const handleSubmit = async (e) => {
    e.preventDefault(); setError(''); setLoading(true)
    try {
      const { data } = await api.post('/auth/login', form)
      login({ name: data.name, user_id: data.user_id }, data.token)
      navigate('/')
    } catch (err) {
      setError(err.response?.data?.detail || 'Login failed')
    } finally { setLoading(false) }
  }

  return (
    <div className="min-h-screen bg-slate-900 flex items-center justify-center p-4">
      <div className="w-full max-w-sm bg-slate-800 rounded-2xl shadow-2xl p-8">
        <div className="flex flex-col items-center mb-6">
          <div className="bg-blue-600 rounded-full p-4 mb-3">
            <Plane className="w-8 h-8 text-white" />
          </div>
          <h1 className="text-2xl font-bold text-white">AI Travel Assistant</h1>
          <p className="text-slate-400 text-sm mt-1">Sign in to plan your adventures</p>
        </div>
        <form onSubmit={handleSubmit} className="space-y-4">
          {[['Email', 'email', 'email', 'you@example.com'], ['Password', 'password', 'password', '••••••••']].map(([label, type, field, ph]) => (
            <div key={field}>
              <label className="block text-sm font-medium text-slate-300 mb-1">{label}</label>
              <input
                type={type} required value={form[field]} placeholder={ph}
                onChange={e => setForm(f => ({ ...f, [field]: e.target.value }))}
                className="w-full px-3 py-2 bg-slate-700 border border-slate-600 rounded-lg text-white placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-blue-500 text-sm"
              />
            </div>
          ))}
          {error && <p className="text-sm text-red-400">{error}</p>}
          <button
            type="submit" disabled={loading}
            className="w-full bg-blue-600 hover:bg-blue-700 disabled:opacity-50 text-white font-semibold py-2.5 rounded-xl transition"
          >
            {loading ? 'Signing in…' : 'Sign in'}
          </button>
        </form>
        <p className="text-center text-sm text-slate-400 mt-4">
          No account?{' '}
          <Link to="/register" className="text-blue-400 hover:underline font-medium">Create one</Link>
        </p>
      </div>
    </div>
  )
}
