"use client";
import { Network } from "lucide-react";
import { COLOR_MAP } from "@/lib/theme";
import { Agent } from "@/lib/agents";

export default function Constellation({ agents, onSelect }: { agents: Agent[]; onSelect?: (a: Agent) => void }) {
  const cx = 200, cy = 200, R = 140;
  return (
    <div className="rounded-2xl border border-white/[0.07] bg-white/[0.02] p-5 h-full">
      <div className="flex items-center justify-between mb-3">
        <div className="flex items-center gap-2">
          <Network className="h-3.5 w-3.5 text-amber-400" strokeWidth={1.5} />
          <span className="font-mono text-[10px] tracking-[0.28em] text-white/80">AGENT MESH</span>
        </div>
        <span className="font-mono text-[9px] tracking-[0.22em] text-white/40">{agents.length} NODES</span>
      </div>
      <svg viewBox="0 0 400 400" className="w-full">
        <defs>
          <radialGradient id="core-glow" cx="50%" cy="50%" r="50%">
            <stop offset="0%" stopColor="#f5b400" stopOpacity="0.45" />
            <stop offset="100%" stopColor="#f5b400" stopOpacity="0" />
          </radialGradient>
        </defs>
        {[60, 100, 140, 180].map((r) => (
          <circle key={r} cx={cx} cy={cy} r={r} fill="none" stroke="rgba(255,255,255,0.05)" strokeDasharray="2 4" />
        ))}
        <circle cx={cx} cy={cy} r={75} fill="url(#core-glow)" />
        {agents.map((a, i) => {
          const angle = (i / agents.length) * Math.PI * 2 - Math.PI / 2;
          const x = cx + Math.cos(angle) * R;
          const y = cy + Math.sin(angle) * R;
          const c = COLOR_MAP[a.color];
          return (
            <g key={`edge-${a.id}`}>
              <line x1={cx} y1={cy} x2={x} y2={y} stroke={c.hex} strokeOpacity="0.22" strokeWidth="1" strokeDasharray="3 6">
                <animate attributeName="stroke-dashoffset" from="0" to="-18" dur="2s" repeatCount="indefinite" />
              </line>
            </g>
          );
        })}
        <circle cx={cx} cy={cy} r="16" fill="#0a0a0a" stroke="#f5b400" strokeWidth="1.5" />
        <circle cx={cx} cy={cy} r="7" fill="#f5b400">
          <animate attributeName="r" values="7;9;7" dur="2s" repeatCount="indefinite" />
        </circle>
        <text x={cx} y={cy + 34} textAnchor="middle" fill="rgba(255,255,255,0.5)" fontSize="9" letterSpacing="2" fontFamily="JetBrains Mono">CORE</text>
        {agents.map((a, i) => {
          const angle = (i / agents.length) * Math.PI * 2 - Math.PI / 2;
          const x = cx + Math.cos(angle) * R;
          const y = cy + Math.sin(angle) * R;
          const c = COLOR_MAP[a.color];
          return (
            <g key={a.id} onClick={() => onSelect?.(a)} style={{ cursor: "pointer" }}>
              <circle cx={x} cy={y} r="22" fill={c.soft} stroke={c.hex} strokeOpacity="0.4" />
              <circle cx={x} cy={y} r="7" fill={c.hex}>
                <animate attributeName="opacity" values="1;0.5;1" dur={`${1.5 + i * 0.2}s`} repeatCount="indefinite" />
              </circle>
              <text x={x} y={y + 38} textAnchor="middle" fill="rgba(255,255,255,0.65)" fontSize="9" letterSpacing="1.5" fontFamily="Space Grotesk" fontWeight="500">
                {a.shortName}
              </text>
            </g>
          );
        })}
      </svg>
    </div>
  );
}
