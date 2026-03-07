import { useState, useRef, useEffect } from "react";
import { sendMessage } from "../services/api";
import { Send, Bot, User, AlertCircle } from "lucide-react";

export default function Chat() {
  const [messages, setMessages]             = useState([]);
  const [input, setInput]                   = useState("");
  const [loading, setLoading]               = useState(false);
  const [conversationId, setConversationId] = useState(null);
  const [error, setError]                   = useState(null);
  const bottomRef                           = useRef(null);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages]);

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
    } catch (err) {
      const msg = err.response?.status === 429
        ? "Daily AI request limit reached. Please try again tomorrow."
        : "Something went wrong. Please try again.";
      setError(msg);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="flex flex-col h-[calc(100vh-80px)]">
      {/* Messages */}
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
            <div className={`max-w-2xl rounded-2xl px-4 py-3 text-sm whitespace-pre-wrap
              ${msg.role === "user"
                ? "bg-blue-600 text-white rounded-br-sm"
                : "bg-slate-700 text-slate-100 rounded-bl-sm"}`}>
              {msg.content}
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
                {[0,1,2].map(i => (
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
  );
}
