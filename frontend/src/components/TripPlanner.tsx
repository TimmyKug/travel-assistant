import { useState, useEffect, useMemo } from "react";
import { useNavigate } from "react-router-dom";
import { listTrips, createTrip, deleteTrip } from "../services/api";
import { Plus, Trash2, MapPin, MessageSquare, Search, Download } from "lucide-react";
import type { Trip } from "../types";
import { downloadTripMarkdown, formatTripMarkdown } from "../utils/tripMarkdown";

interface TripCardProps {
  trip: Trip;
  onDelete: (trip: Trip) => void;
  onOpenChat: (convId: string) => void;
  onOpenDetail: (tripId: string) => void;
  onExport: (trip: Trip) => void;
}

function TripCard({ trip, onDelete, onOpenChat, onOpenDetail, onExport }: TripCardProps) {
  const summaryFromItinerary =
    Array.isArray(trip.itinerary) && trip.itinerary.length > 0 && typeof trip.itinerary[0] === "object"
      ? (trip.itinerary[0] as { summary?: unknown }).summary
      : undefined;
  const rawDescription =
    typeof summaryFromItinerary === "string" && summaryFromItinerary.trim()
      ? summaryFromItinerary
      : trip.notes;
  const description = rawDescription?.trim();

  return (
    <div
      role="button"
      tabIndex={0}
      onClick={() => onOpenDetail(trip.id)}
      onKeyDown={(e) => {
        if (e.key === "Enter" || e.key === " ") {
          e.preventDefault();
          onOpenDetail(trip.id);
        }
      }}
      className="text-left bg-slate-700 rounded-2xl p-4 space-y-3 group hover:bg-slate-600 transition w-full"
    >
      <div className="flex items-start justify-between gap-2">
        <h3 className="font-semibold text-white">{trip.title}</h3>
        <div className="flex items-center gap-1">
          <button
            type="button"
            aria-label="Export trip"
            onClick={(e) => {
              e.stopPropagation();
              onExport(trip);
            }}
            className="p-1 text-slate-400 hover:text-blue-300"
            title="Export as Markdown"
          >
            <Download className="w-4 h-4" />
          </button>
          <button
            type="button"
            aria-label="Delete trip"
            onClick={(e) => {
              e.stopPropagation();
              onDelete(trip);
            }}
            className="p-1 text-slate-400 hover:text-red-400"
          >
            <Trash2 className="w-4 h-4" />
          </button>
        </div>
      </div>

      <div className="flex items-center gap-1 text-blue-400 text-sm">
        <MapPin className="w-3 h-3" />
        <span>{trip.destination || "Destination not set"}</span>
      </div>

      {description && <p className="text-sm text-slate-300 line-clamp-2">{description}</p>}

      {trip.conversation_id && (
        <button
          type="button"
          onClick={(e) => {
            e.stopPropagation();
            onOpenChat(trip.conversation_id!);
          }}
          className="inline-flex items-center gap-1.5 text-xs text-slate-300 hover:text-blue-300 transition"
        >
          <MessageSquare className="w-3.5 h-3.5" /> Open chat
        </button>
      )}
    </div>
  );
}

function DeleteTripModal({
  title,
  deleting,
  onCancel,
  onConfirm,
}: {
  title: string;
  deleting: boolean;
  onCancel: () => void;
  onConfirm: () => void;
}) {
  return (
    <div className="fixed inset-0 z-50 bg-black/60 flex items-center justify-center p-4">
      <div className="w-full max-w-md rounded-2xl border border-slate-600 bg-slate-900 shadow-2xl p-6">
        <h3 className="text-lg font-semibold text-white">Delete Trip?</h3>
        <p className="mt-2 text-sm text-slate-300">
          This will permanently remove <span className="font-medium text-white">"{title}"</span>.
        </p>
        <div className="mt-5 flex items-center justify-end gap-2">
          <button
            type="button"
            onClick={onCancel}
            disabled={deleting}
            className="px-4 py-2 text-sm rounded-lg border border-slate-600 text-slate-300 hover:bg-slate-800 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            Cancel
          </button>
          <button
            type="button"
            onClick={onConfirm}
            disabled={deleting}
            className="px-4 py-2 text-sm rounded-lg bg-red-600 text-white hover:bg-red-700 disabled:opacity-60 disabled:cursor-not-allowed inline-flex items-center gap-2"
          >
            {deleting && (
              <span className="inline-block h-3.5 w-3.5 animate-spin rounded-full border-2 border-white/80 border-t-transparent" />
            )}
            {deleting ? "Deleting..." : "Delete"}
          </button>
        </div>
      </div>
    </div>
  );
}

export default function TripPlanner() {
  const [trips, setTrips] = useState<Trip[]>([]);
  const [adding, setAdding] = useState(false);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [pendingDeleteTrip, setPendingDeleteTrip] = useState<Trip | null>(null);
  const [deletingTrip, setDeletingTrip] = useState(false);
  const [search, setSearch] = useState("");
  const [sortBy, setSortBy] = useState<"updated" | "title">("updated");
  const [newTrip, setNewTrip] = useState({ title: "", destination: "" });
  const navigate = useNavigate();

  useEffect(() => {
    listTrips()
      .then(setTrips)
      .catch(() => setError("Could not load trips."))
      .finally(() => setLoading(false));
  }, []);

  const filteredTrips = useMemo(() => {
    const query = search.trim().toLowerCase();
    const base = trips.filter((trip) => {
      if (!query) return true;
      return [trip.title, trip.destination].filter(Boolean).some((val) => String(val).toLowerCase().includes(query));
    });

    const sorted = [...base];
    if (sortBy === "title") {
      sorted.sort((a, b) => a.title.localeCompare(b.title));
    }
    return sorted;
  }, [search, sortBy, trips]);

  const handleCreate = async () => {
    if (!newTrip.title.trim()) {
      setError("Title is required.");
      return;
    }

    const payload: { title: string; destination?: string } = { title: newTrip.title.trim() };
    if (newTrip.destination.trim()) payload.destination = newTrip.destination.trim();

    const trip = await createTrip(payload);
    setTrips((t) => [trip, ...t]);
    setNewTrip({ title: "", destination: "" });
    setAdding(false);
    setError(null);
  };

  const confirmDeleteTrip = async () => {
    if (!pendingDeleteTrip || deletingTrip) return;

    const trip = pendingDeleteTrip;
    setDeletingTrip(true);

    try {
      await deleteTrip(trip.id);
      setTrips((t) => t.filter((x) => x.id !== trip.id));
      setError(null);
    } catch {
      setError("Could not delete trip.");
    } finally {
      setDeletingTrip(false);
      setPendingDeleteTrip(null);
    }
  };

  const header = (
    <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
      <h2 className="text-xl font-bold text-white">My Trips</h2>
      <button
        onClick={() => setAdding(true)}
        className="flex items-center justify-center gap-2 bg-blue-600 hover:bg-blue-700 text-white text-sm font-medium px-4 py-2 rounded-xl transition"
      >
        <Plus className="w-4 h-4" /> New Trip
      </button>
    </div>
  );

  return (
    <div className="h-full overflow-y-auto pr-1 pb-6 space-y-4">
      {header}

      <div className="grid grid-cols-1 sm:grid-cols-[1fr_auto] gap-2">
        <div className="flex items-center gap-2 bg-slate-800 border border-slate-700 rounded-xl px-3">
          <Search className="w-4 h-4 text-slate-500" />
          <input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search trips"
            className="w-full bg-transparent text-sm text-white py-2.5 outline-none placeholder:text-slate-500"
          />
        </div>

        <select
          value={sortBy}
          onChange={(e) => setSortBy(e.target.value as "updated" | "title")}
          className="bg-slate-800 border border-slate-700 text-slate-200 rounded-xl px-3 py-2.5 text-sm outline-none"
        >
          <option value="updated">Sort: Recently updated</option>
          <option value="title">Sort: Title</option>
        </select>
      </div>

      {error && <p className="text-sm text-red-400 bg-red-900/20 rounded-lg px-3 py-2">{error}</p>}

      {pendingDeleteTrip && (
        <DeleteTripModal
          title={pendingDeleteTrip.title}
          deleting={deletingTrip}
          onCancel={() => setPendingDeleteTrip(null)}
          onConfirm={confirmDeleteTrip}
        />
      )}

      {adding && (
        <div className="bg-slate-700 rounded-2xl p-4 space-y-3">
          <input
            value={newTrip.title}
            placeholder="Trip title *"
            onChange={(e) => setNewTrip((t) => ({ ...t, title: e.target.value }))}
            onKeyDown={(e) => e.key === "Enter" && handleCreate()}
            className="w-full bg-slate-600 text-white text-sm rounded-lg px-3 py-2 outline-none focus:ring-2 focus:ring-blue-500"
          />
          <input
            value={newTrip.destination}
            placeholder="Destination"
            onChange={(e) => setNewTrip((t) => ({ ...t, destination: e.target.value }))}
            className="w-full bg-slate-600 text-white text-sm rounded-lg px-3 py-2 outline-none focus:ring-2 focus:ring-blue-500"
          />
          <div className="flex gap-2 justify-end">
            <button onClick={() => setAdding(false)} className="text-slate-400 text-sm px-3 py-1 hover:text-white">
              Cancel
            </button>
            <button onClick={handleCreate} className="bg-blue-600 text-white text-sm px-4 py-1 rounded-lg hover:bg-blue-700">
              Save
            </button>
          </div>
        </div>
      )}

      {loading ? (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          {Array.from({ length: 3 }).map((_, i) => (
            <div key={i} className="h-36 rounded-2xl bg-slate-800 animate-pulse" />
          ))}
        </div>
      ) : filteredTrips.length === 0 && !adding ? (
        <div className="text-center text-slate-500 mt-12">
          <MapPin className="w-12 h-12 mx-auto mb-3 opacity-50" />
          <p className="text-slate-400">No trips found. Start planning your next adventure.</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          {filteredTrips.map((trip) => (
            <TripCard
              key={trip.id}
              trip={trip}
              onDelete={(selectedTrip) => setPendingDeleteTrip(selectedTrip)}
              onExport={(t) => {
                downloadTripMarkdown(formatTripMarkdown(t), t.title);
              }}
              onOpenDetail={(tripId) => navigate(`/trips/${tripId}`)}
              onOpenChat={(convId) => navigate(`/?conversation_id=${convId}`)}
            />
          ))}
        </div>
      )}
    </div>
  );
}
