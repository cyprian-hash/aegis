"use client";
import { ReactNode } from "react";

export default function SectionHeader({ kicker, title, right }: { kicker: string; title: string; right?: ReactNode }) {
  return (
    <div className="flex items-end justify-between mb-6 flex-wrap gap-3">
      <div>
        <div className="font-mono text-[10px] tracking-[0.35em] text-amber-400/80 mb-2 flex items-center gap-2.5">
          <span className="h-px w-7 bg-amber-400/50" />
          {kicker}
        </div>
        <h2 className="font-display text-2xl md:text-3xl text-white tracking-tight">{title}</h2>
      </div>
      {right}
    </div>
  );
}
