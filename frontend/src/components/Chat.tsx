import { useState, useRef, useEffect } from "react";
import { useSearchParams } from "react-router-dom";
import { sendMessage, getConversation, listConversations, createTrip } from "../services/api";
import { Send, Bot, User, AlertCircle, Bookmark, BookmarkCheck, Plus, MessageSquare } from "lucide-react";
import ReactMarkdown from "react-markdown";
import type { Conversation } from "../types";

interface ChatMessage {
  role: "user" | "assistant";
  content: string;
}

interface SaveModalState {
  content: string;
  index: number;
}

function SaveTripModal({
  message,
  conversationId,
  onClose,
  onSaved,
}: {
  message: string;
  conversationId: string | null;
  onClose: () => void;
  onSaved: () => void;
}) {
  const [form, setForm] = useState({ title: "", destination: "", notes: message });
  const [saving, setSaving] = useState(false);

  const handleSave = async () => {
    if (!form.title.trim() || !form.destination.trim()) return;
    setSaving(true);
    try {
      await createTrip({ ...form, conversation_id: conversationId ?? undefined });
      onSaved();
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="fixed inset-0 bg-black/60 flex items-center justify-center z-50 p-4">
      <div className="bg-slate-800 border border-slate-600 rounded-2xl shadow-xl w-full max-w-md p-6">
        <h2 className="text-lg font-bold text-white mb-4">Save as Trip</h2>
        <div className="space-y-3">
          <input
            placeholder="Trip title *"
            value={form.title}
            onChange={e => setForm(f => ({ ...f, title: e.target.value }))}
            className="w-full bg-slate-700 text-white placeholder-slate-400 rounded-xl px-4 py-3 text-sm outline-none focus:ring-2 focus:ring-blue-500"
          />
          <input
            placeholder="Destination *"
            value={form.destination}
            onChange={e => setForm(f => ({ ...f, destination: e.target.value }))}
            className="w-full bg-slate-700 text-white placeholder-slate-400 rounded-xl px-4 py-3 text-sm outline-none focus:ring-2 focus:ring-blue-500"
          />
          <textarea
            placeholder="Notes (auto-filled from response)"
            value={form.notes}
            onChange={e => setForm(f => ({ ...f, notes: e.target.value }))}
            rows={4}
            className="w-full bg-slate-700 text-white placeholder-slate-400 rounded-xl px-4 py-3 text-sm outline-none focus:ring-2 focus:ring-blue-500 resize-none"
          />
        </div>
        <div className="flex gap-2 mt-4">
          <button onClick={onClose} className="flex-1 py-2 text-sm border border-slate-600 rounded-xl text-slate-300 hover:bg-slate-700">
            Cancel
          </button>
          <button
            onClick={handleSave}
            disabled={saving || !form.title.trim() || !form.destination.trim()}
            className="flex-1 py-2 text-sm bg-blue-600 hover:bg-blue-700 disabled:opacity-40 text-white rounded-xl transition"
          >
            {saving ? "Saving…" : "Save Trip"}
          </button>
        </div>
      </div>
    </div>
  );
}

export default function Chat() {
  const [messages, setMessages]             = useState<ChatMessage[]>([]);
  const [input, setInput]                   = useState("");
  const [loading, setLoading]               = useState(false);
  const [conversationId, setConversationId] = useState<string | null>(null);
  const [error, setError]                   = useState<string | null>(null);
  const [saveModal, setSaveModal]           = useState<SaveModalState | null>(null);
  const [savedIndexes, setSavedIndexes]     = useState<Set<number>>(new Set());
  const [conversations, setConversations]   = useState<Conversation[]>([]);
  const bottomRef                           = useRef<HTMLDivElement>(null);
  const [searchParams]                      = useSearchParams();

  const refreshConversations = () =>
    listConversations().then(setConversations).catch(() => {});

  useEffect(() => { refreshConversations(); }, []);

  useEffect(() => {
    const convId = searchParams.get("conversation_id");
    if (!convId) return;
    loadConversation(convId);
  }, []);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages]);

  const loadConversation = (convId: string) => {
    getConversation(convId).then(conv => {
      const msgs: ChatMessage[] = (conv.messages ?? []).map(m => ({
        role: m.role === "model" ? "assistant" : "user",
        content: m.parts?.[0] ?? "",
      }));
      setMessages(msgs);
      setConversationId(convId);
      setSavedIndexes(new Set());
    }).catch(() => {});
  };

  const startNewChat = () => {
    setMessages([]);
    setConversationId(null);
    setError(null);
    setSavedIndexes(new Set());
  };

  const handleSend = async () => {
    if (!input.trim() || loading) return;
    const userText = input.trim();
    setInput("");
    setError(null);
    setMessages((m) => [...m, { role: "user", content: userText }]);
    setLoading(true);

    try {
      const res = await sendMessage(userText, conversationId);
      setConversationId(res.conversation_id);
      setMessages((m) => [...m, { role: "assistant", content: res.assistant_message }]);
      refreshConversations();
    } catch (err) {
      const status = (err as { response?: { status?: number } }).response?.status;
      const msg = status === 429
        ? "Daily AI request limit reached. Please try again tomorrow."
        : "Something went wrong. Please try again.";
      setError(msg);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="flex h-full gap-4">
      {/* Main chat */}
      <div className="flex flex-col flex-1 min-w-0">
        <div className="flex-1 overflow-y-auto space-y-4 pb-4">
          {messages.length === 0 && (
            <div className="text-center text-slate-500 mt-16">
              <Bot className="w-12 h-12 mx-auto mb-3 opacity-50" />
              <p className="text-lg font-medium text-slate-400">Where would you like to go?</p>
              <p className="text-sm mt-1">Ask me anything about travel — destinations, itineraries, hotels, tips.</p>
            </div>
          )}
          {messages.map((msg, i) => (
            <div key={i} className={`flex gap-3 ${msg.role === "user" ? "justify-end" : "justify-start"}`}>
              {msg.role === "assistant" && (
                <div className="bg-blue-600 rounded-full p-2 h-8 w-8 flex items-center justify-center flex-shrink-0">
                  <Bot className="w-4 h-4 text-white" />
                </div>
              )}
              <div className="flex flex-col gap-1 max-w-2xl">
                <div className={`rounded-2xl px-4 py-3 text-sm
                  ${msg.role === "user"
                    ? "bg-blue-600 text-white rounded-br-sm"
                    : "bg-slate-700 text-slate-100 rounded-bl-sm"}`}>
                  {msg.role === "assistant"
                    ? <div className="prose prose-invert prose-sm max-w-none"><ReactMarkdown>{msg.content}</ReactMarkdown></div>
                    : msg.content}
                </div>
                {msg.role === "assistant" && (
                  <button
                    onClick={() => savedIndexes.has(i) ? undefined : setSaveModal({ content: msg.content, index: i })}
                    title={savedIndexes.has(i) ? "Saved to trips" : "Save as trip"}
                    className={`self-start flex items-center gap-1.5 text-xs px-2.5 py-1 rounded-lg transition
                      ${savedIndexes.has(i)
                        ? "text-green-400 bg-green-900/20 cursor-default"
                        : "text-slate-400 hover:text-blue-400 hover:bg-slate-700"}`}
                  >
                    {savedIndexes.has(i)
                      ? <><BookmarkCheck className="w-3.5 h-3.5" /> Saved</>
                      : <><Bookmark className="w-3.5 h-3.5" /> Save as trip</>}
                  </button>
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
                  {[0, 1, 2].map(i => (
                    <div key={i} className="w-2 h-2 bg-slate-400 rounded-full animate-bounce"
                      style={{ animationDelay: `${i * 0.15}s` }} />
                  ))}
                </div>
              </div>
            </div>
          )}
          {error && (
            <div className="flex items-center gap-2 text-red-400 text-sm bg-red-900/20 rounded-xl px-4 py-3">
              <AlertCircle className="w-4 h-4 flex-shrink-0" /> {error}
            </div>
          )}
          <div ref={bottomRef} />
        </div>

        {/* Input */}
        <div className="flex gap-3 pt-3 border-t border-slate-700">
          <input
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onKeyDown={(e) => e.key === "Enter" && !e.shiftKey && handleSend()}
            placeholder="Ask about destinations, itineraries, hotels..."
            className="flex-1 bg-slate-700 text-white placeholder-slate-400 rounded-xl px-4 py-3 text-sm outline-none focus:ring-2 focus:ring-blue-500"
          />
          <button
            onClick={handleSend}
            disabled={loading || !input.trim()}
            className="bg-blue-600 hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed text-white rounded-xl px-4 py-3 transition"
          >
            <Send className="w-5 h-5" />
          </button>
        </div>
      </div>

      {/* Right sidebar */}
      <aside className="w-60 flex flex-col border-l border-slate-700 pl-4 shrink-0">
        <button
          onClick={startNewChat}
          className="flex items-center gap-2 w-full bg-slate-700 hover:bg-slate-600 text-white text-sm font-medium px-3 py-2.5 rounded-xl transition mb-3"
        >
          <Plus className="w-4 h-4" /> New chat
        </button>

        <p className="text-xs text-slate-500 font-medium uppercase tracking-wide mb-2 px-1">History</p>

        <div className="flex-1 overflow-y-auto space-y-1">
          {conversations.length === 0 && (
            <p className="text-xs text-slate-600 px-1 mt-2">No conversations yet.</p>
          )}
          {conversations.map(conv => (
            <button
              key={conv.id}
              onClick={() => loadConversation(conv.id)}
              className={`w-full text-left flex items-start gap-2 px-3 py-2.5 rounded-xl text-sm transition group
                ${conv.id === conversationId
                  ? "bg-blue-600/20 text-blue-300"
                  : "text-slate-400 hover:bg-slate-700 hover:text-slate-200"}`}
            >
              <MessageSquare className="w-3.5 h-3.5 mt-0.5 shrink-0 opacity-60" />
              <span className="line-clamp-2 leading-snug">
                {conv.title ?? "Untitled chat"}
              </span>
            </button>
          ))}
        </div>
      </aside>

      {saveModal && (
        <SaveTripModal
          message={saveModal.content}
          conversationId={conversationId}
          onClose={() => setSaveModal(null)}
          onSaved={() => {
            setSavedIndexes(prev => new Set([...prev, saveModal.index]));
            setSaveModal(null);
          }}
        />
      )}
    </div>
  );
}
