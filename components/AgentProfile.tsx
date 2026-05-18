"use client";
import { motion } from "framer-motion";
import { ArrowLeft, MessageCircle, Play, Pause, CheckCircle2, AlertCircle, Info, Sparkles } from "lucide-react";
import { Agent } from "@/lib/agents";
import { COLOR_MAP, fmtNum, pad } from "@/lib/theme";
import AgentAvatar from "./AgentAvatar";
import Ring from "./Ring";

export default function AgentProfile({
  agent, onBack, onOpenChat,
}: {
  agent: Agent;
  onBack: () => void;
  onOpenChat: () => void;
}) {
  const c = COLOR_MAP[agent.color];
  const Icon = agent.icon;

  return (
    <motion.div
      initial={{ opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.4, ease: [0.22, 1, 0.36, 1] }}
    >
      {/* Back nav */}
      <button onClick={onBack}
        className="mb-6 flex items-center gap-2 font-mono text-[10px] tracking-[0.25em] text-white/50 hover:text-white">
        <ArrowLeft className="h-3 w-3" /> ALL AGENTS
      </button>

      {/* HERO */}
      <div className="relative border border-white/[0.06] rounded-2xl bg-white/[0.015] overflow-hidden mb-6">
        <div className="absolute inset-0 opacity-50 pointer-events-none"
          style={{ background: `radial-gradient(ellipse 80% 50% at 20% 0%, ${c.soft}, transparent 60%)` }} />
        <div className="absolute -top-20 -right-20 h-72 w-72 rounded-full opacity-20 pointer-events-none"
          style={{ background: `radial-gradient(circle, ${c.hex}, transparent 70%)` }} />

        <div className="relative p-7 md:p-10">
          <div className="flex flex-col md:flex-row items-start gap-6">
            <div className="relative">
              <AgentAvatar agentId={agent.id} size={120} />
              <span
                className="absolute bottom-2 right-2 h-4 w-4 rounded-full border-4 border-[#070707]"
                style={{ background: agent.status === "online" ? "#34d399" : agent.status === "idle" ? "#f5b400" : "#94a3b8" }}
              />
            </div>

            <div className="flex-1 min-w-0">
              <div className="font-mono text-[10px] tracking-[0.3em] mb-2" style={{ color: c.hex }}>
                {agent.id.toUpperCase()} · {agent.joinedAt.toUpperCase()}
              </div>
              <h1 className="font-display text-4xl md:text-5xl text-white tracking-tight leading-none mb-2">
                {agent.name}
              </h1>
              <div className="text-[14px] text-white/60 mb-1">{agent.role}</div>
              <div className="text-[15px] text-white/80 max-w-2xl leading-relaxed mb-5">{agent.tagline}</div>

              <div className="flex items-center gap-2 flex-wrap">
                <motion.button
                  onClick={onOpenChat}
                  whileHover={{ y: -1 }}
                  whileTap={{ scale: 0.98 }}
                  className="flex items-center gap-2 px-5 py-2.5 rounded-full text-[12px] tracking-[0.18em] font-mono font-medium"
                  style={{ background: c.hex, color: "#000", boxShadow: `0 0 16px ${c.glow}` }}
                >
                  <MessageCircle className="h-3.5 w-3.5" strokeWidth={2.5} />
                  OPEN CHAT
                </motion.button>
                <button className="flex items-center gap-1.5 px-4 py-2.5 rounded-full border border-white/15 hover:border-white/40 hover:bg-white/5 text-[12px] tracking-[0.18em] font-mono text-white/80">
                  <Play className="h-3 w-3" strokeWidth={2} /> ENGAGE
                </button>
                <button className="flex items-center gap-1.5 px-4 py-2.5 rounded-full border border-white/15 hover:border-white/40 hover:bg-white/5 text-[12px] tracking-[0.18em] font-mono text-white/80">
                  <Pause className="h-3 w-3" strokeWidth={2} /> PAUSE
                </button>
              </div>
            </div>
          </div>

          {/* live rings */}
          <div className="grid grid-cols-3 gap-6 mt-8 pt-7 border-t border-white/[0.06]">
            <RingStat label="LOAD" value={agent.load} color={agent.color} />
            <RingStat label="CONTEXT" value={Math.min(99, Math.round(agent.tokens / 2500))} color="cyan" />
            <RingStat label="HEALTH" value={Math.max(8, 100 - Math.round(agent.latency / 6))} color="emerald" />
          </div>
        </div>
      </div>

      {/* META GRID */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mb-6">
        {[
          ["MODEL",    agent.model.replace("claude-", "")],
          ["TOKENS",   fmtNum(agent.tokens)],
          ["LATENCY",  `${agent.latency}ms`],
          ["TASKS",    pad(agent.tasks)],
        ].map(([k, v]) => (
          <div key={k} className="border border-white/[0.06] rounded-xl bg-white/[0.015] p-4">
            <div className="font-mono text-[9px] tracking-[0.25em] text-white/40 mb-1.5">{k}</div>
            <div className="font-display text-2xl text-white tabular-nums">{v}</div>
          </div>
        ))}
      </div>

      {/* Two columns */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-3 mb-6">
        {/* Capabilities */}
        <div className="border border-white/[0.06] rounded-2xl bg-white/[0.015] p-6">
          <div className="flex items-center gap-2 mb-5">
            <Sparkles className="h-3.5 w-3.5" style={{ color: c.hex }} strokeWidth={1.5} />
            <span className="font-mono text-[10px] tracking-[0.3em] text-white/80">CAPABILITIES</span>
          </div>
          <div className="space-y-3.5">
            {agent.capabilities.map((cap, i) => (
              <motion.div key={cap.name}
                initial={{ opacity: 0, x: -8 }} animate={{ opacity: 1, x: 0 }}
                transition={{ delay: i * 0.05 }}>
                <div className="flex items-center justify-between mb-1.5">
                  <span className="text-[13px] text-white/85">{cap.name}</span>
                  <span className="font-mono text-[10px] text-white/60 tabular-nums">{cap.level}</span>
                </div>
                <div className="h-1 bg-white/[0.05] rounded-full overflow-hidden">
                  <motion.div className="h-full rounded-full"
                    style={{ background: `linear-gradient(90deg, ${c.hex}, ${c.hex}99)`, boxShadow: `0 0 6px ${c.glow}` }}
                    initial={{ width: 0 }}
                    animate={{ width: `${cap.level}%` }}
                    transition={{ duration: 1, delay: i * 0.08, ease: [0.22, 1, 0.36, 1] }} />
                </div>
              </motion.div>
            ))}
          </div>

          <div className="mt-6 pt-5 border-t border-white/[0.06]">
            <div className="font-mono text-[10px] tracking-[0.3em] text-white/40 mb-3">SPECIALTIES</div>
            <div className="flex flex-wrap gap-1.5">
              {agent.specialties.map(s => (
                <span key={s} className="px-3 py-1.5 rounded-full text-[11px]"
                  style={{ background: c.soft, color: c.hex, border: `1px solid ${c.hex}33` }}>
                  {s}
                </span>
              ))}
            </div>
          </div>
        </div>

        {/* History */}
        <div className="border border-white/[0.06] rounded-2xl bg-white/[0.015] p-6">
          <div className="flex items-center gap-2 mb-5">
            <Info className="h-3.5 w-3.5" style={{ color: c.hex }} strokeWidth={1.5} />
            <span className="font-mono text-[10px] tracking-[0.3em] text-white/80">RECENT ACTIVITY</span>
          </div>
          <div className="space-y-2">
            {agent.history.map((h, i) => (
              <motion.div key={i}
                initial={{ opacity: 0, x: 8 }} animate={{ opacity: 1, x: 0 }}
                transition={{ delay: i * 0.05 }}
                className="flex items-start gap-3 p-3 rounded-xl bg-white/[0.02] border border-white/[0.04]">
                {h.result === "success" && <CheckCircle2 className="h-4 w-4 text-emerald-400 mt-0.5 shrink-0" strokeWidth={1.5} />}
                {h.result === "warn"    && <AlertCircle  className="h-4 w-4 text-amber-400   mt-0.5 shrink-0" strokeWidth={1.5} />}
                {h.result === "info"    && <Info         className="h-4 w-4 text-sky-300     mt-0.5 shrink-0" strokeWidth={1.5} />}
                <div className="flex-1 min-w-0">
                  <div className="text-[13px] text-white/90 leading-snug">{h.title}</div>
                  <div className="font-mono text-[10px] tracking-[0.15em] text-white/40 mt-0.5">{h.ts}</div>
                </div>
              </motion.div>
            ))}
          </div>
        </div>
      </div>

      {/* System prompt */}
      <div className="border border-white/[0.06] rounded-2xl bg-white/[0.015] p-6">
        <div className="flex items-center justify-between mb-3">
          <div className="flex items-center gap-2">
            <Icon className="h-3.5 w-3.5" style={{ color: c.hex }} strokeWidth={1.5} />
            <span className="font-mono text-[10px] tracking-[0.3em] text-white/80">SYSTEM PROMPT</span>
          </div>
          <span className="font-mono text-[9px] tracking-[0.2em] text-white/30">READ-ONLY</span>
        </div>
        <div className="font-mono text-[12px] text-white/75 leading-relaxed bg-black/30 rounded-lg p-4 border border-white/[0.04]">
          {agent.systemPrompt}
        </div>
      </div>
    </motion.div>
  );
}

function RingStat({ label, value, color }: { label: string; value: number; color: any }) {
  return (
    <div className="flex flex-col items-center gap-3">
      <Ring value={value} color={color} size={72} stroke={4} />
      <div className="font-mono text-[10px] tracking-[0.25em] text-white/50">{label}</div>
    </div>
  );
}
