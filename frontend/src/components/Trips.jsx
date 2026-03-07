import { useState, useEffect } from 'react'
import api from '../api'

const EMPTY = { title: '', destination: '', start_date: '', end_date: '', budget: '', currency: 'EUR', notes: '' }

function TripCard({ trip, onEdit, onDelete }) {
  return (
    <div className="bg-white border border-gray-200 rounded-xl p-5 hover:shadow-md transition-shadow">
      <div className="flex items-start justify-between gap-2">
        <div>
          <h3 className="font-semibold text-gray-900">{trip.title}</h3>
          <p className="text-brand-600 text-sm font-medium mt-0.5">📍 {trip.destination}</p>
        </div>
        <div className="flex gap-1 shrink-0">
          <button onClick={() => onEdit(trip)} className="text-xs px-2 py-1 text-gray-500 hover:bg-gray-100 rounded-lg">Edit</button>
          <button onClick={() => onDelete(trip.id)} className="text-xs px-2 py-1 text-red-500 hover:bg-red-50 rounded-lg">Delete</button>
        </div>
      </div>
      <div className="mt-3 flex flex-wrap gap-3 text-xs text-gray-500">
        {trip.start_date && <span>📅 {trip.start_date} → {trip.end_date}</span>}
        {trip.budget && <span>💰 {trip.budget} {trip.currency}</span>}
      </div>
      {trip.notes && <p className="mt-3 text-sm text-gray-600 line-clamp-2">{trip.notes}</p>}
    </div>
  )
}

function Modal({ trip, onSave, onClose }) {
  const [form, setForm]     = useState(trip ? { ...trip, budget: trip.budget ?? '' } : EMPTY)
  const [saving, setSaving] = useState(false)
  const set = f => e => setForm(prev => ({ ...prev, [f]: e.target.value }))

  const handleSave = async () => {
    if (!form.title || !form.destination) return
    setSaving(true)
    try { await onSave({ ...form, budget: form.budget ? Number(form.budget) : null }) }
    finally { setSaving(false) }
  }

  return (
    <div className="fixed inset-0 bg-black/40 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-2xl shadow-xl w-full max-w-md p-6">
        <h2 className="text-lg font-bold text-gray-900 mb-4">{trip ? 'Edit Trip' : 'New Trip'}</h2>
        <div className="space-y-3">
          <input placeholder="Title *" value={form.title} onChange={set('title')} className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-500" />
          <input placeholder="Destination *" value={form.destination} onChange={set('destination')} className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-500" />
          <div className="flex gap-2">
            <input type="date" value={form.start_date} onChange={set('start_date')} className="flex-1 px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-500" />
            <input type="date" value={form.end_date} onChange={set('end_date')} className="flex-1 px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-500" />
          </div>
          <div className="flex gap-2">
            <input type="number" placeholder="Budget" value={form.budget} onChange={set('budget')} className="flex-1 px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-500" />
            <select value={form.currency} onChange={set('currency')} className="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-500">
              {['EUR','USD','GBP','JPY','AUD'].map(c => <option key={c}>{c}</option>)}
            </select>
          </div>
          <textarea placeholder="Notes, itinerary…" value={form.notes ?? ''} onChange={set('notes')} rows={3} className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm resize-none focus:outline-none focus:ring-2 focus:ring-brand-500" />
        </div>
        <div className="flex gap-2 mt-4">
          <button onClick={onClose} className="flex-1 py-2 text-sm border border-gray-300 rounded-lg hover:bg-gray-50">Cancel</button>
          <button onClick={handleSave} disabled={saving || !form.title || !form.destination}
            className="flex-1 py-2 text-sm bg-brand-600 hover:bg-brand-700 disabled:opacity-40 text-white rounded-lg transition-colors">
            {saving ? 'Saving…' : 'Save Trip'}
          </button>
        </div>
      </div>
    </div>
  )
}

export default function Trips() {
  const [trips, setTrips]     = useState([])
  const [loading, setLoading] = useState(true)
  const [modal, setModal]     = useState(null)

  useEffect(() => {
    api.get('/trips/').then(r => setTrips(r.data)).finally(() => setLoading(false))
  }, [])

  const handleSave = async (form) => {
    if (modal && modal !== 'new') {
      const { data } = await api.put(`/trips/${modal.id}`, form)
      setTrips(prev => prev.map(t => t.id === modal.id ? { id: modal.id, ...data } : t))
    } else {
      const { data } = await api.post('/trips/', form)
      setTrips(prev => [data, ...prev])
    }
    setModal(null)
  }

  const handleDelete = async (id) => {
    if (!confirm('Delete this trip?')) return
    await api.delete(`/trips/${id}`)
    setTrips(prev => prev.filter(t => t.id !== id))
  }

  return (
    <div className="h-full overflow-y-auto p-6">
      <div className="max-w-3xl mx-auto">
        <div className="flex items-center justify-between mb-6">
          <div>
            <h1 className="text-2xl font-bold text-gray-900">My Trips</h1>
            <p className="text-sm text-gray-500 mt-0.5">Save and organise your travel plans</p>
          </div>
          <button onClick={() => setModal('new')} className="bg-brand-600 hover:bg-brand-700 text-white text-sm font-medium px-4 py-2 rounded-lg transition-colors">
            + New trip
          </button>
        </div>
        {loading ? (
          <p className="text-gray-400 text-sm">Loading…</p>
        ) : trips.length === 0 ? (
          <div className="text-center py-16 text-gray-400">
            <div className="text-5xl mb-3">🗺️</div>
            <p className="text-base font-medium text-gray-500">No trips saved yet</p>
          </div>
        ) : (
          <div className="grid gap-4 sm:grid-cols-2">
            {trips.map(t => <TripCard key={t.id} trip={t} onEdit={setModal} onDelete={handleDelete} />)}
          </div>
        )}
      </div>
      {modal && <Modal trip={modal === 'new' ? null : modal} onSave={handleSave} onClose={() => setModal(null)} />}
    </div>
  )
}
