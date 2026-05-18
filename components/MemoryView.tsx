"use client";
import { motion } from "framer-motion";
import { Database, FileText, Layers, Search } from "lucide-react";
import StatTile from "./StatTile";
import SectionHeader from "./SectionHeader";
import { COLOR_MAP } from "@/lib/theme";

export default function MemoryView() {
  return (
    <div>
      <SectionHeader kicker="SYSTEM / MEMORY" title="Memory & Knowledge" />

      <div className="grid grid-cols-2 lg:grid-cols-4 gap-3 mb-8">
        <StatTile label="VECTOR DIM" value="1536"   sub="OPENAI/V3"  accent="amber"   sparkSeed={3} />
        <StatTile label="DOCUMENTS"  value="1.42M"  sub="INDEXED"     accent="cyan"    sparkSeed={5} />
        <StatTile label="CHUNKS"     value="4.18M"  sub="EMBEDDED"    accent="violet"  sparkSeed={9} />
        <StatTile label="HIT RATE"   value="92.4%"  sub="LAST 24H"    accent="emerald" sparkSeed={2} />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-3 mb-6">
        <div className="rounded-2xl border border-white/[0.07] bg-white/[0.02] p-6">
          <div className="flex items-center gap-2 mb-4">
            <Database className="h-3.5 w-3.5 text-amber-400" />
            <span className="font-mono text-[10px] tracking-[0.28em] text-white/80">CORPUS BREAKDOWN</span>
          </div>
          <div className="space-y-4">
            {[
              ["Mission logs",      412341, "amber"],
              ["Code repositories", 284922, "violet"],
              ["Research notes",    148230, "cyan"],
              ["Conversations",     298184, "emerald"],
              ["External docs",     278123, "rose"],
            ].map(([k, v, col]) => {
              const c = COLOR_MAP[col as keyof typeof COLOR_MAP];
              const max = 412341;
              const pct = ((v as number) / max) * 100;
              return (
                <div key={k as string}>
                  <div className="flex items-center justify-between mb-1.5">
                    <span className="text-[12px] text-white/75">{k}</span>
                    <span className="font-mono text-[10px] text-white/85 tabular-nums">{(v as number).toLocaleString()}</span>
                  </div>
                  <div className="h-1.5 bg-white/[0.05] rounded-full overflow-hidden">
                    <motion.div className="h-full rounded-full" style={{ background: c.hex, boxShadow: `0 0 6px ${c.glow}` }}
                      initial={{ width: 0 }} whileInView={{ width: `${pct}%` }} viewport={{ once: true }}
                      transition={{ duration: 1 }} />
                  </div>
                </div>
              );
            })}
          </div>
        </div>

        <div className="rounded-2xl border border-white/[0.07] bg-white/[0.02] p-6">
          <div className="flex items-center gap-2 mb-4">
            <Layers className="h-3.5 w-3.5 text-amber-400" />
            <span className="font-mono text-[10px] tracking-[0.28em] text-white/80">RECENT INDEXING</span>
          </div>
          <div className="space-y-1.5">
            {[
              ["docs/api-reference",      "12s ago", "412 chunks",  "emerald"],
              ["missions/M-0042",         "1m ago",  "28 chunks",   "amber"],
              ["repo/aegis-core",         "4m ago",  "1.2k chunks", "violet"],
              ["notes/quantum-research",  "12m ago", "84 chunks",   "cyan"],
              ["chat/2026-05-17",         "18m ago", "62 chunks",   "rose"],
            ].map(([name, when, count, col]) => {
              const c = COLOR_MAP[col as keyof typeof COLOR_MAP];
              return (
                <motion.div key={name as string}
                  initial={{ opacity: 0, x: -8 }} whileInView={{ opacity: 1, x: 0 }} viewport={{ once: true }}
                  className="flex items-center gap-3 rounded-xl border border-white/[0.05] p-3">
                  <div className="h-8 w-8 rounded-lg grid place-items-center" style={{ background: c.soft, border: `1px solid ${c.hex}33` }}>
                    <FileText className="h-3.5 w-3.5" style={{ color: c.hex }} strokeWidth={1.5} />
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="text-[12px] text-white/85 truncate font-mono">{name}</div>
                    <div className="text-[10px] text-white/40 mt-0.5">{count}</div>
                  </div>
                  <span className="font-mono text-[10px] tracking-[0.18em] text-white/40">{when}</span>
                </motion.div>
              );
            })}
          </div>
        </div>
      </div>

      <div className="rounded-2xl border border-white/[0.07] bg-white/[0.02] p-6">
        <div className="flex items-center gap-2 mb-3">
          <Search className="h-3.5 w-3.5 text-amber-400" />
          <span className="font-mono text-[10px] tracking-[0.28em] text-white/80">QUERY THE INDEX</span>
        </div>
        <div className="flex items-center gap-2 rounded-full border border-white/10 bg-black/40 px-4 py-1">
          <span className="text-amber-400 font-mono">⌕</span>
          <input
            placeholder="Semantic search across all indexed memory…"
            className="flex-1 bg-transparent py-2.5 text-[13px] text-white placeholder-white/30 outline-none"
          />
          <button className="px-4 py-1.5 rounded-full bg-amber-400 text-black text-[11px] tracking-[0.18em] font-mono font-medium hover:bg-amber-300">
            SEARCH
          </button>
        </div>
      </div>
    </div>
  );
}
