"use client";
import { useEffect, useMemo, useRef, useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { Search, Filter, Pause, Play, Download, ChevronRight, X } from "lucide-react";
import { COLOR_MAP, fmtTime, pad } from "@/lib/theme";
import { AGENTS } from "@/lib/agents";
import SectionHeader from "./SectionHeader";
import AgentAvatar from "./AgentAvatar";

type Level = "INFO" | "OK" | "WARN" | "ERROR" | "DEBUG" | "TRACE";

interface LogEntry {
  id: number;
  ts: Date;
  level: Level;
  agentId: string | null;
  agent: string;
  msg: string;
  detail?: string;
}

const LEVEL_COLOR: Record<Level, keyof typeof COLOR_MAP> = {
  INFO: "cyan", OK: "emerald", WARN: "amber", ERROR: "rose", DEBUG: "violet", TRACE: "sky",
};

const TEMPLATES: { level: Level; agentId: string | null; agent: string; msg: string; detail?: string }[] = [
  { level: "INFO",  agentId: "claude-prime", agent: "CLAUDE.PRIME", msg: "stream.start :: incoming directive from operator", detail: "model=opus-4.7 tokens=384" },
  { level: "OK",    agentId: "forge-02",     agent: "FORGE-02",     msg: "build.complete :: dist/auth.bundle.js → 12.4kb", detail: "duration=2.8s" },
  { level: "WARN",  agentId: "scout-01",     agent: "SCOUT-01",     msg: "rate_limit.soft :: cooling for 12s", detail: "endpoint=anthropic/messages" },
  { level: "ERROR", agentId: "weaver-04",    agent: "WEAVER-04",    msg: "sub_agent.timeout :: archive-03 unreachable @ 8000ms", detail: "retry=2/3" },
  { level: "TRACE", agentId: "archive-03",   agent: "ARCHIVE-03",   msg: "vector.embed :: 412 chunks → store/2025-05", detail: "model=text-embed-3" },
  { level: "DEBUG", agentId: "claude-prime", agent: "CLAUDE.PRIME", msg: "tool_use :: web_search(\"quantum error correction\")" },
  { level: "OK",    agentId: "sentry-05",    agent: "SENTRY-05",    msg: "eval.pass :: 24/24 safety checks", detail: "score=0.97" },
  { level: "INFO",  agentId: null,           agent: "SYSTEM",       msg: "uplink.handshake :: tls1.3 chacha20-poly1305 :: ok" },
  { level: "DEBUG", agentId: "forge-02",     agent: "FORGE-02",     msg: "lsp.completion :: 3 suggestions surfaced", detail: "file=src/auth.ts" },
  { level: "WARN",  agentId: "claude-prime", agent: "CLAUDE.PRIME", msg: "context.prune :: dropping 8.4k stale tokens" },
  { level: "OK",    agentId: "weaver-04",    agent: "WEAVER-04",    msg: "mission.dispatched :: M-0042 → 3 agents" },
  { level: "INFO",  agentId: "archive-03",   agent: "ARCHIVE-03",   msg: "memory.write :: span=mission-0041 size=2.1kb" },
  { level: "ERROR", agentId: "scout-01",     agent: "SCOUT-01",     msg: "fetch.fail :: tls handshake aborted", detail: "host=archive.org" },
  { level: "TRACE", agentId: "claude-prime", agent: "CLAUDE.PRIME", msg: "thinking :: synthesizing surface code overview" },
];

const LEVELS: Level[] = ["INFO", "OK", "WARN", "ERROR", "DEBUG", "TRACE"];

export default function LogsView() {
  const [logs, setLogs] = useState<LogEntry[]>([]);
  const [paused, setPaused] = useState(false);
  const [query, setQuery] = useState("");
  const [activeLevels, setActiveLevels] = useState<Set<Level>>(new Set(LEVELS));
  const [activeAgent, setActiveAgent] = useState<string>("ALL");
  const [selected, setSelected] = useState<LogEntry | null>(null);
  const idCounter = useRef(0);

  useEffect(() => {
    const seed: LogEntry[] = TEMPLATES.slice().reverse().map((t, i) => ({
      ...t, id: idCounter.current++, ts: new Date(Date.now() - (TEMPLATES.length - i) * 3000),
    }));
    setLogs(seed);
  }, []);

  useEffect(() => {
    if (paused) return;
    const id = setInterval(() => {
      const tpl = TEMPLATES[Math.floor(Math.random() * TEMPLATES.length)];
      setLogs(prev => [...prev, { ...tpl, id: idCounter.current++, ts: new Date() }].slice(-200));
    }, 1400);
    return () => clearInterval(id);
  }, [paused]);

  const filtered = useMemo(() => {
    return logs.filter(l =>
      activeLevels.has(l.level) &&
      (activeAgent === "ALL" || l.agent === activeAgent) &&
      (query === "" || l.msg.toLowerCase().includes(query.toLowerCase()) || (l.detail?.toLowerCase().includes(query.toLowerCase())))
    ).slice().reverse();
  }, [logs, activeLevels, activeAgent, query]);

  const counts = useMemo(() => {
    const c: Record<Level, number> = { INFO: 0, OK: 0, WARN: 0, ERROR: 0, DEBUG: 0, TRACE: 0 };
    logs.forEach(l => c[l.level]++);
    return c;
  }, [logs]);

  const toggleLevel = (l: Level) => {
    setActiveLevels(prev => {
      const next = new Set(prev);
      next.has(l) ? next.delete(l) : next.add(l);
      return next;
    });
  };

  const exportLogs = () => {
    const text = logs.map(l =>
      `${fmtTime(l.ts)} [${l.level}] ${l.agent} :: ${l.msg}${l.detail ? " // " + l.detail : ""}`
    ).join("\n");
    const blob = new Blob([text], { type: "text/plain" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url; a.download = `aegis-logs-${Date.now()}.log`;
    a.click(); URL.revokeObjectURL(url);
  };

  return (
    <div>
      <SectionHeader
        kicker="OPERATIONS / LOG STREAM"
        title="Logs Explorer"
        right={
          <div className="flex items-center gap-2 font-mono text-[10px] tracking-[0.2em] text-white/60">
            <button onClick={() => setPaused(p => !p)}
              className="px-3 py-1.5 rounded-full border border-white/10 hover:border-white/30 hover:text-white flex items-center gap-1.5">
              {paused ? <><Play className="h-3 w-3" /> RESUME</> : <><Pause className="h-3 w-3" /> PAUSE</>}
            </button>
            <button onClick={exportLogs}
              className="px-3 py-1.5 rounded-full border border-white/10 hover:border-white/30 hover:text-white flex items-center gap-1.5">
              <Download className="h-3 w-3" /> EXPORT
            </button>
          </div>
        }
      />

      <div className="grid grid-cols-3 md:grid-cols-6 gap-2 mb-4">
        {LEVELS.map(l => {
          const c = COLOR_MAP[LEVEL_COLOR[l]];
          const on = activeLevels.has(l);
          return (
            <button key={l} onClick={() => toggleLevel(l)}
              className={`rounded-xl border p-3 text-left transition-all ${on ? "" : "opacity-40"}`}
              style={{ borderColor: on ? `${c.hex}55` : "rgba(255,255,255,0.08)", background: on ? c.soft : "transparent" }}>
              <div className="flex items-center justify-between mb-1">
                <span className="font-mono text-[9px] tracking-[0.22em]" style={{ color: c.hex }}>{l}</span>
                <span className="h-1.5 w-1.5 rounded-full" style={{ background: c.hex }} />
              </div>
              <div className="font-display text-xl text-white tabular-nums">{pad(counts[l])}</div>
            </button>
          );
        })}
      </div>

      <div className="flex items-center gap-3 mb-4 flex-wrap">
        <div className="flex items-center gap-2 rounded-full border border-white/10 bg-black/40 px-4 flex-1 min-w-[260px]">
          <Search className="h-3.5 w-3.5 text-white/40" strokeWidth={1.5} />
          <input
            value={query} onChange={e => setQuery(e.target.value)}
            placeholder="Search messages, details, agents…"
            className="flex-1 bg-transparent py-2.5 text-[12px] text-white placeholder-white/30 outline-none"
          />
          <span className="font-mono text-[9px] tracking-[0.18em] text-white/40">{filtered.length}/{logs.length}</span>
        </div>
        <div className="flex items-center gap-1.5">
          <Filter className="h-3.5 w-3.5 text-white/40" strokeWidth={1.5} />
          <select value={activeAgent} onChange={e => setActiveAgent(e.target.value)}
            className="bg-black border border-white/10 rounded-full text-white/80 px-3 py-2 text-[11px] font-mono outline-none">
            <option value="ALL">ALL AGENTS</option>
            {AGENTS.map(a => <option key={a.id} value={a.name}>{a.name}</option>)}
            <option value="SYSTEM">SYSTEM</option>
          </select>
        </div>
      </div>

      <div className="rounded-2xl border border-white/[0.07] bg-black/40 overflow-hidden flex h-[560px]">
        <div className="flex-1 overflow-y-auto">
          <AnimatePresence initial={false}>
            {filtered.map((l) => {
              const c = COLOR_MAP[LEVEL_COLOR[l.level]];
              const isSel = selected?.id === l.id;
              return (
                <motion.button
                  key={l.id}
                  layout
                  initial={{ opacity: 0, y: -4 }}
                  animate={{ opacity: 1, y: 0 }}
                  exit={{ opacity: 0 }}
                  transition={{ duration: 0.18 }}
                  onClick={() => setSelected(l)}
                  className={`w-full flex items-center gap-3 px-4 py-2.5 text-left border-b border-white/[0.04] hover:bg-white/[0.03] ${isSel ? "bg-white/[0.04]" : ""}`}
                >
                  {l.agentId
                    ? <AgentAvatar agentId={l.agentId} size={22} animated={false} />
                    : <div className="h-[22px] w-[22px] grid place-items-center rounded-full" style={{ background: c.soft }}>
                        <span className="h-1.5 w-1.5 rounded-full" style={{ background: c.hex }} />
                      </div>
                  }
                  <span className="font-mono text-[10px] text-white/40 tabular-nums w-[68px] shrink-0">{fmtTime(l.ts).split(" ")[0]}</span>
                  <span className="font-mono text-[9px] tracking-[0.18em] w-[44px] shrink-0" style={{ color: c.hex }}>{l.level}</span>
                  <span className="text-[11px] text-white/85 truncate flex-1">{l.msg}</span>
                </motion.button>
              );
            })}
          </AnimatePresence>
          {filtered.length === 0 && (
            <div className="p-12 text-center font-mono text-[11px] tracking-[0.18em] text-white/30">
              NO LOGS MATCH CURRENT FILTERS
            </div>
          )}
        </div>

        <AnimatePresence>
          {selected && (
            <motion.div
              initial={{ width: 0 }} animate={{ width: 360 }} exit={{ width: 0 }}
              className="border-l border-white/[0.06] overflow-hidden shrink-0"
            >
              <div className="w-[360px] p-5 space-y-4">
                <div className="flex items-center justify-between">
                  <span className="font-mono text-[10px] tracking-[0.28em] text-white/40">LOG DETAIL</span>
                  <button onClick={() => setSelected(null)} className="text-white/40 hover:text-white">
                    <X className="h-3 w-3" />
                  </button>
                </div>
                {selected.agentId && (
                  <div className="flex items-center gap-3 p-3 rounded-xl border border-white/[0.06] bg-white/[0.02]">
                    <AgentAvatar agentId={selected.agentId} size={32} animated={false} />
                    <div>
                      <div className="font-mono text-[11px] text-white/85">{selected.agent}</div>
                      <div className="font-mono text-[9px] tracking-[0.18em] text-white/40">{AGENTS.find(a => a.id === selected.agentId)?.role}</div>
                    </div>
                  </div>
                )}
                <div>
                  <div className="font-mono text-[9px] tracking-[0.25em] text-white/30 mb-1">LEVEL</div>
                  <div className="font-mono text-[12px]" style={{ color: COLOR_MAP[LEVEL_COLOR[selected.level]].hex }}>
                    {selected.level}
                  </div>
                </div>
                <div>
                  <div className="font-mono text-[9px] tracking-[0.25em] text-white/30 mb-1">TIMESTAMP</div>
                  <div className="font-mono text-[12px] text-white/85">{fmtTime(selected.ts)}</div>
                </div>
                <div>
                  <div className="font-mono text-[9px] tracking-[0.25em] text-white/30 mb-1">MESSAGE</div>
                  <div className="font-mono text-[12px] text-white/90 leading-relaxed">{selected.msg}</div>
                </div>
                {selected.detail && (
                  <div>
                    <div className="font-mono text-[9px] tracking-[0.25em] text-white/30 mb-1">DETAIL</div>
                    <div className="font-mono text-[11px] text-white/70 leading-relaxed border-l-2 border-amber-400/40 pl-3">
                      {selected.detail}
                    </div>
                  </div>
                )}
                <div className="pt-2 border-t border-white/[0.06]">
                  <button className="w-full flex items-center justify-center gap-2 py-2 rounded-full border border-white/10 hover:bg-white/5 font-mono text-[10px] tracking-[0.2em] text-white/70">
                    OPEN TRACE <ChevronRight className="h-3 w-3" />
                  </button>
                </div>
              </div>
            </motion.div>
          )}
        </AnimatePresence>
      </div>
    </div>
  );
}
