"use client";
import { useEffect, useState } from "react";
import { motion } from "framer-motion";
import { Wallet, TrendingUp, AlertTriangle, Bot, Cpu, Loader2 } from "lucide-react";
import StatTile from "./StatTile";
import SectionHeader from "./SectionHeader";
import { COLOR_MAP } from "@/lib/theme";
import { getAgent } from "@/lib/agents";

interface Group { name: string; cost: number; calls: number; inTok: number; outTok: number; }
interface Ledger {
  ok: boolean; budget: number;
  today: { spend: number; calls: number; pct: number };
  week: { spend: number; calls: number };
  month: { spend: number; calls: number };
  byAgent: Group[]; byModel: Group[];
  recent: { ts: string; agentId: string; model: string; inTok: number; outTok: number; cost: number }[];
  note: string;
}

const usd = (n: number) => n < 0.01 && n > 0 ? "<$0.01" : `$${n.toFixed(2)}`;
const ago = (iso: string) => {
  const s = Math.floor((Date.now() - new Date(iso).getTime()) / 1000);
  if (s < 60) return `${s}s`; if (s < 3600) return `${Math.floor(s/60)}m`;
  if (s < 86400) return `${Math.floor(s/3600)}h`; return `${Math.floor(s/86400)}d`;
};

export default function LedgerView() {
  const [data, setData] = useState<Ledger | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetch("/api/ledger").then(r => r.json()).then(setData).catch(() => null).finally(() => setLoading(false));
    const id = setInterval(() => fetch("/api/ledger").then(r => r.json()).then(setData).catch(() => null), 30000);
    return () => clearInterval(id);
  }, []);

  const pct = data?.today.pct ?? 0;
  const warn = pct >= 80 && pct < 100;
  const over = pct >= 100;
  const barColor = over ? "#E11D48" : warn ? "#f5b400" : "#34d399";

  return (
    <div>
      <SectionHeader kicker="SYSTEM / LEDGER" title="API Spend & Safety" />

      {(warn || over) && (
        <motion.div initial={{ opacity: 0, y: -6 }} animate={{ opacity: 1, y: 0 }}
          className={`rounded-2xl border p-4 mb-6 flex items-center gap-3 ${over ? "border-rose-500/30 bg-rose-500/[0.06]" : "border-amber-400/30 bg-amber-400/[0.06]"}`}>
          <AlertTriangle className={`h-4 w-4 ${over ? "text-rose-400" : "text-amber-400"}`} />
          <div className="text-[13px] text-white/80">
            {over
              ? <>Today&apos;s estimated spend is <b>over budget</b> ({usd(data!.today.spend)} of ${data!.budget}/day). Requests are NOT blocked — this is a warning only.</>
              : <>Today&apos;s estimated spend is at <b>{Math.round(pct)}%</b> of your ${data!.budget}/day budget.</>}
          </div>
        </motion.div>
      )}

      <div className="grid grid-cols-2 lg:grid-cols-4 gap-3 mb-4">
        <StatTile label="TODAY"      value={loading ? "—" : usd(data?.today.spend ?? 0)} sub={`${data?.today.calls ?? 0} CALLS`}  accent="amber"   sparkSeed={4} />
        <StatTile label="LAST 7 DAYS"  value={loading ? "—" : usd(data?.week.spend ?? 0)}  sub={`${data?.week.calls ?? 0} CALLS`}   accent="cyan"    sparkSeed={7} />
        <StatTile label="LAST 30 DAYS" value={loading ? "—" : usd(data?.month.spend ?? 0)} sub={`${data?.month.calls ?? 0} CALLS`}  accent="violet"  sparkSeed={5} />
        <StatTile label="DAILY BUDGET" value={loading ? "—" : `$${data?.budget ?? 10}`}    sub="AEGIS_DAILY_BUDGET" accent="emerald" sparkSeed={2} />
      </div>

      {/* Budget bar */}
      <div className="rounded-2xl border border-white/[0.07] bg-white/[0.02] p-5 mb-6">
        <div className="flex items-center justify-between mb-2">
          <span className="font-mono text-[10px] tracking-[0.28em] text-white/60">TODAY VS BUDGET</span>
          <span className="font-mono text-[11px] tabular-nums" style={{ color: barColor }}>{Math.min(999, Math.round(pct))}%</span>
        </div>
        <div className="h-2 bg-white/[0.05] rounded-full overflow-hidden">
          <motion.div className="h-full rounded-full" style={{ background: barColor, boxShadow: `0 0 8px ${barColor}88` }}
            initial={{ width: 0 }} animate={{ width: `${Math.min(100, pct)}%` }} transition={{ duration: 0.8 }} />
        </div>
        <div className="mt-2 text-[10px] text-white/35 font-mono">WARNINGS ONLY · REQUESTS ARE NEVER BLOCKED</div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-3 mb-6">
        {/* By agent */}
        <div className="rounded-2xl border border-white/[0.07] bg-white/[0.02] p-6">
          <div className="flex items-center gap-2 mb-4">
            <Bot className="h-3.5 w-3.5 text-amber-400" />
            <span className="font-mono text-[10px] tracking-[0.28em] text-white/80">SPEND BY AGENT · 30D</span>
          </div>
          <div className="space-y-4">
            {loading && <div className="flex items-center gap-2 text-white/40 text-[12px]"><Loader2 className="h-3.5 w-3.5 animate-spin" /> Loading…</div>}
            {!loading && (data?.byAgent ?? []).length === 0 && <div className="text-[12px] text-white/40">No usage recorded yet. Chat with an agent and spend will appear here.</div>}
            {(data?.byAgent ?? []).map(g => {
              const ag = getAgent(g.name);
              const hex = (COLOR_MAP as any)[ag?.color || ""]?.hex || ag?.color || "#f5b400";
              const max = Math.max(0.0001, data!.byAgent[0].cost);
              return (
                <div key={g.name}>
                  <div className="flex items-center justify-between mb-1.5">
                    <span className="text-[12px] text-white/75">{ag?.name || g.name}</span>
                    <span className="font-mono text-[10px] text-white/85 tabular-nums">{usd(g.cost)} · {g.calls} calls</span>
                  </div>
                  <div className="h-1.5 bg-white/[0.05] rounded-full overflow-hidden">
                    <motion.div className="h-full rounded-full" style={{ background: hex, boxShadow: `0 0 6px ${hex}88` }}
                      initial={{ width: 0 }} animate={{ width: `${(g.cost / max) * 100}%` }} transition={{ duration: 0.8 }} />
                  </div>
                </div>
              );
            })}
          </div>
        </div>

        {/* By model */}
        <div className="rounded-2xl border border-white/[0.07] bg-white/[0.02] p-6">
          <div className="flex items-center gap-2 mb-4">
            <Cpu className="h-3.5 w-3.5 text-amber-400" />
            <span className="font-mono text-[10px] tracking-[0.28em] text-white/80">SPEND BY MODEL · 30D</span>
          </div>
          <div className="space-y-1.5">
            {!loading && (data?.byModel ?? []).length === 0 && <div className="text-[12px] text-white/40">No usage yet.</div>}
            {(data?.byModel ?? []).map(g => (
              <div key={g.name} className="flex items-center gap-3 rounded-xl border border-white/[0.05] p-3">
                <div className="flex-1 min-w-0">
                  <div className="text-[12px] text-white/85 truncate font-mono">{g.name}</div>
                  <div className="text-[10px] text-white/40 mt-0.5">{g.inTok.toLocaleString()} in · {g.outTok.toLocaleString()} out</div>
                </div>
                <span className="font-mono text-[11px] text-white/85 tabular-nums">{usd(g.cost)}</span>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Recent calls */}
      <div className="rounded-2xl border border-white/[0.07] bg-white/[0.02] p-6">
        <div className="flex items-center gap-2 mb-4">
          <TrendingUp className="h-3.5 w-3.5 text-amber-400" />
          <span className="font-mono text-[10px] tracking-[0.28em] text-white/80">RECENT CALLS</span>
        </div>
        <div className="space-y-1">
          {(data?.recent ?? []).map((r, i) => {
            const ag = getAgent(r.agentId);
            return (
              <div key={r.ts + i} className="flex items-center gap-3 py-1.5 border-b border-white/[0.03] last:border-0 text-[11px]">
                <span className="text-white/70 w-28 truncate">{ag?.name || r.agentId}</span>
                <span className="text-white/35 font-mono flex-1 truncate">{r.model}</span>
                <span className="text-white/40 font-mono tabular-nums hidden sm:inline">{r.inTok}→{r.outTok}</span>
                <span className="text-white/80 font-mono tabular-nums">{usd(r.cost)}</span>
                <span className="text-white/30 font-mono w-8 text-right">{ago(r.ts)}</span>
              </div>
            );
          })}
          {!loading && (data?.recent ?? []).length === 0 && <div className="text-[12px] text-white/40">No calls logged yet.</div>}
        </div>
        <div className="mt-4 text-[10px] text-white/30 font-mono leading-relaxed">
          ESTIMATES AT PUBLISHED PER-TOKEN PRICES · PROVIDER BILL IS GROUND TRUTH · TRACKS AEGIS USAGE ONLY, FROM INSTALL · HERMES (LOCAL) = $0
        </div>
      </div>
    </div>
  );
}
