"use client";
import { useEffect, useState } from "react";
import { motion } from "framer-motion";
import { Cpu, BarChart3, Activity, Zap, Clock, AlertTriangle } from "lucide-react";
import StatTile from "./StatTile";
import SectionHeader from "./SectionHeader";
import { COLOR_MAP, fmtNum } from "@/lib/theme";

export default function TelemetryView() {
  const [tick, setTick] = useState(0);
  useEffect(() => { const id = setInterval(() => setTick(t => t + 1), 1200); return () => clearInterval(id); }, []);

  const histogram = Array.from({ length: 24 }, (_, i) => 30 + Math.sin((i + tick) * 0.4) * 25 + ((i * 17 + tick * 3) % 13));

  return (
    <div>
      <SectionHeader kicker="SYSTEM / TELEMETRY" title="Performance Telemetry" />

      <div className="grid grid-cols-2 lg:grid-cols-4 gap-3 mb-6">
        <StatTile label="P50 LATENCY" value="284ms" sub="LAST 5 MIN"   accent="amber"   sparkSeed={4}  icon={Clock} />
        <StatTile label="P99 LATENCY" value="1.24s" sub="LAST 5 MIN"   accent="rose"    sparkSeed={9}  icon={AlertTriangle} />
        <StatTile label="TOKENS / HR" value="2.1M"  sub="ROLLING"      accent="cyan"    sparkSeed={6}  icon={Zap} />
        <StatTile label="UPTIME"      value="99.97%" sub="LAST 30 DAYS" accent="emerald" sparkSeed={11} icon={Activity} />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-3 mb-6">
        <div className="lg:col-span-2 rounded-2xl border border-white/[0.07] bg-white/[0.02] p-6">
          <div className="flex items-center justify-between mb-4">
            <div className="flex items-center gap-2">
              <BarChart3 className="h-3.5 w-3.5 text-amber-400" />
              <span className="font-mono text-[10px] tracking-[0.28em] text-white/80">REQUESTS / MIN · 24H</span>
            </div>
            <span className="font-mono text-[10px] tracking-[0.18em] text-white/40">PEAK 14:00 UTC</span>
          </div>
          <div className="h-[240px] flex items-end gap-1.5">
            {histogram.map((v, i) => (
              <motion.div
                key={i}
                initial={{ height: 0 }}
                animate={{ height: `${v}%` }}
                transition={{ duration: 0.8, delay: i * 0.02, ease: [0.22, 1, 0.36, 1] }}
                className="flex-1 relative group rounded-t"
              >
                <div className="absolute inset-0 rounded-t bg-gradient-to-t from-amber-400 to-amber-400/30"
                  style={{ boxShadow: "0 -4px 12px rgba(245,180,0,0.25)" }} />
                <div className="absolute -top-6 left-1/2 -translate-x-1/2 font-mono text-[9px] text-white/50 opacity-0 group-hover:opacity-100 transition-opacity">
                  {Math.round(v)}
                </div>
              </motion.div>
            ))}
          </div>
          <div className="flex justify-between mt-3 font-mono text-[9px] tracking-[0.18em] text-white/30">
            <span>00:00</span><span>06:00</span><span>12:00</span><span>18:00</span><span>24:00</span>
          </div>
        </div>

        <div className="rounded-2xl border border-white/[0.07] bg-white/[0.02] p-6">
          <div className="flex items-center gap-2 mb-4">
            <Cpu className="h-3.5 w-3.5 text-amber-400" />
            <span className="font-mono text-[10px] tracking-[0.28em] text-white/80">MODEL DISTRIBUTION</span>
          </div>
          <div className="space-y-4">
            {[
              ["opus-4.7", 48, "amber"],
              ["sonnet-4.6", 31, "cyan"],
              ["opus-4.6", 14, "violet"],
              ["haiku-4.5", 7, "emerald"],
            ].map(([model, pct, col]) => {
              const c = COLOR_MAP[col as keyof typeof COLOR_MAP];
              return (
                <div key={model as string}>
                  <div className="flex items-center justify-between mb-1.5">
                    <span className="font-mono text-[10px] tracking-[0.18em] text-white/70">{model}</span>
                    <span className="font-mono text-[10px] text-white/90 tabular-nums">{pct}%</span>
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
      </div>

      <SectionHeader kicker="LIVE STREAM" title="Real-time Diagnostics" />
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        {[
          ["INPUT TOKENS / SEC",  fmtNum(1840 + (tick % 200))],
          ["OUTPUT TOKENS / SEC", fmtNum(2840 + (tick % 320))],
          ["TOOL CALLS / MIN",    String(38 + (tick % 8))],
          ["ERROR RATE",          `${(0.04 + ((tick % 4) * 0.01)).toFixed(2)}%`],
        ].map(([k, v], i) => (
          <motion.div key={k as string}
            initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: i * 0.04 }}
            className="rounded-2xl border border-white/[0.07] bg-white/[0.02] p-4">
            <div className="font-mono text-[9px] tracking-[0.25em] text-white/40 mb-1.5">{k}</div>
            <div className="font-display text-2xl text-white tabular-nums">{v}</div>
          </motion.div>
        ))}
      </div>
    </div>
  );
}
