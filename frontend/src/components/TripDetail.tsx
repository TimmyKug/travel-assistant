import { useEffect, useMemo, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import {
  ArrowLeft,
  CalendarDays,
  Check,
  Coins,
  Hotel,
  MapPin,
  MessageSquare,
  Pencil,
  X,
  Download,
  Trash2,
} from "lucide-react";
import { deleteTrip, getTrip, updateTrip } from "../services/api";
import type { Trip, TripPlan } from "../types";
import { downloadTripMarkdown, formatTripMarkdown } from "../utils/tripMarkdown";

function parseTripPlanCandidate(value: unknown): TripPlan | null {
  if (!value || typeof value !== "object") return null;
  const candidate = value as Partial<TripPlan>;
  if (!candidate.trip_title || !candidate.destination || !Array.isArray(candidate.days)) return null;
  return candidate as TripPlan;
}

function parseTripPlanFromTrip(trip: Pick<Trip, "itinerary" | "notes">): TripPlan | null {
  if (Array.isArray(trip.itinerary) && trip.itinerary.length > 0) {
    const parsed = parseTripPlanCandidate(trip.itinerary[0]);
    if (parsed) return parsed;
  }
  if (typeof trip.notes === "string" && trip.notes.trim().startsWith("{")) {
    try {
      const parsed = JSON.parse(trip.notes);
      return parseTripPlanCandidate(parsed);
    } catch {
      return null;
    }
  }
  return null;
}

function getHotelsByNight(plan: TripPlan): Array<{
  night: number;
  date?: string;
  options: Array<{ name: string; area?: string; nightly_estimate?: string; reason?: string }>;
}> {
  if (!Array.isArray(plan.hotels) || plan.hotels.length === 0) return [];
  const first = plan.hotels[0] as unknown;
  if (first && typeof first === "object" && "options" in (first as Record<string, unknown>)) {
    return (plan.hotels as Array<{
      night: number;
      date?: string;
      options: Array<{ name: string; area?: string; nightly_estimate?: string; reason?: string }>;
    }>).filter((entry) => Number.isFinite(entry.night) && Array.isArray(entry.options));
  }
  return [
    {
      night: 1,
      options: (plan.hotels as Array<{ name: string; area?: string; nightly_estimate?: string; reason?: string }>),
    },
  ];
}

function ItineraryPreview({ plan }: { plan: TripPlan }) {
  const hotelsByNight = getHotelsByNight(plan);
  const hotelByNight = new Map(hotelsByNight.map((entry) => [entry.night, entry]));
  return (
    <div className="mt-2 rounded-xl border border-blue-900/40 bg-slate-800/70 p-3 space-y-3">
      <div>
        <h4 className="text-sm font-semibold text-blue-300">{plan.trip_title}</h4>
        <p className="text-xs text-slate-300">{plan.destination}</p>
        {plan.summary && <p className="text-xs text-slate-400 mt-1">{plan.summary}</p>}
      </div>

      <div className="space-y-2">
        {plan.days.map((day, dayIdx) => (
          <div key={`detail-day-${day.day}`} className="space-y-2">
            <div className="rounded-lg border border-slate-700 bg-slate-900/50 p-2">
              <div className="flex items-center gap-2 text-xs text-slate-300 mb-1">
                <CalendarDays className="w-3.5 h-3.5" />
                <span className="font-medium">Day {day.day}</span>
                {day.date && <span className="text-slate-500">({day.date})</span>}
              </div>
              <ol className="space-y-1.5">
                {day.items.map((item, idx) => (
                  <li key={`detail-item-${day.day}-${idx}`} className="rounded-md bg-slate-800/80 p-2">
                    <div className="flex items-center justify-between gap-2">
                      <span className="text-xs text-slate-400">{item.time}</span>
                      <span className="text-[10px] uppercase tracking-wide text-blue-300">{item.category}</span>
                    </div>
                    <p className="text-sm text-white font-medium">{item.title}</p>
                    <p className="text-xs text-slate-300">{item.description}</p>
                  </li>
                ))}
              </ol>
            </div>

            {dayIdx < plan.days.length - 1 && hotelByNight.get(day.day) && (
              <div className="rounded-lg border border-indigo-900/50 bg-indigo-900/20 p-2">
                <div className="flex items-center gap-2 text-xs text-indigo-300 mb-2">
                  <Hotel className="w-3.5 h-3.5" />
                  <span className="font-medium">
                    Night {day.day}
                    {hotelByNight.get(day.day)?.date ? ` (${hotelByNight.get(day.day)?.date})` : ""}
                  </span>
                </div>
                <ul className="space-y-1.5">
                  {hotelByNight.get(day.day)!.options.map((hotel, idx) => (
                    <li key={`detail-hotel-${day.day}-${idx}`} className="rounded-md bg-slate-800/70 p-2">
                      <p className="text-sm text-white font-medium">{hotel.name}</p>
                      <p className="text-xs text-slate-300">
                        {hotel.area ? `${hotel.area} · ` : ""}
                        {hotel.nightly_estimate ? `~${hotel.nightly_estimate}/night` : "nightly rate unspecified"}
                      </p>
                      {hotel.reason && <p className="text-xs text-slate-400 mt-1">{hotel.reason}</p>}
                    </li>
                  ))}
                </ul>
              </div>
            )}
          </div>
        ))}
      </div>

      {plan.budget && (
        <div className="rounded-lg border border-emerald-900/50 bg-emerald-900/20 p-2">
          <div className="flex items-center gap-2 text-xs text-emerald-300 mb-1">
            <Coins className="w-3.5 h-3.5" /> Budget
          </div>
          <p className="text-xs text-slate-100">
            {plan.budget.estimated_total ?? "n/a"} {plan.budget.currency ?? ""}
          </p>
          {plan.budget.notes && <p className="text-xs text-slate-300">{plan.budget.notes}</p>}
        </div>
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

export default function TripDetail() {
  const { tripId } = useParams<{ tripId: string }>();
  const navigate = useNavigate();
  const [trip, setTrip] = useState<Trip | null>(null);
  const [data, setData] = useState<Trip | null>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [editing, setEditing] = useState(false);
  const [pendingDelete, setPendingDelete] = useState(false);

  useEffect(() => {
    if (!tripId) return;
    setLoading(true);
    getTrip(tripId)
      .then((res) => {
        setTrip(res);
        setData(res);
      })
      .catch(() => setError("Trip not found."))
      .finally(() => setLoading(false));
  }, [tripId]);

  const structuredPlan = useMemo(() => (trip ? parseTripPlanFromTrip(trip) : null), [trip]);
  const editablePlan = useMemo(() => (data ? parseTripPlanFromTrip(data) : null), [data]);

  const updatePlan = (updater: (plan: TripPlan) => TripPlan) => {
    setData((prev) => {
      if (!prev) return prev;
      const current = parseTripPlanFromTrip(prev);
      if (!current) return prev;
      const next = updater(current);
      return {
        ...prev,
        title: next.trip_title || prev.title,
        destination: next.destination || prev.destination,
        notes: next.summary || prev.notes,
        itinerary: [next as unknown as Record<string, unknown>],
      };
    });
  };

  const save = async () => {
    if (!trip || !data || !trip.id || !data.title?.trim() || !data.destination?.trim()) return;
    setSaving(true);
    setError(null);
    try {
      const updated = await updateTrip(trip.id, {
        title: data.title.trim(),
        destination: data.destination.trim(),
        start_date: data.start_date,
        end_date: data.end_date,
        notes: data.notes,
        itinerary: data.itinerary,
        conversation_id: data.conversation_id,
      });
      setTrip(updated);
      setData(updated);
      setEditing(false);
    } catch {
      setError("Could not save trip changes.");
    } finally {
      setSaving(false);
    }
  };

  const confirmDelete = async () => {
    if (!trip?.id || deleting) return;
    setDeleting(true);
    setError(null);
    try {
      await deleteTrip(trip.id);
      navigate("/trips");
    } catch {
      setError("Could not delete trip.");
      setDeleting(false);
    }
  };

  if (loading) {
    return <div className="h-40 rounded-2xl bg-slate-800 animate-pulse" />;
  }

  if (!trip || !data) {
    return (
      <div className="space-y-4">
        <button
          type="button"
          onClick={() => navigate("/trips")}
          className="inline-flex items-center gap-2 text-sm text-slate-300 hover:text-white"
        >
          <ArrowLeft className="w-4 h-4" /> Back to Trips
        </button>
        <p className="text-red-400">{error ?? "Trip not found."}</p>
      </div>
    );
  }

  return (
    <div className="h-full min-h-0 overflow-y-auto pr-1 pb-10 space-y-4">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <button
          type="button"
          onClick={() => navigate("/trips")}
          className="inline-flex items-center gap-2 text-sm text-slate-300 hover:text-white"
        >
          <ArrowLeft className="w-4 h-4" /> Back to Trips
        </button>
        <div className="flex items-center gap-2">
          <button
            type="button"
            onClick={() => downloadTripMarkdown(formatTripMarkdown(trip), trip.title)}
            className="inline-flex items-center gap-1.5 text-xs px-3 py-2 rounded-lg bg-slate-700 text-slate-200 hover:bg-slate-600"
          >
            <Download className="w-3.5 h-3.5" /> Export .md
          </button>
          {trip.conversation_id && (
            <button
              type="button"
              onClick={() => navigate(`/?conversation_id=${trip.conversation_id}`)}
              className="inline-flex items-center gap-1.5 text-xs px-3 py-2 rounded-lg bg-slate-700 text-slate-200 hover:bg-slate-600"
            >
              <MessageSquare className="w-3.5 h-3.5" /> Open chat
            </button>
          )}
          {!editing ? (
            <>
              <button
                type="button"
                onClick={() => setEditing(true)}
                className="inline-flex items-center gap-1.5 text-xs px-3 py-2 rounded-lg bg-slate-700 text-amber-300 hover:bg-slate-600 border border-amber-800/40"
              >
                <Pencil className="w-3.5 h-3.5" /> Edit
              </button>
              <button
                type="button"
                onClick={() => setPendingDelete(true)}
                className="inline-flex items-center gap-1.5 text-xs px-3 py-2 rounded-lg bg-slate-700 text-red-300 hover:bg-slate-600 border border-red-900/40"
              >
                <Trash2 className="w-3.5 h-3.5" /> Delete trip
              </button>
            </>
          ) : (
            <>
              <button
                type="button"
                onClick={() => {
                  setData(trip);
                  setEditing(false);
                }}
                className="inline-flex items-center gap-1.5 text-xs px-3 py-2 rounded-lg bg-slate-700 text-slate-200 hover:bg-slate-600"
              >
                <X className="w-3.5 h-3.5" /> Cancel
              </button>
              <button
                type="button"
                onClick={save}
                disabled={saving}
                className="inline-flex items-center gap-1.5 text-xs px-3 py-2 rounded-lg bg-blue-600 text-white hover:bg-blue-700 disabled:opacity-50"
              >
                <Check className="w-3.5 h-3.5" /> {saving ? "Saving..." : "Save"}
              </button>
            </>
          )}
        </div>
      </div>

      {error && <p className="text-sm text-red-400 bg-red-900/20 rounded-lg px-3 py-2">{error}</p>}
      {pendingDelete && (
        <DeleteTripModal
          title={trip.title}
          deleting={deleting}
          onCancel={() => {
            if (!deleting) setPendingDelete(false);
          }}
          onConfirm={confirmDelete}
        />
      )}

      <section className="rounded-2xl bg-slate-700 p-4 space-y-3">
        {editing ? (
          <>
            {editablePlan ? (
              <>
                <input
                  value={editablePlan.trip_title}
                  placeholder="Trip title *"
                  onChange={(e) => updatePlan((plan) => ({ ...plan, trip_title: e.target.value }))}
                  className="w-full bg-slate-600 text-white text-sm rounded-lg px-3 py-2 outline-none focus:ring-2 focus:ring-blue-500"
                />
                <input
                  value={editablePlan.destination}
                  placeholder="Destination"
                  onChange={(e) => updatePlan((plan) => ({ ...plan, destination: e.target.value }))}
                  className="w-full bg-slate-600 text-white text-sm rounded-lg px-3 py-2 outline-none focus:ring-2 focus:ring-blue-500"
                />
                <textarea
                  value={editablePlan.summary ?? ""}
                  placeholder="Trip summary"
                  rows={2}
                  onChange={(e) => updatePlan((plan) => ({ ...plan, summary: e.target.value }))}
                  className="w-full bg-slate-600 text-white text-sm rounded-lg px-3 py-2 outline-none focus:ring-2 focus:ring-blue-500 resize-none"
                />
                {editablePlan.days.map((day, dayIdx) => (
                  <div key={`detail-edit-day-${day.day}-${dayIdx}`} className="rounded-lg border border-slate-600 p-2 space-y-2">
                    <div className="grid grid-cols-2 gap-2">
                      <input
                        value={day.day}
                        placeholder="Day #"
                        onChange={(e) =>
                          updatePlan((plan) => ({
                            ...plan,
                            days: plan.days.map((d, idx) =>
                              idx === dayIdx ? { ...d, day: Number(e.target.value) || d.day } : d
                            ),
                          }))
                        }
                        className="w-full bg-slate-600 text-white text-xs rounded-lg px-2.5 py-2 outline-none focus:ring-2 focus:ring-blue-500"
                      />
                      <input
                        value={day.date ?? ""}
                        placeholder="Date"
                        onChange={(e) =>
                          updatePlan((plan) => ({
                            ...plan,
                            days: plan.days.map((d, idx) =>
                              idx === dayIdx ? { ...d, date: e.target.value } : d
                            ),
                          }))
                        }
                        className="w-full bg-slate-600 text-white text-xs rounded-lg px-2.5 py-2 outline-none focus:ring-2 focus:ring-blue-500"
                      />
                    </div>
                    {day.items.map((item, itemIdx) => (
                      <div key={`detail-edit-item-${dayIdx}-${itemIdx}`} className="rounded-md bg-slate-800/60 p-2 space-y-2">
                        <div className="grid grid-cols-2 gap-2">
                          <input
                            value={item.time}
                            placeholder="HH:MM"
                            onChange={(e) =>
                              updatePlan((plan) => ({
                                ...plan,
                                days: plan.days.map((d, dIdx) =>
                                  dIdx === dayIdx
                                    ? {
                                        ...d,
                                        items: d.items.map((it, iIdx) =>
                                          iIdx === itemIdx ? { ...it, time: e.target.value } : it
                                        ),
                                      }
                                    : d
                                ),
                              }))
                            }
                            className="w-full bg-slate-600 text-white text-xs rounded-lg px-2.5 py-2 outline-none focus:ring-2 focus:ring-blue-500"
                          />
                          <input
                            value={item.category}
                            placeholder="Category"
                            onChange={(e) =>
                              updatePlan((plan) => ({
                                ...plan,
                                days: plan.days.map((d, dIdx) =>
                                  dIdx === dayIdx
                                    ? {
                                        ...d,
                                        items: d.items.map((it, iIdx) =>
                                          iIdx === itemIdx ? { ...it, category: e.target.value } : it
                                        ),
                                      }
                                    : d
                                ),
                              }))
                            }
                            className="w-full bg-slate-600 text-white text-xs rounded-lg px-2.5 py-2 outline-none focus:ring-2 focus:ring-blue-500"
                          />
                        </div>
                        <input
                          value={item.title}
                          placeholder="Item title"
                          onChange={(e) =>
                            updatePlan((plan) => ({
                              ...plan,
                              days: plan.days.map((d, dIdx) =>
                                dIdx === dayIdx
                                  ? {
                                      ...d,
                                      items: d.items.map((it, iIdx) =>
                                        iIdx === itemIdx ? { ...it, title: e.target.value } : it
                                      ),
                                    }
                                  : d
                              ),
                            }))
                          }
                          className="w-full bg-slate-600 text-white text-xs rounded-lg px-2.5 py-2 outline-none focus:ring-2 focus:ring-blue-500"
                        />
                        <textarea
                          value={item.description}
                          placeholder="Description"
                          rows={2}
                          onChange={(e) =>
                            updatePlan((plan) => ({
                              ...plan,
                              days: plan.days.map((d, dIdx) =>
                                dIdx === dayIdx
                                  ? {
                                      ...d,
                                      items: d.items.map((it, iIdx) =>
                                        iIdx === itemIdx ? { ...it, description: e.target.value } : it
                                      ),
                                    }
                                  : d
                              ),
                            }))
                          }
                          className="w-full bg-slate-600 text-white text-xs rounded-lg px-2.5 py-2 outline-none focus:ring-2 focus:ring-blue-500 resize-none"
                        />
                      </div>
                    ))}
                  </div>
                ))}
              </>
            ) : (
              <>
                <input
                  value={data.title ?? ""}
                  placeholder="Title *"
                  onChange={(e) => setData((d) => (d ? { ...d, title: e.target.value } : d))}
                  className="w-full bg-slate-600 text-white text-sm rounded-lg px-3 py-2 outline-none focus:ring-2 focus:ring-blue-500"
                />
                <input
                  value={data.destination ?? ""}
                  placeholder="Destination"
                  onChange={(e) => setData((d) => (d ? { ...d, destination: e.target.value } : d))}
                  className="w-full bg-slate-600 text-white text-sm rounded-lg px-3 py-2 outline-none focus:ring-2 focus:ring-blue-500"
                />
                <textarea
                  value={data.notes ?? ""}
                  placeholder="Notes"
                  rows={4}
                  onChange={(e) => setData((d) => (d ? { ...d, notes: e.target.value } : d))}
                  className="w-full bg-slate-600 text-white text-sm rounded-lg px-3 py-2 outline-none focus:ring-2 focus:ring-blue-500 resize-none"
                />
              </>
            )}
          </>
        ) : (
          <>
            <h2 className="text-2xl font-bold text-white">{trip.title}</h2>
            {trip.destination && (
              <div className="flex items-center gap-1 text-blue-400 text-base">
                <MapPin className="w-4 h-4" />
                {trip.destination}
              </div>
            )}
            {structuredPlan ? (
              <ItineraryPreview plan={structuredPlan} />
            ) : trip.notes ? (
              <p className="text-slate-300">{trip.notes}</p>
            ) : (
              <p className="text-slate-400">No details available for this trip yet.</p>
            )}
          </>
        )}
      </section>
    </div>
  );
}
