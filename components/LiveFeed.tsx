"use client";
import { useEffect, useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { Radio } from "lucide-react";
import { COLOR_MAP, fmtTime } from "@/lib/theme";
import AgentAvatar from "./AgentAvatar";

interface Template {
  tag: string;
  color: keyof typeof COLOR_MAP;
  agentId: string | null;
  msg: string;
}

const TEMPLATES: Template[] = [
  { tag: "TASK", color: "amber",   agentId: "claude-prime", msg: "accepted query :: deep-research on quantum error correction" },
  { tag: "SYNC", color: "rose",    agentId: "weaver-04",    msg: "orchestrating 3 sub-agents across pipeline" },
  { tag: "OK",   color: "violet",  agentId: "forge-02",     msg: "completed module :: build/auth.ts (3.1kb)" },
  { tag: "EVAL", color: "sky",     agentId: "sentry-05",    msg: "passing 24/24 safety checks" },
  { tag: "IDX",  color: "emerald", agentId: "archive-03",   msg: "indexed 412 documents :: vector store +1.2MB" },
  { tag: "WARN", color: "cyan",    agentId: "scout-01",     msg: "rate-limit soft hit :: cooling 12s" },
  { tag: "TOOL", color: "amber",   agentId: "claude-prime", msg: "tool_use(web_search) :: 4 results returned" },
  { tag: "LINK", color: "emerald", agentId: null,           msg: "tls1.3 handshake complete · chacha20-poly1305" },
  { tag: "MEM",  color: "cyan",    agentId: "claude-prime", msg: "context-window pruned · -8.4k tokens" },
];

interface Event extends Template { id: number; ts: Date; }

export default function LiveFeed() {
  const [events, setEvents] = useState<Event[]>([]);

  useEffect(() => {
    const seeded = TEMPLATES.slice(0, 6).map((e, i) => ({
      ...e, id: Date.now() - i * 4000, ts: new Date(Date.now() - i * 4000),
    }));
    setEvents(seeded);
    const id = setInterval(() => {
      const next = TEMPLATES[Math.floor(Math.random() * TEMPLATES.length)];
      setEvents(prev => [{ ...next, id: Date.now(), ts: new Date() }, ...prev].slice(0, 8));
    }, 2400);
    return () => clearInterval(id);
  }, []);

  return (
    <div className="rounded-2xl border border-white/[0.07] bg-white/[0.02] p-5 h-full flex flex-col">
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-2">
          <Radio className="h-3.5 w-3.5 text-amber-400" strokeWidth={1.5} />
          <span className="font-mono text-[10px] tracking-[0.28em] text-white/80">LIVE FEED</span>
        </div>
        <span className="font-mono text-[9px] tracking-[0.22em] text-emerald-400 flex items-center gap-1.5">
          <motion.span className="h-1 w-1 rounded-full bg-emerald-400"
            animate={{ opacity: [1, 0.3, 1] }} transition={{ duration: 1, repeat: Infinity }} />
          STREAMING
        </span>
      </div>
      <div className="space-y-2 overflow-hidden flex-1">
        <AnimatePresence initial={false}>
          {events.map((e) => {
            const c = COLOR_MAP[e.color];
            return (
              <motion.div
                key={e.id} layout
                initial={{ opacity: 0, x: -12, height: 0 }}
                animate={{ opacity: 1, x: 0, height: "auto" }}
                exit={{ opacity: 0, x: 12 }}
                transition={{ duration: 0.35 }}
                className="flex items-center gap-2.5 text-[12px]"
              >
                {e.agentId
                  ? <AgentAvatar agentId={e.agentId} size={24} animated={false} />
                  : <div className="h-6 w-6 grid place-items-center rounded-full" style={{ background: c.soft }}>
                      <span className="h-1.5 w-1.5 rounded-full" style={{ background: c.hex }} />
                    </div>
                }
                <span className="text-white/30 tabular-nums font-mono text-[10px] w-[52px] shrink-0">{fmtTime(e.ts).split(" ")[0]}</span>
                <span className="px-1.5 py-0.5 rounded font-mono text-[9px] tracking-[0.18em] shrink-0"
                  style={{ background: c.soft, color: c.hex }}>
                  {e.tag}
                </span>
                <span className="text-white/70 truncate">{e.msg}</span>
              </motion.div>
            );
          })}
        </AnimatePresence>
      </div>
    </div>
  );
}
