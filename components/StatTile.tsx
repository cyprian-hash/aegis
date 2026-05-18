"use client";
import { useMemo } from "react";
import { motion } from "framer-motion";
import { COLOR_MAP } from "@/lib/theme";

export default function StatTile({
  label, value, sub, accent = "amber", delay = 0, sparkSeed = 7, icon: Icon,
}: {
  label: string;
  value: string | number;
  sub?: string;
  accent?: keyof typeof COLOR_MAP;
  delay?: number;
  sparkSeed?: number;
  icon?: any;
}) {
  const c = COLOR_MAP[accent];

  const spark = useMemo(() => {
    const out: number[] = [];
    for (let i = 0; i < 24; i++) {
      const v = 18 + Math.sin(i * 0.6 + sparkSeed) * 8 + ((i * 13 + sparkSeed * 7) % 11) * 0.6;
      out.push(v);
    }
    return out;
  }, [sparkSeed]);

  const path = useMemo(() => {
    const w = 120, h = 32;
    const step = w / (spark.length - 1);
    return spark.map((v, i) => `${i === 0 ? "M" : "L"} ${i * step} ${h - v}`).join(" ");
  }, [spark]);

  return (
    <motion.div
      initial={{ opacity: 0, y: 14 }} animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.6, delay, ease: [0.22, 1, 0.36, 1] }}
      whileHover={{ y: -2 }}
      className="relative rounded-2xl border border-white/[0.07] bg-white/[0.02] backdrop-blur-sm p-5 overflow-hidden group transition-colors hover:border-white/15"
    >
      {/* hover glow */}
      <div className="absolute inset-0 opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none rounded-2xl"
        style={{ background: `radial-gradient(60% 60% at 50% 0%, ${c.soft}, transparent)` }} />

      {/* top color accent line */}
      <div className="absolute top-0 left-5 right-5 h-px" style={{ background: `linear-gradient(90deg, transparent, ${c.hex}55, transparent)` }} />

      <div className="relative flex items-center justify-between mb-3">
        <div className="font-mono text-[9px] tracking-[0.28em] text-white/40">{label}</div>
        {Icon && <Icon className="h-3.5 w-3.5" style={{ color: c.hex }} strokeWidth={1.5} />}
      </div>
      <div className="relative flex items-end justify-between gap-3">
        <div>
          <div className="font-display text-4xl text-white tabular-nums leading-none">{value}</div>
          {sub && <div className="font-mono mt-2 text-[10px] tracking-[0.15em] text-white/40">{sub}</div>}
        </div>
        <svg width="120" height="32" className="opacity-90 shrink-0">
          <defs>
            <linearGradient id={`grad-${accent}-${sparkSeed}`} x1="0" x2="0" y1="0" y2="1">
              <stop offset="0%" stopColor={c.hex} stopOpacity="0.5" />
              <stop offset="100%" stopColor={c.hex} stopOpacity="0" />
            </linearGradient>
          </defs>
          <path d={`${path} L 120 32 L 0 32 Z`} fill={`url(#grad-${accent}-${sparkSeed})`} />
          <path d={path} fill="none" stroke={c.hex} strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round" />
          <circle cx="120" cy={32 - spark[spark.length - 1]} r="2.5" fill={c.hex}>
            <animate attributeName="r" values="2.5;3.6;2.5" dur="1.6s" repeatCount="indefinite" />
          </circle>
        </svg>
      </div>
    </motion.div>
  );
}
