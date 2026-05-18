"use client";
import { motion } from "framer-motion";
import { COLOR_MAP } from "@/lib/theme";

export default function Ring({
  value, color = "amber", size = 64, stroke = 3, label,
}: {
  value: number;
  color?: keyof typeof COLOR_MAP;
  size?: number;
  stroke?: number;
  label?: string;
}) {
  const c = COLOR_MAP[color];
  const r = (size - stroke) / 2;
  const cir = 2 * Math.PI * r;
  return (
    <div className="relative inline-flex items-center justify-center" style={{ width: size, height: size }}>
      <svg width={size} height={size} className="-rotate-90">
        <circle cx={size / 2} cy={size / 2} r={r} stroke="rgba(255,255,255,0.06)" strokeWidth={stroke} fill="none" />
        <motion.circle
          cx={size / 2} cy={size / 2} r={r} stroke={c.hex} strokeWidth={stroke} fill="none"
          strokeLinecap="round" strokeDasharray={cir}
          initial={{ strokeDashoffset: cir }}
          animate={{ strokeDashoffset: cir - (value / 100) * cir }}
          transition={{ duration: 1.2, ease: [0.22, 1, 0.36, 1] }}
          style={{ filter: `drop-shadow(0 0 6px ${c.glow})` }}
        />
      </svg>
      <div className="absolute inset-0 flex items-center justify-center">
        <div className="font-display text-[15px] text-white tabular-nums">{value}<span className="text-white/40 text-[11px]">%</span></div>
      </div>
      {label && (
        <div className="font-mono absolute -bottom-5 left-1/2 -translate-x-1/2 text-[9px] tracking-[0.2em] text-white/40 whitespace-nowrap">
          {label}
        </div>
      )}
    </div>
  );
}
