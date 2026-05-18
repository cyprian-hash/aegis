"use client";
import { useState, useEffect } from "react";
import { motion } from "framer-motion";
import { Search } from "lucide-react";
import { AGENTS, Agent } from "@/lib/agents";
import { COLOR_MAP } from "@/lib/theme";
import AgentAvatar from "./AgentAvatar";
import ChatView from "./ChatView";

// pretend last-message snippets so the directory feels alive
const PREVIEWS: Record<string, { snippet: string; time: string; unread?: number }> = {
  "claude-prime": { snippet: "Commander. Prime online. What's the objective?", time: "now",     unread: 1 },
  "scout-01":     { snippet: "Found 28 papers on surface codes.",                time: "4m" },
  "forge-02":     { snippet: "Shipped /oauth/authorize. Ready for review.",      time: "8m",    unread: 2 },
  "archive-03":   { snippet: "412 chunks embedded.",                              time: "12m" },
  "weaver-04":    { snippet: "Plan ready: 7 steps across 3 agents.",              time: "1h" },
  "sentry-05":    { snippet: "PASS — 24/24 checks.",                               time: "2h" },
};

export default function MessengerView({ initialAgentId }: { initialAgentId?: string }) {
  const [activeId, setActiveId] = useState<string>(initialAgentId || AGENTS[0].id);
  const [query, setQuery] = useState("");
  const [mobileShowChat, setMobileShowChat] = useState(false);

  useEffect(() => {
    if (initialAgentId) {
      setActiveId(initialAgentId);
      setMobileShowChat(true);
    }
  }, [initialAgentId]);

  const filtered = AGENTS.filter(a =>
    query === "" ||
    a.name.toLowerCase().includes(query.toLowerCase()) ||
    a.role.toLowerCase().includes(query.toLowerCase())
  );

  const activeAgent = AGENTS.find(a => a.id === activeId) || AGENTS[0];

  return (
    <div className="grid grid-cols-1 md:grid-cols-[320px_1fr] gap-3 h-[calc(100vh-160px)]">
      {/* Directory */}
      <div className={`bg-[#0a0a0a] border border-white/[0.06] rounded-2xl overflow-hidden flex flex-col ${mobileShowChat ? "hidden md:flex" : "flex"}`}>
        <div className="px-4 py-4 border-b border-white/[0.06]">
          <div className="flex items-center justify-between mb-3">
            <h2 className="font-display text-xl text-white tracking-tight">Agents</h2>
            <div className="font-mono text-[9px] tracking-[0.25em] text-emerald-400 flex items-center gap-1.5">
              <motion.span className="h-1.5 w-1.5 rounded-full bg-emerald-400"
                animate={{ opacity: [1, 0.4, 1] }} transition={{ duration: 1.6, repeat: Infinity }} />
              {AGENTS.filter(a => a.status === "online").length} ONLINE
            </div>
          </div>
          <div className="flex items-center gap-2 bg-white/[0.03] border border-white/10 rounded-full px-3.5 py-2">
            <Search className="h-3.5 w-3.5 text-white/40" strokeWidth={1.5} />
            <input
              value={query} onChange={e => setQuery(e.target.value)}
              placeholder="Search agents…"
              className="flex-1 bg-transparent text-[13px] text-white placeholder-white/30 outline-none"
            />
          </div>
        </div>

        <div className="flex-1 overflow-y-auto p-2">
          {filtered.map((agent, i) => {
            const c = COLOR_MAP[agent.color];
            const isActive = agent.id === activeId;
            const preview = PREVIEWS[agent.id];

            return (
              <motion.button
                key={agent.id}
                initial={{ opacity: 0, x: -8 }} animate={{ opacity: 1, x: 0 }}
                transition={{ delay: i * 0.04 }}
                onClick={() => { setActiveId(agent.id); setMobileShowChat(true); }}
                className={`relative w-full flex items-center gap-3 p-2.5 rounded-xl text-left transition-colors ${
                  isActive ? "bg-white/[0.05]" : "hover:bg-white/[0.03]"
                }`}
              >
                {isActive && (
                  <motion.div layoutId="dir-active"
                    className="absolute left-0 top-1/2 -translate-y-1/2 h-6 w-[2px] rounded-r"
                    style={{ background: c.hex, boxShadow: `0 0 8px ${c.glow}` }} />
                )}

                <div className="relative shrink-0">
                  <AgentAvatar agentId={agent.id} size={44} />
                  <span
                    className="absolute bottom-0 right-0 h-2.5 w-2.5 rounded-full border-2 border-[#0a0a0a]"
                    style={{ background: agent.status === "online" ? "#34d399" : agent.status === "idle" ? "#f5b400" : "#94a3b8" }}
                  />
                </div>

                <div className="flex-1 min-w-0">
                  <div className="flex items-center justify-between mb-0.5">
                    <span className="font-display text-[13px] text-white font-medium truncate">{agent.shortName}</span>
                    <span className="font-mono text-[9px] text-white/30 tabular-nums shrink-0 ml-2">{preview?.time}</span>
                  </div>
                  <div className="flex items-center justify-between gap-2">
                    <span className="text-[11px] text-white/50 truncate">{preview?.snippet || agent.role}</span>
                    {preview?.unread && (
                      <span
                        className="shrink-0 h-4 min-w-[16px] px-1 rounded-full grid place-items-center text-[9px] font-bold text-black tabular-nums"
                        style={{ background: c.hex, boxShadow: `0 0 8px ${c.glow}` }}
                      >
                        {preview.unread}
                      </span>
                    )}
                  </div>
                </div>
              </motion.button>
            );
          })}
        </div>
      </div>

      {/* Active chat */}
      <div className={`${mobileShowChat ? "block" : "hidden md:block"}`}>
        <ChatView agent={activeAgent} onBack={() => setMobileShowChat(false)} embedded />
      </div>
    </div>
  );
}
