import { useMemo, useRef, useEffect, useState, useCallback } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import {
  sendMessage,
  getConversation,
  listConversations,
  listTrips,
  createTrip,
  updateTrip,
  renameConversation,
  deleteConversation,
} from "../services/api";
import {
  Send,
  Bot,
  User,
  AlertCircle,
  Bookmark,
  BookmarkCheck,
  Plus,
  MessageSquare,
  Pin,
  Pencil,
  Trash2,
  Download,
  Menu,
  X,
  Sparkles,
  CalendarDays,
  Coins,
  Hotel,
  RotateCcw,
  Loader2,
  ArrowUpRight,
} from "lucide-react";
import ReactMarkdown from "react-markdown";
import type { Conversation, Trip, TripPlan } from "../types";
import { downloadTripMarkdown, formatTripPlanMarkdown } from "../utils/tripMarkdown";

interface ChatMessage {
  role: "user" | "assistant";
  content: string;
  tripPlan?: TripPlan | null;
}

interface SaveModalState {
  content: string;
  index: number;
  tripPlan?: TripPlan | null;
}

interface RetryRequest {
  requestText: string;
  conversationId: string | null;
}

const PINNED_KEY = "pinned_conversations";
const INITIAL_RECOMMENDATION_COUNT = 3;
const INITIAL_RECOMMENDATION_POOL: string[] = [
  "Plan a 3-day city break with local highlights.",
  "Build a low-budget weekend itinerary in Europe.",
  "Suggest a family-friendly 5-day trip with kids.",
  "Create a business trip plan with efficient routing.",
  "Find a foodie itinerary with cheap local gems.",
  "Plan a nature-focused trip with easy hikes.",
  "Design a romantic weekend with cozy stays.",
  "Create a solo travel plan with safety tips.",
  "Plan a beach escape with transport options.",
  "Suggest a cultural itinerary with museums and landmarks.",
  "Build a backpacker route with hostel options.",
  "Plan a rainy-day itinerary with indoor alternatives.",
  "Create a luxury short break with premium stays.",
  "Suggest a winter city trip with warm indoor spots.",
  "Design a summer trip with heat-friendly pacing.",
  "Plan a train-based trip across nearby cities.",
  "Create a weekend getaway under 300 EUR total.",
  "Suggest a workation plan with strong Wi-Fi spots.",
  "Plan a photography-focused trip with golden-hour stops.",
  "Build a no-car itinerary using public transport only.",
  "Plan a 4-day mountain retreat with scenic viewpoints.",
  "Suggest a digital nomad month in a low-cost city.",
  "Create a weekend plan around live music and nightlife.",
  "Build an art and architecture itinerary in one capital.",
  "Plan a quiet wellness trip with spa and nature time.",
  "Suggest a student-friendly trip with minimal daily spend.",
  "Design a long-weekend trip focused on local festivals.",
  "Create a road-trip style plan with short driving legs.",
  "Build a spring itinerary with parks and outdoor cafes.",
  "Plan an autumn escape with cozy food spots.",
  "Suggest a winter sun destination with budget flights.",
  "Create a history-focused route through old towns.",
  "Plan a pet-friendly trip with easy transport options.",
  "Build a couples itinerary with sunset viewpoints.",
  "Suggest a slow-travel week with fewer hotel changes.",
  "Create a museum-heavy itinerary with free-entry days.",
  "Plan a trip that avoids tourist peaks and queues.",
  "Build a weekend plan around local markets and food halls.",
  "Suggest a beach + city combo trip on a tight budget.",
  "Create an island itinerary using ferries only.",
  "Plan a first-time solo Europe trip with safety tips.",
  "Build a low-stress itinerary with midday breaks.",
  "Suggest hidden-gem day trips from a major city.",
  "Create a trip plan optimized for train travel passes.",
  "Plan a one-week food crawl with regional specialties.",
  "Build an itinerary with free walking tours each day.",
  "Suggest an eco-conscious trip with low-carbon transport.",
  "Create a short trip focused on iconic photo locations.",
  "Plan a city break with rooftop bars and cheap eats.",
  "Build a budget itinerary for a group of friends.",
];

function pickInitialRecommendations(): string[] {
  const pool = [...INITIAL_RECOMMENDATION_POOL];
  for (let i = pool.length - 1; i > 0; i -= 1) {
    const j = Math.floor(Math.random() * (i + 1));
    [pool[i], pool[j]] = [pool[j], pool[i]];
  }
  return pool.slice(0, INITIAL_RECOMMENDATION_COUNT);
}

function normalizeError(err: unknown, fallback: string): string {
  if (typeof err === "object" && err && "response" in err) {
    const response = (
      err as {
        response?: {
          data?:
            | string
            | {
                detail?: string;
                gemini_raw_response?: string;
                gemini_raw_response_first_try?: string;
              };
        };
      }
    ).response;
    console.error("AI error response payload:", response?.data);
    const data = response?.data;
    if (data && typeof data === "object" && data.gemini_raw_response) {
      // Keep this for quick browser-console inspection when envelope validation fails.
      console.error("Gemini raw response (retry):", data.gemini_raw_response);
    }
    if (data && typeof data === "object" && data.gemini_raw_response_first_try) {
      console.error("Gemini raw response (first try):", data.gemini_raw_response_first_try);
    }
    if (typeof data === "string") return data;
    return data?.detail ?? fallback;
  }
  return fallback;
}

function parseTripPlanFromContent(content: string): TripPlan | null {
  try {
    const parsed = JSON.parse(content) as unknown;
    return parseTripPlanFromUnknown(parsed);
  } catch {
    return null;
  }
}

function parseTripPlanFromUnknown(raw: unknown): TripPlan | null {
  if (!raw || typeof raw !== "object") return null;
  const parsed = raw as Partial<TripPlan>;
  if (!parsed.trip_title || !parsed.destination || !Array.isArray(parsed.days)) return null;
  return parsed as TripPlan;
}

function stableObject(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(stableObject);
  if (value && typeof value === "object") {
    const sortedEntries = Object.entries(value as Record<string, unknown>)
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([key, val]) => [key, stableObject(val)]);
    return Object.fromEntries(sortedEntries);
  }
  return value;
}

function sameTripPlan(a: TripPlan | null | undefined, b: TripPlan | null | undefined): boolean {
  if (!a || !b) return false;
  return JSON.stringify(stableObject(a)) === JSON.stringify(stableObject(b));
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

function TimelineCard({ plan }: { plan: TripPlan }) {
  const hotelsByNight = getHotelsByNight(plan);
  const hotelByNight = new Map(hotelsByNight.map((entry) => [entry.night, entry]));
  return (
    <div className="mt-3 rounded-xl border border-blue-900/50 bg-slate-800/70 p-3 space-y-3">
      <div>
        <h4 className="text-sm font-semibold text-blue-300">{plan.trip_title}</h4>
        <p className="text-xs text-slate-300">{plan.destination}</p>
        {plan.summary && <p className="text-xs text-slate-400 mt-1">{plan.summary}</p>}
      </div>

      <div className="space-y-3">
        {plan.days.map((day, dayIdx) => (
          <div key={`day-${day.day}`} className="space-y-2">
            <div className="rounded-lg bg-slate-900/50 border border-slate-700 p-2">
              <div className="flex items-center gap-2 text-xs text-slate-300 mb-2">
                <CalendarDays className="w-3.5 h-3.5" />
                <span className="font-medium">Day {day.day}</span>
                {day.date && <span className="text-slate-500">({day.date})</span>}
              </div>

              <ol className="space-y-2">
                {day.items.map((item, idx) => (
                  <li key={`${day.day}-${idx}`} className="rounded-md bg-slate-800/80 p-2">
                    <div className="flex items-center justify-between gap-2">
                      <div className="text-xs text-slate-400">{item.time}</div>
                      <div className="text-[10px] uppercase tracking-wide text-blue-300">{item.category}</div>
                    </div>
                    <p className="text-sm text-white font-medium">{item.title}</p>
                    <p className="text-xs text-slate-300">{item.description}</p>
                    {item.estimated_cost && (
                      <p className="text-[11px] text-emerald-300 mt-1">Est. cost: {item.estimated_cost}</p>
                    )}
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
                <ul className="space-y-2">
                  {hotelByNight.get(day.day)!.options.map((hotel, idx) => (
                    <li key={`${hotel.name}-${day.day}-${idx}`} className="rounded-md bg-slate-800/70 p-2">
                      <p className="text-sm text-white font-medium">{hotel.name}</p>
                      <p className="text-xs text-slate-300">
                        {hotel.area ? `${hotel.area} · ` : ""}
                        {hotel.nightly_estimate ? `~${hotel.nightly_estimate}/night` : "nightly rate not specified"}
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

function SaveTripModal({
  message,
  tripPlan,
  conversationId,
  onClose,
  onSaved,
}: {
  message: string;
  tripPlan?: TripPlan | null;
  conversationId: string | null;
  onClose: () => void;
  onSaved: () => void;
}) {
  const [form, setForm] = useState({
    title: tripPlan?.trip_title ?? "",
    destination: tripPlan?.destination ?? "",
    notes: tripPlan?.summary ?? message,
  });
  const [saving, setSaving] = useState(false);

  const handleSave = async () => {
    if (!form.title.trim() || !form.destination.trim()) return;
    setSaving(true);
    try {
      const payload: Partial<Trip> = {
        title: form.title.trim(),
        destination: form.destination.trim(),
        notes: form.notes.trim(),
        conversation_id: conversationId ?? undefined,
      };
      if (tripPlan) {
        payload.notes = form.notes.trim() || tripPlan.summary || "Generated itinerary";
        payload.itinerary = [tripPlan as unknown as Record<string, unknown>];
      }
      await createTrip(payload);
      onSaved();
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="fixed inset-0 bg-black/60 flex items-center justify-center z-50 p-4">
      <div className="bg-slate-800 border border-slate-600 rounded-2xl shadow-xl w-full max-w-md p-6">
        <h2 className="text-lg font-bold text-white mb-3">Save as Trip</h2>

        <div className="space-y-3">
          <input
            placeholder="Trip title *"
            value={form.title}
            onChange={(e) => setForm((f) => ({ ...f, title: e.target.value }))}
            className="w-full bg-slate-700 text-white placeholder-slate-400 rounded-xl px-4 py-3 text-sm outline-none focus:ring-2 focus:ring-blue-500"
          />
          <input
            placeholder="Destination *"
            value={form.destination}
            onChange={(e) => setForm((f) => ({ ...f, destination: e.target.value }))}
            className="w-full bg-slate-700 text-white placeholder-slate-400 rounded-xl px-4 py-3 text-sm outline-none focus:ring-2 focus:ring-blue-500"
          />
          <textarea
            placeholder="Notes (auto-filled from response)"
            value={form.notes}
            onChange={(e) => setForm((f) => ({ ...f, notes: e.target.value }))}
            rows={4}
            className="w-full bg-slate-700 text-white placeholder-slate-400 rounded-xl px-4 py-3 text-sm outline-none focus:ring-2 focus:ring-blue-500 resize-none"
          />
        </div>
        <div className="flex gap-2 mt-4">
          <button
            onClick={onClose}
            className="flex-1 py-2 text-sm border border-slate-600 rounded-xl text-slate-300 hover:bg-slate-700"
          >
            Cancel
          </button>
          <button
            onClick={handleSave}
            disabled={saving || !form.title.trim() || !form.destination.trim()}
            className="flex-1 py-2 text-sm bg-blue-600 hover:bg-blue-700 disabled:opacity-40 text-white rounded-xl transition"
          >
            {saving ? "Saving..." : "Save Trip"}
          </button>
        </div>
      </div>
    </div>
  );
}

function DeleteConversationModal({
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
        <h3 className="text-lg font-semibold text-white">Delete Conversation?</h3>
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

export default function Chat() {
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [input, setInput] = useState("");
  const [loading, setLoading] = useState(false);
  const [loadingConversationId, setLoadingConversationId] = useState<string | null>(null);
  const [conversationId, setConversationId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [info, setInfo] = useState<string | null>(null);
  const [saveModal, setSaveModal] = useState<SaveModalState | null>(null);
  const [savedIndexes, setSavedIndexes] = useState<Set<number>>(new Set());
  const [linkedTrip, setLinkedTrip] = useState<Trip | null>(null);
  const [updatingIndexes, setUpdatingIndexes] = useState<Set<number>>(new Set());
  const [conversations, setConversations] = useState<Conversation[]>([]);
  const [searchTerm, setSearchTerm] = useState("");
  const [recommendations, setRecommendations] = useState<string[]>(() => pickInitialRecommendations());
  const [mobileHistoryOpen, setMobileHistoryOpen] = useState(false);
  const [retryRequest, setRetryRequest] = useState<RetryRequest | null>(null);
  const [canRetry, setCanRetry] = useState(false);
  const [pendingDeleteConversation, setPendingDeleteConversation] = useState<Conversation | null>(
    null
  );
  const [deletingConversation, setDeletingConversation] = useState(false);
  const [pinnedIds, setPinnedIds] = useState<string[]>(() => {
    try {
      const raw = localStorage.getItem(PINNED_KEY);
      const parsed = raw ? (JSON.parse(raw) as string[]) : [];
      return Array.isArray(parsed) ? parsed : [];
    } catch {
      return [];
    }
  });

  const [searchParams, setSearchParams] = useSearchParams();
  const navigate = useNavigate();
  const bottomRef = useRef<HTMLDivElement>(null);

  const syncConversationParam = useCallback((convId: string | null, replace = true) => {
    const current = searchParams.get("conversation_id");
    const normalizedCurrent = current && current.trim() ? current : null;
    const normalizedNext = convId && convId.trim() ? convId : null;
    if (normalizedCurrent === normalizedNext) return;

    const next = new URLSearchParams(searchParams);
    if (normalizedNext) next.set("conversation_id", normalizedNext);
    else next.delete("conversation_id");
    setSearchParams(next, { replace });
  }, [searchParams, setSearchParams]);

  const persistPinned = (ids: string[]) => {
    setPinnedIds(ids);
    localStorage.setItem(PINNED_KEY, JSON.stringify(ids));
  };

  const togglePinned = (id: string) => {
    const next = pinnedIds.includes(id) ? pinnedIds.filter((p) => p !== id) : [id, ...pinnedIds];
    persistPinned(next);
  };

  const sortedConversations = useMemo(() => {
    const searched = conversations.filter((c) => {
      if (!searchTerm.trim()) return true;
      return (c.title ?? "Untitled conversation")
        .toLowerCase()
        .includes(searchTerm.trim().toLowerCase());
    });

    return [...searched].sort((a, b) => {
      const pinA = pinnedIds.includes(a.id) ? 1 : 0;
      const pinB = pinnedIds.includes(b.id) ? 1 : 0;
      if (pinA !== pinB) return pinB - pinA;
      return (b.updated_at ?? "").localeCompare(a.updated_at ?? "");
    });
  }, [conversations, pinnedIds, searchTerm]);

  const refreshConversations = () => listConversations().then(setConversations).catch(() => {});

  const refreshLinkedTrip = useCallback(async (convId: string | null) => {
    if (!convId) {
      setLinkedTrip(null);
      return;
    }
    try {
      const trips = await listTrips();
      const linked = trips.find((t) => t.conversation_id === convId);
      setLinkedTrip(linked ?? null);
    } catch {
      // Keep non-blocking; save flow still works even if trip lookup fails.
      setLinkedTrip(null);
    }
  }, []);

  const loadConversation = useCallback((convId: string) => {
    syncConversationParam(convId, true);
    setLoadingConversationId(convId);
    setError(null);
    getConversation(convId)
      .then((conv) => {
        const msgs: ChatMessage[] = (conv.messages ?? []).map((m) => {
          const content = m.parts?.[0] ?? "";
          const assistant = m.role === "model";
          return {
            role: assistant ? "assistant" : "user",
            content,
            tripPlan: assistant ? parseTripPlanFromContent(content) : null,
          };
        });
        setMessages(msgs);
        setConversationId(convId);
        setRecommendations(conv.recommendations ?? []);
        setSavedIndexes(new Set());
        refreshLinkedTrip(convId);
        setMobileHistoryOpen(false);
      })
      .catch(() => {
        setError("Conversation could not be loaded.");
      })
      .finally(() => {
        setLoadingConversationId(null);
      });
  }, [refreshLinkedTrip, syncConversationParam]);

  useEffect(() => {
    refreshConversations();
  }, []);

  useEffect(() => {
    const convId = searchParams.get("conversation_id");
    if (!convId || convId === conversationId) return;
    loadConversation(convId);
  }, [searchParams, conversationId, loadConversation]);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages]);

  useEffect(() => {
    if (!info) return;
    const timeout = setTimeout(() => setInfo(null), 3500);
    return () => clearTimeout(timeout);
  }, [info]);

  const startNewChat = () => {
    syncConversationParam(null, true);
    setMessages([]);
    setConversationId(null);
    setError(null);
    setCanRetry(false);
    setRetryRequest(null);
    setRecommendations(pickInitialRecommendations());
    setSavedIndexes(new Set());
    setLinkedTrip(null);
    setMobileHistoryOpen(false);
    setLoadingConversationId(null);
  };

  const handleOverwriteTrip = async (idx: number, plan: TripPlan) => {
    if (!linkedTrip || updatingIndexes.has(idx)) return;
    setUpdatingIndexes((prev) => new Set(prev).add(idx));
    try {
      await updateTrip(linkedTrip.id, {
        title: plan.trip_title || linkedTrip.title,
        destination: plan.destination || linkedTrip.destination,
        notes: plan.summary || linkedTrip.notes,
        itinerary: [plan as unknown as Record<string, unknown>],
        conversation_id: conversationId ?? linkedTrip.conversation_id,
      });
      setSavedIndexes((prev) => new Set(prev).add(idx));
      await refreshLinkedTrip(conversationId ?? linkedTrip.conversation_id ?? null);
      setInfo("Trip itinerary updated.");
    } catch (err) {
      setError(normalizeError(err, "Could not update trip itinerary."));
    } finally {
      setUpdatingIndexes((prev) => {
        const next = new Set(prev);
        next.delete(idx);
        return next;
      });
    }
  };

  const handleSend = async (forcedPrompt?: string) => {
    const sourceText = (forcedPrompt ?? input).trim();
    if (!sourceText || loading) return;

    const userText = sourceText;
    const requestText = userText;

    if (!forcedPrompt) setInput("");
    setError(null);
    setCanRetry(false);
    setMessages((m) => [...m, { role: "user", content: userText }]);
    setLoading(true);
    setRetryRequest({
      requestText,
      conversationId,
    });

    try {
      const res = await sendMessage(requestText, conversationId);

      setConversationId(res.conversation_id);
      syncConversationParam(res.conversation_id, true);
      refreshLinkedTrip(res.conversation_id);
      setMessages((m) => [
        ...m,
        {
          role: "assistant",
          content: res.assistant_message,
          tripPlan: res.trip_plan ?? null,
        },
      ]);
      setRecommendations(res.recommendations);
      setCanRetry(false);
      refreshConversations();
    } catch (err) {
      const status = (err as { response?: { status?: number } }).response?.status;
      const msg =
        status === 429
          ? "Daily AI request limit reached. Please try again tomorrow."
          : normalizeError(err, "Something went wrong. Please try again.");
      setError(msg);
      setCanRetry(status === 502 || status === 503 || status === 504 || !status);
    } finally {
      setLoading(false);
    }
  };

  const handleRetry = async () => {
    if (!retryRequest || loading) return;

    setError(null);
    setLoading(true);
    try {
      const res = await sendMessage(retryRequest.requestText, retryRequest.conversationId);

      setConversationId(res.conversation_id);
      syncConversationParam(res.conversation_id, true);
      refreshLinkedTrip(res.conversation_id);
      setMessages((m) => [
        ...m,
        {
          role: "assistant",
          content: res.assistant_message,
          tripPlan: res.trip_plan ?? null,
        },
      ]);
      setRecommendations(res.recommendations);
      setCanRetry(false);
      refreshConversations();
    } catch (err) {
      const status = (err as { response?: { status?: number } }).response?.status;
      setError(normalizeError(err, "Retry failed. Please try once more."));
      setCanRetry(status === 502 || status === 503 || status === 504 || !status);
    } finally {
      setLoading(false);
    }
  };

  const handleRenameConversation = async (conv: Conversation) => {
    const current = conv.title ?? "";
    const nextTitle = window.prompt("New conversation title", current);
    if (nextTitle === null) return;

    const trimmed = nextTitle.trim();
    if (!trimmed) {
      setError("Title cannot be empty.");
      return;
    }

    try {
      await renameConversation(conv.id, trimmed);
      refreshConversations();
      setInfo("Conversation renamed.");
    } catch (err) {
      setError(normalizeError(err, "Could not rename conversation."));
    }
  };

  const confirmDeleteConversation = async () => {
    if (!pendingDeleteConversation || deletingConversation) return;
    const conv = pendingDeleteConversation;
    setDeletingConversation(true);
    try {
      await deleteConversation(conv.id);
      if (conversationId === conv.id) {
        startNewChat();
      }
      persistPinned(pinnedIds.filter((id) => id !== conv.id));
      refreshConversations();
      setInfo("Conversation deleted.");
    } catch (err) {
      setError(normalizeError(err, "Could not delete conversation."));
    } finally {
      setDeletingConversation(false);
      setPendingDeleteConversation(null);
    }
  };

  return (
    <div className="flex h-full gap-4 relative">
      <div className="flex flex-col flex-1 min-w-0">
        <div className="flex items-center gap-2 flex-wrap mb-3">
          <button
            type="button"
            onClick={() => setMobileHistoryOpen((v) => !v)}
            className="lg:hidden p-2 rounded-lg bg-slate-700 text-slate-200"
            aria-label="Toggle history"
          >
            {mobileHistoryOpen ? <X className="w-4 h-4" /> : <Menu className="w-4 h-4" />}
          </button>
        </div>

        {info && (
          <div className="mb-3 flex items-center gap-2 text-emerald-300 text-xs bg-emerald-900/30 border border-emerald-900 rounded-xl px-3 py-2">
            {info}
          </div>
        )}

        <div className="flex-1 overflow-y-auto space-y-4 pb-4">
          {messages.length === 0 && (
            <div className="text-center text-slate-500 mt-16">
              <Bot className="w-12 h-12 mx-auto mb-3 opacity-50" />
              <p className="text-lg font-medium text-slate-400">Where would you like to go?</p>
              <p className="text-sm mt-1">Ask me anything about travel - destinations, itineraries, hotels, tips.</p>
            </div>
          )}

          {messages.map((msg, i) => (
            <div key={i} className={`flex gap-3 ${msg.role === "user" ? "justify-end" : "justify-start"}`}>
              {msg.role === "assistant" && (
                <div className="bg-blue-600 rounded-full p-2 h-8 w-8 flex items-center justify-center flex-shrink-0">
                  <Bot className="w-4 h-4 text-white" />
                </div>
              )}

              <div className="flex flex-col gap-1 max-w-2xl w-full">
                <div
                  className={`rounded-2xl px-4 py-3 text-sm ${
                    msg.role === "user"
                      ? "bg-blue-600 text-white rounded-br-sm"
                      : "bg-slate-700 text-slate-100 rounded-bl-sm"
                  }`}
                >
                  {msg.role === "assistant" ? (
                    <>
                      {msg.tripPlan ? (
                        <>
                          <p className="text-xs text-blue-200/90 mb-2">
                            Structured timeline generated.
                          </p>
                          <TimelineCard plan={msg.tripPlan} />
                        </>
                      ) : (
                        <div className="prose prose-invert prose-sm max-w-none">
                          <ReactMarkdown>{msg.content}</ReactMarkdown>
                        </div>
                      )}
                    </>
                  ) : (
                    msg.content
                  )}
                </div>

                {msg.role === "assistant" && msg.tripPlan && (
                  <div className="self-start flex items-center gap-2">
                    {(() => {
                      const linkedPlan = parseTripPlanFromUnknown(linkedTrip?.itinerary?.[0]);
                      const isSyncedWithLinkedTrip = sameTripPlan(msg.tripPlan, linkedPlan);
                      // Once a trip is linked, "Saved" must reflect the currently linked itinerary only.
                      const isSaved = linkedTrip ? isSyncedWithLinkedTrip : savedIndexes.has(i);
                      const canOverwrite = !!linkedTrip && !isSaved;
                      const isUpdating = updatingIndexes.has(i);
                      const canRestorePreviousVersion =
                        !!linkedTrip && savedIndexes.has(i) && !isSyncedWithLinkedTrip;

                      if (isSaved) {
                        if (linkedTrip) {
                          return (
                            <button
                              type="button"
                              onClick={() => navigate(`/trips/${linkedTrip.id}`)}
                              className="flex items-center gap-1.5 text-xs px-2.5 py-1 rounded-lg text-green-400 bg-green-900/20 hover:bg-green-900/35"
                              title="Open saved trip"
                            >
                              <BookmarkCheck className="w-3.5 h-3.5" /> Open trip
                              <ArrowUpRight className="w-3.5 h-3.5" />
                            </button>
                          );
                        }

                        return (
                          <button
                            type="button"
                            className="flex items-center gap-1.5 text-xs px-2.5 py-1 rounded-lg text-green-400 bg-green-900/20 cursor-default"
                            title="Saved in trip"
                          >
                            <BookmarkCheck className="w-3.5 h-3.5" /> Saved
                          </button>
                        );
                      }

                      if (canOverwrite) {
                        return (
                          <button
                            type="button"
                            onClick={() => handleOverwriteTrip(i, msg.tripPlan!)}
                            disabled={isUpdating}
                            title={
                              canRestorePreviousVersion
                                ? "Restore this previously saved version"
                                : "Overwrite existing trip itinerary"
                            }
                            className="flex items-center gap-1.5 text-xs px-2.5 py-1 rounded-lg text-amber-300 bg-amber-900/20 hover:bg-amber-900/35 disabled:opacity-60"
                          >
                            {canRestorePreviousVersion ? (
                              <RotateCcw className="w-3.5 h-3.5" />
                            ) : (
                              <Bookmark className="w-3.5 h-3.5" />
                            )}{" "}
                            {isUpdating
                              ? "Updating..."
                              : canRestorePreviousVersion
                                ? "Restore version"
                                : "Update trip"}
                          </button>
                        );
                      }

                      return (
                        <button
                          type="button"
                          onClick={() => setSaveModal({ content: msg.content, index: i, tripPlan: msg.tripPlan })}
                          title="Save as trip"
                          className="flex items-center gap-1.5 text-xs px-2.5 py-1 rounded-lg text-slate-400 hover:text-blue-400 hover:bg-slate-700"
                        >
                          <Bookmark className="w-3.5 h-3.5" /> Save as trip
                        </button>
                      );
                    })()}
                    <button
                      type="button"
                      onClick={() => {
                        const markdown = formatTripPlanMarkdown(msg.tripPlan!);
                        downloadTripMarkdown(markdown, msg.tripPlan!.trip_title);
                        setInfo("Itinerary exported as Markdown.");
                      }}
                      className="flex items-center gap-1.5 text-xs px-2.5 py-1 rounded-lg text-slate-400 hover:text-blue-400 hover:bg-slate-700"
                      title="Export itinerary as Markdown"
                    >
                      <Download className="w-3.5 h-3.5" /> Export .md
                    </button>
                  </div>
                )}
              </div>

              {msg.role === "user" && (
                <div className="bg-slate-600 rounded-full p-2 h-8 w-8 flex items-center justify-center flex-shrink-0">
                  <User className="w-4 h-4 text-white" />
                </div>
              )}
            </div>
          ))}

          {loading && (
            <div className="flex gap-3">
              <div className="bg-blue-600 rounded-full p-2 h-8 w-8 flex items-center justify-center">
                <Bot className="w-4 h-4 text-white" />
              </div>
              <div className="bg-slate-700 rounded-2xl rounded-bl-sm px-4 py-3">
                <div className="flex gap-1">
                  {[0, 1, 2].map((i) => (
                    <div
                      key={i}
                      className="w-2 h-2 bg-slate-400 rounded-full animate-bounce"
                      style={{ animationDelay: `${i * 0.15}s` }}
                    />
                  ))}
                </div>
              </div>
            </div>
          )}

          {error && (
            <div className="flex items-center justify-between gap-3 text-red-400 text-sm bg-red-900/20 rounded-xl px-4 py-3">
              <div className="flex items-center gap-2">
                <AlertCircle className="w-4 h-4 flex-shrink-0" /> {error}
              </div>
              {canRetry && (
                <button
                  type="button"
                  onClick={handleRetry}
                  disabled={loading}
                  className="inline-flex items-center gap-1.5 rounded-lg border border-red-400/30 px-3 py-1.5 text-xs text-red-300 hover:bg-red-900/30 disabled:opacity-50"
                >
                  <RotateCcw className="w-3.5 h-3.5" />
                  Retry
                </button>
              )}
            </div>
          )}

          <div ref={bottomRef} />
        </div>

        {!loading && recommendations.length > 0 && (
          <div className="relative z-20 -mb-3 pt-1 overflow-x-auto overflow-y-hidden pb-2 recommendations-scroll">
            <div className="flex w-max min-w-full gap-2 whitespace-nowrap pr-1">
            {recommendations.map((prompt) => (
              <button
                key={prompt}
                type="button"
                onClick={() => handleSend(prompt)}
                disabled={loading}
                className="shrink-0 text-xs px-3 py-1.5 rounded-full bg-slate-700 text-slate-300 hover:bg-slate-600"
                title={prompt}
              >
                <span className="inline-flex items-center gap-1">
                  <Sparkles className="w-3 h-3 flex-shrink-0" />
                  <span>{prompt}</span>
                </span>
              </button>
            ))}
            </div>
          </div>
        )}

        <div className="relative z-10 pt-1">
          <div className="mb-2 h-px bg-gradient-to-r from-transparent via-slate-500/55 to-transparent" />
          <div className="flex gap-3">
            <input
              value={input}
              onChange={(e) => setInput(e.target.value)}
              onKeyDown={(e) => e.key === "Enter" && !e.shiftKey && handleSend()}
              placeholder="Ask about destinations, itineraries, hotels..."
              className="flex-1 bg-slate-700 text-white placeholder-slate-400 rounded-xl px-4 py-3 text-sm outline-none focus:ring-2 focus:ring-blue-500"
            />
            <button
              onClick={() => handleSend()}
              disabled={loading || !input.trim()}
              className="bg-blue-600 hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed text-white rounded-xl px-4 py-3 transition"
            >
              <Send className="w-5 h-5" />
            </button>
          </div>
        </div>
      </div>

      <aside
        className={`${mobileHistoryOpen ? "flex" : "hidden"} lg:flex w-full lg:w-72 flex-col border border-slate-700 lg:border-l lg:border-t-0 rounded-xl lg:rounded-none lg:pl-4 p-3 lg:p-0 shrink-0 bg-slate-900/95 lg:bg-transparent absolute lg:static inset-4 lg:inset-auto z-40`}
      >
        <div className="flex items-center gap-2 mb-3">
          <button
            onClick={startNewChat}
            className="flex items-center justify-center gap-2 flex-1 bg-slate-700 hover:bg-slate-600 text-white text-sm font-medium px-3 py-2.5 rounded-xl transition"
          >
            <Plus className="w-4 h-4" /> New chat
          </button>
          <button
            type="button"
            onClick={() => setMobileHistoryOpen(false)}
            className="lg:hidden p-2 rounded-lg bg-slate-700 text-slate-200"
            aria-label="Close history"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        <input
          value={searchTerm}
          onChange={(e) => setSearchTerm(e.target.value)}
          placeholder="Search history"
          className="w-full mb-3 bg-slate-800 border border-slate-700 text-slate-200 rounded-lg px-3 py-2 text-sm outline-none"
        />

        <p className="text-xs text-slate-500 font-medium uppercase tracking-wide mb-2 px-1">History</p>

        <div className="flex-1 overflow-y-auto space-y-1">
          {sortedConversations.length === 0 && <p className="text-xs text-slate-600 px-1 mt-2">No conversations yet.</p>}

          {sortedConversations.map((conv) => {
            const loadingRow = conv.id === loadingConversationId;
            const active = conv.id === conversationId || loadingRow;
            const pinned = pinnedIds.includes(conv.id);
            const conversationTitle = conv.title || "Untitled conversation";
            return (
              <div
                key={conv.id}
                className={`group flex items-center gap-1 rounded-lg border px-1.5 py-1 ${
                  active ? "border-blue-500 bg-slate-700" : "border-transparent hover:border-slate-700 hover:bg-slate-800/60"
                }`}
              >
                <button
                  type="button"
                  onClick={() => loadConversation(conv.id)}
                  className="min-w-0 flex-1 text-left px-1 py-1.5 text-sm text-slate-300 rounded-md flex items-center gap-2"
                >
                  {loadingRow ? (
                    <Loader2 className="w-3.5 h-3.5 opacity-80 flex-shrink-0 animate-spin" />
                  ) : (
                    <MessageSquare className="w-3.5 h-3.5 opacity-70 flex-shrink-0" />
                  )}
                  <span className="truncate" title={conversationTitle}>
                    {conversationTitle}
                  </span>
                  {loadingRow && <span className="text-[11px] text-blue-300 flex-shrink-0">Loading…</span>}
                </button>

                <div className="flex items-center gap-0.5">
                  <button
                    type="button"
                    onClick={() => togglePinned(conv.id)}
                    className={`p-1.5 rounded hover:bg-slate-700 transition-opacity ${
                      pinned
                        ? "text-amber-400 opacity-100"
                        : active
                          ? "text-slate-400 opacity-100 hover:text-amber-400"
                          : "text-slate-400 opacity-0 group-hover:opacity-100 hover:text-amber-400"
                    }`}
                    aria-label="Pin conversation"
                    title={pinned ? "Unpin" : "Pin"}
                  >
                    <Pin className="w-3.5 h-3.5" />
                  </button>
                  <div
                    className={`flex items-center gap-0.5 transition-opacity ${
                      active ? "opacity-100" : "opacity-0 group-hover:opacity-100"
                    }`}
                  >
                  <button
                    type="button"
                    onClick={() => handleRenameConversation(conv)}
                    className="p-1.5 rounded text-slate-400 hover:text-blue-400 hover:bg-slate-700"
                    aria-label="Rename conversation"
                    title="Rename"
                  >
                    <Pencil className="w-3.5 h-3.5" />
                  </button>
                  <button
                    type="button"
                    onClick={() => setPendingDeleteConversation(conv)}
                    className="p-1.5 rounded text-slate-400 hover:text-red-400 hover:bg-slate-700"
                    aria-label="Delete conversation"
                    title="Delete"
                  >
                    <Trash2 className="w-3.5 h-3.5" />
                  </button>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      </aside>

      {saveModal && (
        <SaveTripModal
          message={saveModal.content}
          tripPlan={saveModal.tripPlan}
          conversationId={conversationId}
          onClose={() => setSaveModal(null)}
          onSaved={() => {
            setSavedIndexes((prev) => new Set(prev).add(saveModal.index));
            refreshLinkedTrip(conversationId);
            setSaveModal(null);
            setInfo("Trip saved.");
          }}
        />
      )}
      {pendingDeleteConversation && (
        <DeleteConversationModal
          title={pendingDeleteConversation.title || "Untitled conversation"}
          deleting={deletingConversation}
          onCancel={() => {
            if (deletingConversation) return;
            setPendingDeleteConversation(null);
          }}
          onConfirm={confirmDeleteConversation}
        />
      )}
    </div>
  );
}
