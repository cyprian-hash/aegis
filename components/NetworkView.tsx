"use client";
import { motion } from "framer-motion";
import { Globe, Shield } from "lucide-react";
import Constellation from "./Constellation";
import SectionHeader from "./SectionHeader";
import { AGENTS } from "@/lib/agents";

export default function NetworkView({ onSelect }: { onSelect: (a: any) => void }) {
  return (
    <div>
      <SectionHeader kicker="SYSTEM / NETWORK" title="Network Topology" />
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-3 mb-8">
        <div className="lg:col-span-2"><Constellation agents={AGENTS} onSelect={onSelect} /></div>
        <div className="space-y-3">
          <div className="rounded-2xl border border-white/[0.07] bg-white/[0.02] p-5">
            <div className="flex items-center gap-2 mb-4">
              <Shield className="h-3.5 w-3.5 text-amber-400" />
              <span className="font-mono text-[10px] tracking-[0.28em] text-white/80">SECURE LINK</span>
            </div>
            <div className="space-y-3 font-mono">
              <div className="flex justify-between text-[11px]"><span className="text-white/40">Protocol</span><span className="text-white/85">TLS 1.3</span></div>
              <div className="flex justify-between text-[11px]"><span className="text-white/40">Cipher</span><span className="text-white/85">CHACHA20-POLY1305</span></div>
              <div className="flex justify-between text-[11px]"><span className="text-white/40">Cert</span><span className="text-emerald-400">VERIFIED</span></div>
              <div className="flex justify-between text-[11px]"><span className="text-white/40">Bandwidth</span><span className="text-white/85 tabular-nums">12.4 MB/s</span></div>
            </div>
          </div>

          <div className="rounded-2xl border border-white/[0.07] bg-white/[0.02] p-5">
            <div className="flex items-center gap-2 mb-4">
              <Globe className="h-3.5 w-3.5 text-amber-400" />
              <span className="font-mono text-[10px] tracking-[0.28em] text-white/80">UPSTREAM</span>
            </div>
            <div className="space-y-2.5 font-mono">
              {[
                ["api.anthropic.com",     "12ms", "emerald"],
                ["mcp.notion.com",        "84ms", "emerald"],
                ["drivemcp.googleapis.com", "61ms", "emerald"],
                ["mcp.vercel.com",        "94ms", "emerald"],
                ["mcp.canva.com",         "—",    "white"],
              ].map(([host, lat, col]) => (
                <div key={host as string} className="flex items-center justify-between text-[11px]">
                  <div className="flex items-center gap-2 text-white/70">
                    <motion.span className={`h-1.5 w-1.5 rounded-full ${col === "emerald" ? "bg-emerald-400" : "bg-white/30"}`}
                      animate={col === "emerald" ? { opacity: [1, 0.4, 1] } : {}} transition={{ duration: 1.8, repeat: Infinity }} />
                    {host}
                  </div>
                  <span className="text-white/40 tabular-nums">{lat}</span>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>

      <SectionHeader kicker="LINKS" title="Active Connections" />
      <div className="rounded-2xl border border-white/[0.07] bg-black/30 overflow-hidden">
        <div className="grid grid-cols-[1fr_120px_100px_100px_80px] gap-3 px-4 py-2.5 border-b border-white/[0.06] font-mono text-[9px] tracking-[0.25em] text-white/40">
          <div>SOURCE → TARGET</div><div>PROTOCOL</div><div>LATENCY</div><div>BYTES</div><div>STATUS</div>
        </div>
        {[
          ["operator → claude.prime",  "HTTPS/SSE", "12ms",  "8.4k"],
          ["claude.prime → forge-02",  "INTERNAL",  "3ms",   "12.1k"],
          ["forge-02 → archive-03",    "INTERNAL",  "8ms",   "3.4k"],
          ["scout-01 → web/anthropic", "HTTPS",     "184ms", "44.2k"],
          ["weaver-04 → mcp/notion",   "MCP",       "84ms",  "1.2k"],
        ].map((row, i) => (
          <motion.div key={i}
            initial={{ opacity: 0, x: -8 }} animate={{ opacity: 1, x: 0 }} transition={{ delay: i * 0.05 }}
            className="grid grid-cols-[1fr_120px_100px_100px_80px] gap-3 px-4 py-2.5 border-b border-white/[0.04] last:border-b-0 font-mono text-[11px]">
            <span className="text-white/85">{row[0]}</span>
            <span className="text-white/60 tracking-[0.15em]">{row[1]}</span>
            <span className="text-white/70 tabular-nums">{row[2]}</span>
            <span className="text-white/70 tabular-nums">{row[3]}</span>
            <span className="flex items-center gap-1.5">
              <span className="h-1.5 w-1.5 rounded-full bg-emerald-400" />
              <span className="text-emerald-400 text-[9px] tracking-[0.2em]">OK</span>
            </span>
          </motion.div>
        ))}
      </div>
    </div>
  );
}
