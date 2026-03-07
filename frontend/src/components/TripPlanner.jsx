import { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { listTrips, createTrip, updateTrip, deleteTrip } from "../services/api";
import { Plus, Trash2, MapPin, Calendar, Pencil, X, Check, MessageSquare } from "lucide-react";

function TripCard({ trip, onDelete, onUpdate, onViewChat }) {
  const [editing, setEditing] = useState(false);
  const [data, setData] = useState(trip);

  const save = async () => {
    await onUpdate(trip.id, data);
    setEditing(false);
  };

  const field = (key, placeholder) => (
    <input key={key} value={data[key] || ""} placeholder={placeholder}
      onChange={e => setData(d => ({ ...d, [key]: e.target.value }))}
      className="w-full bg-slate-600 text-white text-sm rounded-lg px-3 py-2 outline-none focus:ring-2 focus:ring-blue-500" />
  );

  if (editing) return (
    <div className="bg-slate-700 rounded-2xl p-4 space-y-3">
      {field("title", "Title *")}
      {field("destination", "Destination")}
      {field("start_date", "Start Date")}
      {field("end_date", "End Date")}
      <textarea value={data.notes || ""} placeholder="Notes" rows={3}
        onChange={e => setData(d => ({ ...d, notes: e.target.value }))}
        className="w-full bg-slate-600 text-white text-sm rounded-lg px-3 py-2 outline-none focus:ring-2 focus:ring-blue-500 resize-none" />
      <div className="flex gap-2 justify-end">
        <button onClick={() => setEditing(false)} className="p-2 text-slate-400 hover:text-white"><X className="w-4 h-4" /></button>
        <button onClick={save} className="p-2 text-green-400 hover:text-green-300"><Check className="w-4 h-4" /></button>
      </div>
    </div>
  );

  return (
    <div className="bg-slate-700 rounded-2xl p-4 space-y-2 group hover:bg-slate-600 transition">
      <div className="flex items-start justify-between">
        <h3 className="font-semibold text-white">{trip.title}</h3>
        <div className="flex gap-1 opacity-0 group-hover:opacity-100 transition">
          <button onClick={() => setEditing(true)} className="p-1 text-slate-400 hover:text-white"><Pencil className="w-4 h-4" /></button>
          <button onClick={() => onDelete(trip.id)} className="p-1 text-slate-400 hover:text-red-400"><Trash2 className="w-4 h-4" /></button>
        </div>
      </div>
      {trip.destination && <div className="flex items-center gap-1 text-blue-400 text-sm"><MapPin className="w-3 h-3" />{trip.destination}</div>}
      {(trip.start_date || trip.end_date) && (
        <div className="flex items-center gap-1 text-slate-400 text-xs">
          <Calendar className="w-3 h-3" />{trip.start_date}{trip.end_date ? ` to ${trip.end_date}` : ""}
        </div>
      )}
      {trip.notes && <p className="text-slate-300 text-sm line-clamp-2">{trip.notes}</p>}
      {trip.conversation_id && (
        <button
          onClick={() => onViewChat(trip.conversation_id)}
          className="mt-1 flex items-center gap-1.5 text-xs text-slate-400 hover:text-blue-400 transition"
        >
          <MessageSquare className="w-3.5 h-3.5" /> View chat
        </button>
      )}
    </div>
  );
}

export default function TripPlanner() {
  const [trips, setTrips]     = useState([]);
  const [adding, setAdding]   = useState(false);
  const [newTrip, setNewTrip] = useState({ title: "", destination: "" });
  const navigate              = useNavigate();

  useEffect(() => { listTrips().then(setTrips).catch(console.error); }, []);

  const handleCreate = async () => {
    if (!newTrip.title.trim()) return;
    const trip = await createTrip(newTrip);
    setTrips(t => [trip, ...t]);
    setNewTrip({ title: "", destination: "" });
    setAdding(false);
  };

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h2 className="text-xl font-bold text-white">My Trips</h2>
        <button onClick={() => setAdding(true)}
          className="flex items-center gap-2 bg-blue-600 hover:bg-blue-700 text-white text-sm font-medium px-4 py-2 rounded-xl transition">
          <Plus className="w-4 h-4" /> New Trip
        </button>
      </div>

      {adding && (
        <div className="bg-slate-700 rounded-2xl p-4 space-y-3">
          <input value={newTrip.title} placeholder="Trip title *"
            onChange={e => setNewTrip(t => ({ ...t, title: e.target.value }))}
            onKeyDown={e => e.key === "Enter" && handleCreate()}
            className="w-full bg-slate-600 text-white text-sm rounded-lg px-3 py-2 outline-none focus:ring-2 focus:ring-blue-500" />
          <input value={newTrip.destination} placeholder="Destination"
            onChange={e => setNewTrip(t => ({ ...t, destination: e.target.value }))}
            className="w-full bg-slate-600 text-white text-sm rounded-lg px-3 py-2 outline-none focus:ring-2 focus:ring-blue-500" />
          <div className="flex gap-2 justify-end">
            <button onClick={() => setAdding(false)} className="text-slate-400 text-sm px-3 py-1 hover:text-white">Cancel</button>
            <button onClick={handleCreate} className="bg-blue-600 text-white text-sm px-4 py-1 rounded-lg hover:bg-blue-700">Save</button>
          </div>
        </div>
      )}

      {trips.length === 0 && !adding ? (
        <div className="text-center text-slate-500 mt-12">
          <MapPin className="w-12 h-12 mx-auto mb-3 opacity-50" />
          <p className="text-slate-400">No trips yet. Start planning your next adventure!</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          {trips.map(trip => (
            <TripCard key={trip.id} trip={trip}
              onDelete={async id => { await deleteTrip(id); setTrips(t => t.filter(x => x.id !== id)); }}
              onUpdate={async (id, data) => { const u = await updateTrip(id, data); setTrips(t => t.map(x => x.id === id ? u : x)); }}
              onViewChat={convId => navigate(`/?conversation_id=${convId}`)} />
          ))}
        </div>
      )}
    </div>
  );
}
