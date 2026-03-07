import { useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { useAuth } from '../AuthContext'
import api from '../api'

export default function Register() {
  const { login } = useAuth()
  const navigate = useNavigate()
  const [form, setForm]       = useState({ name: '', email: '', password: '' })
  const [error, setError]     = useState('')
  const [loading, setLoading] = useState(false)

  const handleSubmit = async (e) => {
    e.preventDefault(); setError(''); setLoading(true)
    try {
      const { data } = await api.post('/auth/register', form)
      login({ name: data.name, user_id: data.user_id }, data.token)
      navigate('/')
    } catch (err) {
      setError(err.response?.data?.detail || 'Registration failed')
    } finally { setLoading(false) }
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-brand-50 to-teal-100 p-4">
      <div className="w-full max-w-sm bg-white rounded-2xl shadow-lg p-8">
        <div className="text-center mb-6">
          <div className="text-4xl mb-2">🌍</div>
          <h1 className="text-2xl font-bold text-gray-900">Create account</h1>
          <p className="text-gray-500 text-sm mt-1">Start planning your adventures</p>
        </div>
        <form onSubmit={handleSubmit} className="space-y-4">
          {[['Name','text','name','Your name'],['Email','email','email','you@example.com'],['Password','password','password','Min. 8 characters']].map(([label,type,field,ph]) => (
            <div key={field}>
              <label className="block text-sm font-medium text-gray-700 mb-1">{label}</label>
              <input type={type} required value={form[field]} placeholder={ph}
                onChange={e => setForm(f => ({...f,[field]:e.target.value}))}
                className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-brand-500 text-sm" />
            </div>
          ))}
          {error && <p className="text-sm text-red-600">{error}</p>}
          <button type="submit" disabled={loading}
            className="w-full bg-brand-600 hover:bg-brand-700 disabled:opacity-50 text-white font-medium py-2 px-4 rounded-lg transition-colors">
            {loading ? 'Creating account…' : 'Create account'}
          </button>
        </form>
        <p className="text-center text-sm text-gray-500 mt-4">
          Already have an account? <Link to="/login" className="text-brand-600 hover:underline font-medium">Sign in</Link>
        </p>
      </div>
    </div>
  )
}
