"use client";
import { useEffect, useState } from "react";
import { motion } from "framer-motion";
import { fmtTime } from "@/lib/theme";

export default function StatusBar() {
  const [now, setNow] = useState<Date | null>(null);
  useEffect(() => {
    setNow(new Date());
    const id = setInterval(() => setNow(new Date()), 1000);
    return () => clearInterval(id);
  }, []);
  return (
    <div className="flex items-center justify-between border-b border-white/[0.06] px-6 py-3 text-[10px] tracking-[0.22em] text-white/50 font-mono backdrop-blur-xl bg-black/20">
      <div className="flex items-center gap-5">
        <div className="flex items-center gap-2">
          <motion.span className="block h-1.5 w-1.5 rounded-full bg-amber-400"
            animate={{ opacity: [1, 0.3, 1], boxShadow: ["0 0 4px #f5b400", "0 0 12px #f5b400", "0 0 4px #f5b400"] }}
            transition={{ duration: 1.6, repeat: Infinity }} />
          <span className="text-white/80">AEGIS · MISSION CONTROL</span>
        </div>
        <span className="text-white/25 hidden sm:inline">v4.7.0</span>
        <span className="hidden md:inline text-white/30">SECURE · ANTHROPIC UPLINK</span>
      </div>
      <div className="flex items-center gap-5">
        <span className="hidden sm:inline text-white/40">
          <span className="text-emerald-400">●</span> NOMINAL
        </span>
        <span className="text-white/70 tabular-nums">{now ? fmtTime(now) : "--:--:-- UTC"}</span>
      </div>
    </div>
  );
}
