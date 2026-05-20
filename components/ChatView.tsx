"use client";
import { useState, useRef, useEffect, useMemo } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { Send, Sparkles, Paperclip, MoreVertical, ChevronLeft, X, Smile, Mic } from "lucide-react";
import { Agent } from "@/lib/agents";
import { COLOR_MAP } from "@/lib/theme";
import AgentAvatar from "./AgentAvatar";
import { useVoiceInput } from "@/lib/useVoiceInput";

interface Msg {
  id: number;
  role: "user" | "assistant" | "system";
  text: string;
  ts: Date;
}

const dayLabel = (d: Date) => {
  const now = new Date();
  const isToday = d.toDateString() === now.toDateString();
  const yest = new Date(now); yest.setDate(now.getDate() - 1);
  const isYesterday = d.toDateString() === yest.toDateString();
  if (isToday) return "TODAY";
  if (isYesterday) return "YESTERDAY";
  return d.toLocaleDateString("en-US", { weekday: "long", month: "short", day: "numeric" }).toUpperCase();
};

const timeLabel = (d: Date) => d.toLocaleTimeString("en-US", { hour: "numeric", minute: "2-digit", hour12: false });

export default function ChatView({
  agent,
  onBack,
  embedded = false,
}: {
  agent: Agent;
  onBack?: () => void;
  embedded?: boolean;
}) {
  const c = COLOR_MAP[agent.color];
  const [text, setText] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [messages, setMessages] = useState<Msg[]>(() => [
    { id: 1, role: "assistant", text: agent.greeting, ts: new Date(Date.now() - 30000) },
  ]);
  const endRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLTextAreaElement>(null);
  const abortRef = useRef<AbortController | null>(null);
  const idCounter = useRef(2);

  // voice input (browser Web Speech API)
  const voice = useVoiceInput();
  // when finalized speech arrives, append it into the textarea
  useEffect(() => {
    if (voice.transcript) {
      setText(prev => (prev ? prev.replace(/\s+$/, "") + " " : "") + voice.transcript);
    }
  }, [voice.transcript]);
  // surface voice errors in the same error banner
  useEffect(() => {
    if (voice.error) setError(voice.error);
  }, [voice.error]);


  // suggested starters per agent
  const suggestions = useMemo(() => {
    const base: Record<string, string[]> = {
      "claude-prime": ["Plan a mission to audit our auth surface", "Summarize the day's agent activity", "What should I prioritize this week?"],
      "scout-01":     ["Research the latest in quantum error correction", "Verify the claim that GPT-5 has tool use", "Find primary sources on this paper"],
      "forge-02":     ["Refactor /src/auth to OAuth 2.1", "Build a Redis-backed session store", "Review my React component for perf"],
      "archive-03":   ["Index this conversation", "Find anything we discussed about Postgres", "Summarize the past week's missions"],
      "weaver-04":    ["Decompose 'launch the beta' into steps", "Wire a 4-agent research pipeline", "Plan a nightly eval cron"],
      "sentry-05":    ["Audit this code for vulnerabilities", "Check this draft for factual claims", "Run a safety eval on agent output"],
    };
    return base[agent.id] || base["claude-prime"];
  }, [agent.id]);

  useEffect(() => {
    endRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages, busy]);

  useEffect(() => {
    inputRef.current?.focus();
  }, [agent.id]);

  const dispatch = async (q: string) => {
    if (!q.trim() || busy) return;
    setError(null);

    const userMsg: Msg = { id: idCounter.current++, role: "user", text: q, ts: new Date() };
    setMessages(prev => [...prev, userMsg]);
    setText("");
    setBusy(true);

    // build API messages from current chat history (excluding system messages)
    const apiMessages = [...messages, userMsg]
      .filter(m => m.role === "user" || m.role === "assistant")
      .map(m => ({ role: m.role as "user" | "assistant", content: m.text }));

    // create placeholder assistant message
    const assistantId = idCounter.current++;
    let streamedText = "";
    setMessages(prev => [...prev, { id: assistantId, role: "assistant", text: "", ts: new Date() }]);

    abortRef.current?.abort();
    const ctrl = new AbortController();
    abortRef.current = ctrl;

    try {
      let activeProjectId: string | null = null;
      try { activeProjectId = localStorage.getItem("aegis_active_project"); } catch {}
      const res = await fetch("/api/claude", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ agentId: agent.id, messages: apiMessages, activeProjectId }),
        signal: ctrl.signal,
      });

      if (!res.ok || !res.body) {
        const errBody = await res.json().catch(() => ({}));
        throw new Error(errBody.error || `HTTP ${res.status}`);
      }

      const reader = res.body.getReader();
      const decoder = new TextDecoder();
      let buffer = "";

      while (true) {
        const { value, done } = await reader.read();
        if (done) break;
        buffer += decoder.decode(value, { stream: true });
        const events = buffer.split("\n\n");
        buffer = events.pop() || "";
        for (const ev of events) {
          const lines = ev.split("\n");
          let event = "message", data = "";
          for (const line of lines) {
            if (line.startsWith("event:")) event = line.slice(6).trim();
            else if (line.startsWith("data:")) data += line.slice(5).trim();
          }
          if (!data) continue;
          try {
            const parsed = JSON.parse(data);
            if (event === "delta" && parsed.text) {
              streamedText += parsed.text;
              setMessages(prev => prev.map(m =>
                m.id === assistantId ? { ...m, text: m.text + parsed.text } : m
              ));
            } else if (event === "error") {
              throw new Error(parsed.message);
            }
          } catch (parseErr: any) {
            if (parseErr?.message && event === "error") throw parseErr;
          }
        }
      }
    } catch (err: any) {
      if (err.name === "AbortError") return;
      setError(err.message);
      setMessages(prev => prev.map(m =>
        m.id === assistantId && !m.text ? { ...m, text: `[connection error] ${err.message}` } : m
      ));
    } finally {
      setBusy(false);
      // Auto-save the exchange to the Obsidian vault (fire-and-forget, only if we got a response)
      if (streamedText.trim()) {
        fetch("/api/vault", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            kind: "chat",
            agentId: agent.id,
            agentName: agent.name,
            userText: q,
            agentText: streamedText,
          }),
        }).catch(() => { /* vault save is best-effort */ });
      }
    }
  };

  // group messages by day
  const grouped = useMemo(() => {
    const groups: { day: string; msgs: Msg[] }[] = [];
    messages.forEach(m => {
      const day = dayLabel(m.ts);
      const lastGroup = groups[groups.length - 1];
      if (lastGroup && lastGroup.day === day) {
        lastGroup.msgs.push(m);
      } else {
        groups.push({ day, msgs: [m] });
      }
    });
    return groups;
  }, [messages]);

  return (
    <div className={`flex flex-col ${embedded ? "h-full" : "h-[calc(100vh-160px)]"} bg-[#0a0a0a] border border-white/[0.06] rounded-2xl overflow-hidden`}>
      {/* HEADER */}
      <header className="flex items-center gap-3 px-5 py-3.5 border-b border-white/[0.06] bg-black/40 backdrop-blur-xl">
        {onBack && (
          <button onClick={onBack}
            className="md:hidden h-8 w-8 grid place-items-center rounded-full hover:bg-white/5 text-white/60 hover:text-white">
            <ChevronLeft className="h-4 w-4" />
          </button>
        )}
        <AgentAvatar agentId={agent.id} size={40} />
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2">
            <div className="font-display text-[15px] text-white font-medium truncate">{agent.name}</div>
            <span className="font-mono text-[9px] tracking-[0.2em] px-1.5 py-0.5 rounded" style={{ background: c.soft, color: c.hex }}>
              {agent.model.replace("claude-", "")}
            </span>
          </div>
          <div className="flex items-center gap-1.5 text-[11px] text-white/50">
            <motion.span className="h-1.5 w-1.5 rounded-full"
              style={{ background: agent.status === "online" ? "#34d399" : agent.status === "idle" ? "#f5b400" : "#94a3b8" }}
              animate={{ opacity: [1, 0.4, 1] }} transition={{ duration: 1.8, repeat: Infinity }} />
            <span className="capitalize">{agent.status}</span>
            <span className="text-white/20">·</span>
            <span className="truncate">{agent.role}</span>
          </div>
        </div>
        <button className="h-8 w-8 grid place-items-center rounded-full hover:bg-white/5 text-white/40 hover:text-white">
          <MoreVertical className="h-4 w-4" strokeWidth={1.5} />
        </button>
      </header>

      {/* MESSAGES */}
      <div className="flex-1 overflow-y-auto px-4 md:px-6 py-6 space-y-1 relative">
        {/* subtle ambient gradient for this agent's color */}
        <div className="absolute inset-0 pointer-events-none opacity-30"
          style={{ background: `radial-gradient(ellipse 80% 30% at 50% 0%, ${c.soft}, transparent 70%)` }} />

        <div className="relative">
          {grouped.map((group, gi) => (
            <div key={`${group.day}-${gi}`}>
              <div className="flex items-center gap-3 my-5">
                <div className="flex-1 h-px bg-white/[0.06]" />
                <span className="font-mono text-[9px] tracking-[0.3em] text-white/30">{group.day}</span>
                <div className="flex-1 h-px bg-white/[0.06]" />
              </div>

              <div className="space-y-3">
                {group.msgs.map((m, mi) => {
                  const isLast = mi === group.msgs.length - 1 && gi === grouped.length - 1;
                  const isStreaming = isLast && busy && m.role === "assistant";
                  const showAvatar =
                    m.role === "assistant" &&
                    (mi === 0 || group.msgs[mi - 1].role !== "assistant");

                  return (
                    <MessageBubble
                      key={m.id}
                      msg={m}
                      agent={agent}
                      showAvatar={showAvatar}
                      isStreaming={isStreaming}
                    />
                  );
                })}
              </div>
            </div>
          ))}

          {/* typing indicator when busy and last assistant msg is empty */}
          {busy && messages[messages.length - 1]?.role === "assistant" && !messages[messages.length - 1]?.text && (
            <motion.div
              initial={{ opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }}
              className="flex items-end gap-2.5 mt-1"
            >
              <AgentAvatar agentId={agent.id} size={32} />
              <div className="px-4 py-3 rounded-2xl rounded-bl-md" style={{ background: c.soft, border: `1px solid ${c.hex}22` }}>
                <div className="flex items-center gap-1">
                  {[0, 1, 2].map(i => (
                    <motion.span key={i} className="h-1.5 w-1.5 rounded-full"
                      style={{ background: c.hex }}
                      animate={{ y: [0, -4, 0], opacity: [0.4, 1, 0.4] }}
                      transition={{ duration: 0.8, repeat: Infinity, delay: i * 0.15 }} />
                  ))}
                </div>
              </div>
            </motion.div>
          )}

          <div ref={endRef} />
        </div>
      </div>

      {/* SUGGESTIONS */}
      {messages.length <= 1 && !busy && (
        <motion.div
          initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }}
          className="px-5 pb-3 flex flex-wrap gap-1.5"
        >
          {suggestions.map((s, i) => (
            <motion.button
              key={s}
              initial={{ opacity: 0, scale: 0.95 }} animate={{ opacity: 1, scale: 1 }}
              transition={{ delay: i * 0.06 }}
              onClick={() => dispatch(s)}
              className="text-[12px] px-3 py-1.5 rounded-full border border-white/10 text-white/70 hover:text-white hover:border-white/30 transition-colors flex items-center gap-1.5"
            >
              <Sparkles className="h-3 w-3" style={{ color: c.hex }} strokeWidth={1.5} />
              {s}
            </motion.button>
          ))}
        </motion.div>
      )}

      {/* ERROR */}
      {error && (
        <motion.div initial={{ height: 0, opacity: 0 }} animate={{ height: "auto", opacity: 1 }}
          className="border-t border-rose-400/30 bg-rose-400/[0.06] px-5 py-2 font-mono text-[11px] text-rose-300 flex items-center justify-between">
          <span>{error.includes("API_KEY")
            ? "ANTHROPIC_API_KEY not set. Copy .env.local.example → .env.local and add your key."
            : error}
          </span>
          <button onClick={() => setError(null)}><X className="h-3 w-3" /></button>
        </motion.div>
      )}

      {/* COMPOSER */}
      <div className="border-t border-white/[0.06] bg-black/30 px-3 md:px-5 py-3">
        <div className="flex items-end gap-2 rounded-2xl bg-white/[0.03] border border-white/10 focus-within:border-white/30 transition-colors px-3 py-2">
          <button className="h-8 w-8 grid place-items-center rounded-full hover:bg-white/5 text-white/40 hover:text-white shrink-0">
            <Paperclip className="h-4 w-4" strokeWidth={1.5} />
          </button>
          <textarea
            ref={inputRef}
            value={text}
            onChange={(e) => setText(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === "Enter" && !e.shiftKey) {
                e.preventDefault();
                dispatch(text);
              }
            }}
            placeholder={voice.listening ? (voice.interim || "Listening…") : `Message ${agent.shortName}…`}
            rows={1}
            disabled={busy}
            className="flex-1 bg-transparent resize-none text-[14px] text-white placeholder-white/30 outline-none py-1.5 max-h-32 leading-relaxed disabled:opacity-50"
            style={{ minHeight: "28px" }}
          />
          {voice.supported && (
            <motion.button
              onClick={() => (voice.listening ? voice.stop() : voice.start())}
              whileTap={{ scale: 0.9 }}
              aria-label={voice.listening ? "Stop voice input" : "Start voice input"}
              title={voice.listening ? "Stop listening" : "Speak your message"}
              className="relative h-8 w-8 grid place-items-center rounded-full shrink-0 transition-colors"
              style={voice.listening
                ? { background: c.hex, color: "#000", boxShadow: `0 0 14px ${c.glow}` }
                : { background: "transparent", color: "rgba(255,255,255,0.4)" }}
            >
              {voice.listening
                ? <Mic className="h-4 w-4" strokeWidth={2} />
                : <Mic className="h-4 w-4" strokeWidth={1.5} />}
              {voice.listening && (
                <>
                  <motion.span
                    className="absolute inset-0 rounded-full pointer-events-none"
                    style={{ border: `2px solid ${c.hex}` }}
                    animate={{ scale: [1, 1.6, 1], opacity: [0.6, 0, 0.6] }}
                    transition={{ duration: 1.4, repeat: Infinity }}
                  />
                </>
              )}
            </motion.button>
          )}
          <button
            aria-label="Emoji"
            className="h-8 w-8 grid place-items-center rounded-full hover:bg-white/5 text-white/40 hover:text-white shrink-0">
            <Smile className="h-4 w-4" strokeWidth={1.5} />
          </button>
          <motion.button
            onClick={() => dispatch(text)}
            disabled={!text.trim() || busy}
            whileTap={{ scale: 0.92 }}
            className="h-8 w-8 grid place-items-center rounded-full shrink-0 transition-opacity disabled:opacity-30"
            style={{ background: c.hex, color: "#000", boxShadow: text.trim() && !busy ? `0 0 14px ${c.glow}` : "none" }}
          >
            <Send className="h-3.5 w-3.5" strokeWidth={2.5} />
          </motion.button>
        </div>
        <div className="flex items-center justify-between mt-1.5 px-3 text-[10px] text-white/30 font-mono">
          <span>{voice.supported ? "↵ to send · ⇧↵ for newline · 🎤 mic for voice" : "↵ to send · ⇧↵ for newline"}</span>
          <span className="tracking-[0.2em]">END-TO-END · TLS 1.3</span>
        </div>
      </div>
    </div>
  );
}

function MessageBubble({
  msg, agent, showAvatar, isStreaming,
}: {
  msg: Msg; agent: Agent; showAvatar: boolean; isStreaming: boolean;
}) {
  const c = COLOR_MAP[agent.color];
  const isUser = msg.role === "user";

  return (
    <motion.div
      initial={{ opacity: 0, y: 8, scale: 0.98 }}
      animate={{ opacity: 1, y: 0, scale: 1 }}
      transition={{ duration: 0.3, ease: [0.22, 1, 0.36, 1] }}
      className={`flex items-end gap-2.5 ${isUser ? "justify-end" : "justify-start"}`}
    >
      {!isUser && (
        <div className="w-8 shrink-0">
          {showAvatar ? <AgentAvatar agentId={agent.id} size={32} /> : null}
        </div>
      )}
      <div className={`flex flex-col max-w-[78%] md:max-w-[68%] ${isUser ? "items-end" : "items-start"}`}>
        {!isUser && showAvatar && (
          <div className="text-[10px] font-mono tracking-[0.2em] mb-1 ml-1" style={{ color: c.hex }}>
            {agent.shortName.toUpperCase()}
          </div>
        )}
        <div
          className={`px-4 py-2.5 rounded-2xl text-[14px] leading-relaxed whitespace-pre-wrap break-words ${
            isUser
              ? "rounded-br-md text-black"
              : "rounded-bl-md text-white/90"
          }`}
          style={
            isUser
              ? { background: "linear-gradient(135deg, #f5b400, #e0a300)", boxShadow: "0 1px 12px rgba(245,180,0,0.18)" }
              : { background: c.soft, border: `1px solid ${c.hex}22` }
          }
        >
          {msg.text}
          {isStreaming && <span className="inline-block w-1 h-[14px] ml-0.5 align-text-bottom animate-pulse" style={{ background: c.hex }} />}
        </div>
        <div className="text-[10px] text-white/30 font-mono mt-1 mx-1 tabular-nums">
          {timeLabel(msg.ts)}
        </div>
      </div>
      {isUser && (
        <div className="w-8 shrink-0">
          <div className="h-8 w-8 rounded-full bg-gradient-to-br from-amber-300 to-amber-600 grid place-items-center text-black text-[11px] font-mono font-bold">
            C
          </div>
        </div>
      )}
    </motion.div>
  );
}
