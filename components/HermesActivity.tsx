"use client";
import { useEffect, useState, useCallback } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { Radio, Inbox } from "lucide-react";
import AgentAvatar from "./AgentAvatar";

interface KanbanEvent {
  id: number;
  task_id: string;
  kind: string;
  payload: any;
  created_at: string;
  task_title: string | null;
  assignee: string | null;
}

interface EventsResponse {
  events: KanbanEvent[];
  dbExists: boolean;
  error?: string;
}

const KIND_COLOR: Record<string, string> = {
  created:    "#22d3ee",
  promoted:   "#a78bfa",
  claimed:    "#fbbf24",
  spawned:    "#fbbf24",
  heartbeat:  "#7dd3fc",
  completed:  "#34d399",
  blocked:    "#fb7185",
  unblocked:  "#34d399",
  archived:   "#94a3b8",
  reclaimed:  "#fb7185",
  crashed:    "#fb7185",
  timed_out:  "#fb7185",
  gave_up:    "#fb7185",
};

function relTime(iso: string): string {
  try {
    const t = new Date(iso).getTime();
    const ago = Date.now() - t;
    if (ago < 60_000) return `${Math.max(1, Math.floor(ago / 1000))}s ago`;
    if (ago < 3600_000) return `${Math.floor(ago / 60_000)}m ago`;
    if (ago < 86400_000) return `${Math.floor(ago / 3600_000)}h ago`;
    return `${Math.floor(ago / 86400_000)}d ago`;
  } catch { return ""; }
}

export default function HermesActivity() {
  const [state, setState] = useState<EventsResponse | null>(null);
  const [loading, setLoading] = useState(true);

  const refresh = useCallback(async () => {
    try {
      const res = await fetch("/api/hermes/events", { cache: "no-store" });
      const data: EventsResponse = await res.json();
      setState(data);
    } catch {
      setState({ events: [], dbExists: false });
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    refresh();
    const id = setInterval(refresh, 5000);
    return () => clearInterval(id);
  }, [refresh]);

  return (
    <div className="rounded-2xl border border-white/[0.07] bg-white/[0.02] p-5 h-full flex flex-col">
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-2">
          <Radio className="h-3.5 w-3.5 text-amber-400" strokeWidth={1.5} />
          <span className="font-mono text-[10px] tracking-[0.28em] text-white/80">HERMES ACTIVITY</span>
        </div>
        {state?.dbExists && (
          <span className="font-mono text-[9px] tracking-[0.22em] text-emerald-400 flex items-center gap-1.5">
            <motion.span className="h-1 w-1 rounded-full bg-emerald-400"
              animate={{ opacity: [1, 0.3, 1] }} transition={{ duration: 1, repeat: Infinity }} />
            STREAMING
          </span>
        )}
      </div>

      {loading && (
        <div className="font-mono text-[10px] text-white/30 tracking-[0.18em]">LOADING…</div>
      )}

      {!loading && !state?.dbExists && (
        <div className="flex-1 flex flex-col items-center justify-center text-center py-8">
          <Inbox className="h-6 w-6 text-white/25 mb-2" strokeWidth={1.5} />
          <div className="text-[12px] text-white/55">No Hermes activity yet.</div>
          <div className="font-mono text-[10px] text-white/30 mt-1 max-w-[260px] leading-relaxed">
            Send a task to Hermes from the Missions board to see it work in real time.
          </div>
        </div>
      )}

      {!loading && state?.dbExists && state.events.length === 0 && (
        <div className="flex-1 flex flex-col items-center justify-center text-center py-8">
          <Inbox className="h-6 w-6 text-white/25 mb-2" strokeWidth={1.5} />
          <div className="text-[12px] text-white/55">Hermes is idle.</div>
        </div>
      )}

      {!loading && state?.dbExists && state.events.length > 0 && (
        <div className="flex-1 overflow-y-auto space-y-1.5">
          <AnimatePresence initial={false}>
            {state.events.map((e) => {
              const color = KIND_COLOR[e.kind] || "#94a3b8";
              return (
                <motion.div
                  key={e.id}
                  layout
                  initial={{ opacity: 0, x: -8 }}
                  animate={{ opacity: 1, x: 0 }}
                  exit={{ opacity: 0 }}
                  transition={{ duration: 0.2 }}
                  className="flex items-center gap-2.5 rounded-lg border border-white/[0.04] bg-white/[0.015] px-3 py-2"
                >
                  <AgentAvatar agentId="hermes-07" size={20} animated={false} />
                  <span className="font-mono text-[9px] tracking-[0.2em] px-1.5 py-0.5 rounded shrink-0"
                    style={{ background: color + "22", color }}>
                    {e.kind.toUpperCase()}
                  </span>
                  <div className="flex-1 min-w-0">
                    <div className="text-[11px] text-white/85 truncate">
                      {e.task_title || e.task_id}
                    </div>
                    {e.assignee && (
                      <div className="font-mono text-[9px] text-white/40">{e.assignee}</div>
                    )}
                  </div>
                  <span className="font-mono text-[9px] tabular-nums text-white/40 shrink-0">
                    {relTime(e.created_at)}
                  </span>
                </motion.div>
              );
            })}
          </AnimatePresence>
        </div>
      )}
    </div>
  );
}
