"use client";
import { useEffect, useState, useCallback } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { Inbox, Check, X, MessageSquare, Loader2, CircleDot } from "lucide-react";
import SectionHeader from "./SectionHeader";
import { getAgent } from "@/lib/agents";
import { COLOR_MAP } from "@/lib/theme";

interface Decision {
  id: string; title: string; body: string; source: string;
  agentId?: string; status: "open" | "resolved" | "dismissed";
  createdAt: string; closedAt?: string;
}

const ago = (iso: string) => {
  const s = Math.floor((Date.now() - new Date(iso).getTime()) / 1000);
  if (s < 3600) return `${Math.max(1, Math.floor(s / 60))}m ago`;
  if (s < 86400) return `${Math.floor(s / 3600)}h ago`;
  return `${Math.floor(s / 86400)}d ago`;
};

export default function DecisionsView({ onOpenChat }: { onOpenChat?: (agentId: string) => void }) {
  const [decisions, setDecisions] = useState<Decision[] | null>(null);
  const [busy, setBusy] = useState<string | null>(null);

  const load = useCallback(() => {
    fetch("/api/decisions").then(r => r.json())
      .then(j => setDecisions(j.ok ? j.decisions : []))
      .catch(() => setDecisions([]));
  }, []);
  useEffect(() => { load(); const id = setInterval(load, 30000); return () => clearInterval(id); }, [load]);

  const act = async (id: string, status: "resolved" | "dismissed") => {
    setBusy(id);
    try { await fetch("/api/decisions", { method: "PATCH", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ id, status }) }); } catch {}
    setBusy(null); load();
  };

  const open = (decisions ?? []).filter(d => d.status === "open");
  const closed = (decisions ?? []).filter(d => d.status !== "open").slice(0, 10);

  const agentChip = (d: Decision) => {
    const ag = d.agentId ? getAgent(d.agentId) : null;
    const hex = ag ? ((COLOR_MAP as any)[ag.color]?.hex || ag.color) : "#f5b400";
    return (
      <span className="flex items-center gap-1.5 font-mono text-[9px] tracking-[0.16em] text-white/40 uppercase">
        <span className="h-1.5 w-1.5 rounded-full" style={{ background: hex, boxShadow: `0 0 5px ${hex}` }} />
        {d.source}
      </span>
    );
  };

  return (
    <div>
      <SectionHeader kicker="OPERATIONS / DECISIONS" title="Decisions" />
      <div className="text-[13px] text-white/55 -mt-3 mb-6 max-w-2xl">
        Things your agents and routines flagged for your call. Resolve or dismiss; routine reports live in the vault under AEGIS/Routines.
      </div>

      {decisions === null && (
        <div className="flex items-center gap-2 text-white/40 text-[12px]"><Loader2 className="h-3.5 w-3.5 animate-spin" /> Loading decisions…</div>
      )}

      {decisions !== null && open.length === 0 && (
        <div className="rounded-2xl border border-white/[0.07] bg-white/[0.02] p-8 text-center mb-6">
          <Inbox className="h-6 w-6 text-white/25 mx-auto mb-2" strokeWidth={1.5} />
          <div className="text-[13px] text-white/50">Nothing needs your call right now.</div>
          <div className="font-mono text-[10px] tracking-[0.2em] text-white/25 mt-1">THE BOARD ROOM IS QUIET</div>
        </div>
      )}

      <AnimatePresence>
        {open.map(d => (
          <motion.div key={d.id} layout initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, x: 40 }}
            className="rounded-2xl border border-amber-400/20 bg-amber-400/[0.03] p-5 mb-3">
            <div className="flex items-start justify-between gap-4 flex-wrap">
              <div className="min-w-0 flex-1">
                <div className="flex items-center gap-2 mb-1.5 flex-wrap">
                  <CircleDot className="h-3.5 w-3.5 text-amber-400 shrink-0" strokeWidth={2} />
                  <span className="text-[14px] text-white/90 font-medium">{d.title}</span>
                </div>
                <div className="flex items-center gap-3 mb-2.5">{agentChip(d)}<span className="font-mono text-[9px] text-white/30">{d.createdAt ? ago(d.createdAt) : ""}</span></div>
                <div className="text-[12.5px] text-white/60 leading-relaxed whitespace-pre-wrap">{d.body}</div>
              </div>
              <div className="flex items-center gap-2 shrink-0">
                {d.agentId && onOpenChat && (
                  <button onClick={() => onOpenChat(d.agentId!)} title="Discuss with the agent"
                    className="flex items-center gap-1.5 px-3 py-1.5 rounded-full border border-white/10 hover:border-white/25 hover:bg-white/[0.04] font-mono text-[10px] tracking-[0.14em] text-white/60 hover:text-white">
                    <MessageSquare className="h-3 w-3" strokeWidth={1.5} /> DISCUSS
                  </button>
                )}
                <button onClick={() => act(d.id, "resolved")} disabled={busy === d.id} title="Mark resolved"
                  className="flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-emerald-400/15 border border-emerald-400/30 hover:bg-emerald-400/25 font-mono text-[10px] tracking-[0.14em] text-emerald-300 disabled:opacity-40">
                  <Check className="h-3 w-3" strokeWidth={2} /> RESOLVE
                </button>
                <button onClick={() => act(d.id, "dismissed")} disabled={busy === d.id} title="Dismiss"
                  className="h-7 w-7 grid place-items-center rounded-full border border-white/10 hover:bg-white/5 text-white/40 hover:text-white disabled:opacity-40">
                  <X className="h-3.5 w-3.5" strokeWidth={1.5} />
                </button>
              </div>
            </div>
          </motion.div>
        ))}
      </AnimatePresence>

      {closed.length > 0 && (
        <div className="mt-8">
          <div className="font-mono text-[10px] tracking-[0.28em] text-white/35 mb-3">RECENTLY CLOSED</div>
          {closed.map(d => (
            <div key={d.id} className="flex items-center gap-3 rounded-xl border border-white/[0.05] px-4 py-2.5 mb-1.5 opacity-55">
              {d.status === "resolved"
                ? <Check className="h-3.5 w-3.5 text-emerald-400 shrink-0" strokeWidth={2} />
                : <X className="h-3.5 w-3.5 text-white/35 shrink-0" strokeWidth={2} />}
              <span className="text-[12px] text-white/70 truncate flex-1">{d.title}</span>
              <span className="font-mono text-[9px] text-white/30 shrink-0">{d.closedAt ? ago(d.closedAt) : ""}</span>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
