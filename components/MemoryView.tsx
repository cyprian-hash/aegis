"use client";
import { useEffect, useState, useCallback } from "react";
import { motion } from "framer-motion";
import { Database, FileText, Layers, Search, MessageSquare, BookOpen, FileStack, Loader2 } from "lucide-react";
import StatTile from "./StatTile";
import SectionHeader from "./SectionHeader";
import MemoryConstellation from "./MemoryConstellation";
import { COLOR_MAP } from "@/lib/theme";

interface Recent { name: string; kind: string; project?: string; updated: string; size: number; }
interface SearchHit { name: string; kind: string; project?: string; snippet: string; updated: string; }
interface Overview {
  ok: boolean; error?: string;
  stats?: { total: number; briefs: number; conversations: number; context: number; sources: number; strategies: number; totalSize: number; };
  recent?: Recent[];
}

const KIND_META: Record<string, { label: string; color: string; icon: any }> = {
  brief:        { label: "Brief",        color: "cyan",    icon: BookOpen },
  conversation: { label: "Conversation", color: "emerald", icon: MessageSquare },
  context:      { label: "Context",      color: "amber",   icon: Database },
  source:       { label: "Source Doc",   color: "violet",  icon: FileText },
  strategy:     { label: "Strategy",     color: "rose",    icon: FileStack },
  other:        { label: "File",         color: "cyan",    icon: FileText },
};

function ago(iso: string): string {
  const s = Math.floor((Date.now() - new Date(iso).getTime()) / 1000);
  if (s < 60) return `${s}s ago`;
  if (s < 3600) return `${Math.floor(s / 60)}m ago`;
  if (s < 86400) return `${Math.floor(s / 3600)}h ago`;
  return `${Math.floor(s / 86400)}d ago`;
}
function kb(n: number): string { return n < 1024 ? `${n} B` : `${(n / 1024).toFixed(1)} KB`; }

export default function MemoryView() {
  const [data, setData] = useState<Overview | null>(null);
  const [loading, setLoading] = useState(true);
  const [query, setQuery] = useState("");
  const [results, setResults] = useState<SearchHit[] | null>(null);
  const [searching, setSearching] = useState(false);

  useEffect(() => {
    fetch("/api/memory").then(r => r.json()).then(setData).catch(() => setData({ ok: false, error: "Failed to load" })).finally(() => setLoading(false));
  }, []);

  const runSearch = useCallback(async (qOverride?: string) => {
    const q = (qOverride ?? query).trim();
    if (!q) { setResults(null); return; }
    setSearching(true);
    try {
      const r = await fetch(`/api/memory?q=${encodeURIComponent(q)}`);
      const j = await r.json();
      setResults(j.ok ? j.results : []);
    } catch { setResults([]); }
    finally { setSearching(false); }
  }, [query]);

  const s = data?.stats;

  return (
    <div>
      <SectionHeader kicker="SYSTEM / MEMORY" title="Memory & Knowledge" />

      <MemoryConstellation onSearch={(name) => { setQuery(name); runSearch(name); }} />

      {/* Real stats from the vault */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-3 mb-8">
        <StatTile label="TOTAL FILES"   value={loading ? "—" : String(s?.total ?? 0)}         sub="IN VAULT"       accent="amber"   sparkSeed={3} />
        <StatTile label="PROJECT BRIEFS" value={loading ? "—" : String(s?.briefs ?? 0)}        sub="KNOWLEDGE BASE" accent="cyan"    sparkSeed={5} />
        <StatTile label="CONVERSATIONS"  value={loading ? "—" : String(s?.conversations ?? 0)} sub="AGENT THREADS"  accent="emerald" sparkSeed={9} />
        <StatTile label="CONTEXT FILES"  value={loading ? "—" : String(s?.context ?? 0)}       sub="ALWAYS-ON"      accent="violet"  sparkSeed={2} />
      </div>

      {!loading && data && !data.ok && (
        <div className="rounded-2xl border border-rose-500/20 bg-rose-500/[0.04] p-4 mb-6 text-[12px] text-rose-300/80 font-mono">
          Memory source unavailable: {data.error}
        </div>
      )}

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-3 mb-6">
        {/* Knowledge breakdown — real counts */}
        <div className="rounded-2xl border border-white/[0.07] bg-white/[0.02] p-6">
          <div className="flex items-center gap-2 mb-4">
            <Layers className="h-3.5 w-3.5 text-amber-400" />
            <span className="font-mono text-[10px] tracking-[0.28em] text-white/80">KNOWLEDGE BREAKDOWN</span>
          </div>
          <div className="space-y-4">
            {([
              ["Project Briefs",  s?.briefs ?? 0,        "cyan"],
              ["Conversations",   s?.conversations ?? 0, "emerald"],
              ["Context Files",   s?.context ?? 0,       "amber"],
              ["Source Docs",     s?.sources ?? 0,       "violet"],
              ["Strategies",      s?.strategies ?? 0,    "rose"],
            ] as const).map(([k, v, col]) => {
              const c = COLOR_MAP[col as keyof typeof COLOR_MAP];
              const max = Math.max(1, s?.total ?? 1);
              const pct = ((v as number) / max) * 100;
              return (
                <div key={k}>
                  <div className="flex items-center justify-between mb-1.5">
                    <span className="text-[12px] text-white/75">{k}</span>
                    <span className="font-mono text-[10px] text-white/85 tabular-nums">{v}</span>
                  </div>
                  <div className="h-1.5 bg-white/[0.05] rounded-full overflow-hidden">
                    <motion.div className="h-full rounded-full" style={{ background: c.hex, boxShadow: `0 0 6px ${c.glow}` }}
                      initial={{ width: 0 }} animate={{ width: `${pct}%` }} transition={{ duration: 1 }} />
                  </div>
                </div>
              );
            })}
          </div>
        </div>

        {/* Recently updated — real files */}
        <div className="rounded-2xl border border-white/[0.07] bg-white/[0.02] p-6">
          <div className="flex items-center gap-2 mb-4">
            <FileText className="h-3.5 w-3.5 text-amber-400" />
            <span className="font-mono text-[10px] tracking-[0.28em] text-white/80">RECENTLY UPDATED</span>
          </div>
          <div className="space-y-1.5">
            {loading && <div className="flex items-center gap-2 text-white/40 text-[12px]"><Loader2 className="h-3.5 w-3.5 animate-spin" /> Reading vault…</div>}
            {!loading && (data?.recent ?? []).map((f, i) => {
              const meta = KIND_META[f.kind] || KIND_META.other;
              const c = COLOR_MAP[meta.color as keyof typeof COLOR_MAP];
              const Icon = meta.icon;
              return (
                <motion.div key={f.name + i}
                  initial={{ opacity: 0, x: -8 }} animate={{ opacity: 1, x: 0 }} transition={{ delay: i * 0.03 }}
                  className="flex items-center gap-3 rounded-xl border border-white/[0.05] p-3">
                  <div className="h-8 w-8 rounded-lg grid place-items-center shrink-0" style={{ background: c.soft, border: `1px solid ${c.hex}33` }}>
                    <Icon className="h-3.5 w-3.5" style={{ color: c.hex }} strokeWidth={1.5} />
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="text-[12px] text-white/85 truncate">{f.name}</div>
                    <div className="text-[10px] text-white/40 mt-0.5">{meta.label}{f.project && f.project !== f.name ? ` · ${f.project}` : ""} · {kb(f.size)}</div>
                  </div>
                  <span className="font-mono text-[10px] tracking-[0.18em] text-white/40 shrink-0">{ago(f.updated)}</span>
                </motion.div>
              );
            })}
            {!loading && (data?.recent ?? []).length === 0 && (
              <div className="text-[12px] text-white/40">No files found in vault.</div>
            )}
          </div>
        </div>
      </div>

      {/* Working keyword search */}
      <div className="rounded-2xl border border-white/[0.07] bg-white/[0.02] p-6">
        <div className="flex items-center gap-2 mb-3">
          <Search className="h-3.5 w-3.5 text-amber-400" />
          <span className="font-mono text-[10px] tracking-[0.28em] text-white/80">SEARCH MEMORY</span>
        </div>
        <div className="flex items-center gap-2 rounded-full border border-white/10 bg-black/40 px-4 py-1">
          <span className="text-amber-400 font-mono">⌕</span>
          <input
            value={query}
            onChange={e => setQuery(e.target.value)}
            onKeyDown={e => { if (e.key === "Enter") runSearch(); }}
            placeholder="Keyword search across briefs, conversations, context…"
            className="flex-1 bg-transparent py-2.5 text-[13px] text-white placeholder-white/30 outline-none"
          />
          <button onClick={() => runSearch()} disabled={searching}
            className="px-4 py-1.5 rounded-full bg-amber-400 text-black text-[11px] tracking-[0.18em] font-mono font-medium hover:bg-amber-300 disabled:opacity-50 flex items-center gap-1.5">
            {searching ? <Loader2 className="h-3 w-3 animate-spin" /> : null}
            SEARCH
          </button>
        </div>

        {results !== null && (
          <div className="mt-4 space-y-1.5">
            <div className="font-mono text-[10px] tracking-[0.2em] text-white/40 mb-2">
              {results.length} {results.length === 1 ? "MATCH" : "MATCHES"}
            </div>
            {results.map((r, i) => {
              const meta = KIND_META[r.kind] || KIND_META.other;
              const c = COLOR_MAP[meta.color as keyof typeof COLOR_MAP];
              return (
                <motion.div key={r.name + i}
                  initial={{ opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: i * 0.02 }}
                  className="rounded-xl border border-white/[0.05] p-3">
                  <div className="flex items-center gap-2 mb-1">
                    <span className="h-1.5 w-1.5 rounded-full shrink-0" style={{ background: c.hex, boxShadow: `0 0 6px ${c.glow}` }} />
                    <span className="text-[12px] text-white/85">{r.name}</span>
                    <span className="font-mono text-[9px] tracking-[0.18em] text-white/35 uppercase">{meta.label}{r.project && r.project !== r.name ? ` · ${r.project}` : ""}</span>
                  </div>
                  <div className="text-[11px] text-white/45 leading-relaxed pl-3.5">…{r.snippet}…</div>
                </motion.div>
              );
            })}
            {results.length === 0 && <div className="text-[12px] text-white/40">No matches found.</div>}
          </div>
        )}
      </div>
    </div>
  );
}
