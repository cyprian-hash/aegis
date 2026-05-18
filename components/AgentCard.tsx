"use client";
import { motion } from "framer-motion";
import { MessageCircle, ArrowUpRight } from "lucide-react";
import { COLOR_MAP, pad } from "@/lib/theme";
import { Agent } from "@/lib/agents";
import AgentAvatar from "./AgentAvatar";

export default function AgentCard({
  agent, onClick, onChat, index = 0,
}: {
  agent: Agent;
  onClick?: (a: Agent) => void;
  onChat?: (a: Agent) => void;
  index?: number;
}) {
  const c = COLOR_MAP[agent.color];
  const statusColor = agent.status === "online" ? "#34d399" : agent.status === "idle" ? "#f5b400" : "#94a3b8";

  return (
    <motion.div
      initial={{ opacity: 0, y: 16 }} animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.5, delay: index * 0.06, ease: [0.22, 1, 0.36, 1] }}
      whileHover={{ y: -4 }}
      className="group relative cursor-pointer"
      onClick={() => onClick?.(agent)}
    >
      <div className="absolute -inset-px rounded-2xl opacity-0 group-hover:opacity-100 transition-opacity duration-300 blur-xl pointer-events-none"
        style={{ background: `radial-gradient(60% 60% at 50% 0%, ${c.hex}66, transparent)` }} />

      <div className="relative rounded-2xl border border-white/[0.08] bg-white/[0.02] backdrop-blur-sm overflow-hidden transition-colors group-hover:border-white/20">
        {/* color stripe at top */}
        <div className="h-[2px] w-full" style={{ background: `linear-gradient(90deg, transparent, ${c.hex}, transparent)` }} />

        {/* spotlight overlay */}
        <div className="absolute inset-0 opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none"
          style={{ background: `radial-gradient(400px circle at 50% 0%, ${c.soft}, transparent 70%)` }} />

        <div className="relative p-5">
          <div className="flex items-start justify-between mb-4">
            <div className="flex items-center gap-3">
              <div className="relative">
                <AgentAvatar agentId={agent.id} size={52} />
                <span
                  className="absolute bottom-0 right-0 h-3 w-3 rounded-full border-2 border-[#070707]"
                  style={{ background: statusColor }}
                />
              </div>
              <div>
                <div className="font-display text-[15px] text-white font-medium leading-tight">{agent.name}</div>
                <div className="text-[11px] text-white/50 mt-0.5">{agent.role}</div>
              </div>
            </div>
            <span className="font-mono text-[9px] tracking-[0.2em] uppercase text-white/50">{agent.status}</span>
          </div>

          <div className="text-[12px] text-white/65 leading-relaxed mb-5 line-clamp-2 min-h-[36px]">
            {agent.tagline}
          </div>

          <div className="grid grid-cols-3 gap-3 mb-4">
            <Stat label="MODEL" value={agent.model.replace("claude-", "")} mono />
            <Stat label="TASKS" value={pad(agent.tasks)} mono />
            <Stat label="LAT"   value={`${agent.latency}ms`} mono />
          </div>

          <div className="mb-2 flex items-center justify-between">
            <span className="font-mono text-[9px] tracking-[0.22em] text-white/40">LOAD</span>
            <span className="font-mono text-[10px] text-white/80 tabular-nums">{pad(agent.load)}%</span>
          </div>
          <div className="relative h-1.5 bg-white/[0.05] rounded-full overflow-hidden">
            <motion.div className="absolute inset-y-0 left-0 rounded-full"
              style={{ background: `linear-gradient(90deg, ${c.hex}, ${c.hex}cc)`, boxShadow: `0 0 8px ${c.glow}` }}
              initial={{ width: 0 }} animate={{ width: `${agent.load}%` }}
              transition={{ duration: 1, delay: 0.2 + index * 0.05 }}
            />
          </div>

          <div className="mt-5 pt-4 border-t border-white/[0.05] flex items-center gap-2">
            <button
              onClick={(e) => { e.stopPropagation(); onChat?.(agent); }}
              className="flex-1 flex items-center justify-center gap-1.5 py-2 rounded-full text-[11px] font-mono tracking-[0.18em] font-medium transition-all"
              style={{ background: c.hex, color: "#000", boxShadow: `0 0 12px ${c.glow}88` }}
            >
              <MessageCircle className="h-3 w-3" strokeWidth={2.5} /> CHAT
            </button>
            <button
              onClick={(e) => { e.stopPropagation(); onClick?.(agent); }}
              className="flex items-center justify-center gap-1 px-3 py-2 rounded-full border border-white/10 text-[11px] font-mono tracking-[0.18em] text-white/70 hover:text-white hover:border-white/30 transition-colors"
            >
              PROFILE <ArrowUpRight className="h-3 w-3" />
            </button>
          </div>
        </div>
      </div>
    </motion.div>
  );
}

function Stat({ label, value, mono }: { label: string; value: string; mono?: boolean }) {
  return (
    <div>
      <div className="font-mono text-[9px] tracking-[0.2em] text-white/30 mb-1">{label}</div>
      <div className={`text-[11px] text-white/85 truncate ${mono ? "font-mono" : ""}`}>{value}</div>
    </div>
  );
}
