"use client";
import { useEffect, useMemo, useState } from "react";
import { motion } from "framer-motion";
import { Sparkles, Bot, Globe, Cpu, ArrowRight, MessageSquare, Activity, Zap, Database } from "lucide-react";
import { AGENTS, Agent } from "@/lib/agents";
import { COLOR_MAP, fmtNum } from "@/lib/theme";
import StatTile from "./StatTile";
import AgentCard from "./AgentCard";
import LiveFeed from "./LiveFeed";
import Constellation from "./Constellation";
import SectionHeader from "./SectionHeader";
import Waveform from "./Waveform";
import AgentAvatar from "./AgentAvatar";

export default function OverviewView({
  onProfileAgent, onChatAgent, onGo,
}: {
  onProfileAgent: (a: Agent) => void;
  onChatAgent: (a: Agent) => void;
  onGo: (id: any) => void;
}) {
  const [tick, setTick] = useState(0);
  useEffect(() => { const id = setInterval(() => setTick(t => t + 1), 1500); return () => clearInterval(id); }, []);

  const tokensPerSec = useMemo(() => 2840 + Math.round(Math.sin(tick / 3) * 320), [tick]);
  const meshLoad = useMemo(() => 42 + Math.round(Math.sin(tick / 5) * 14), [tick]);
  const activeTasks = AGENTS.reduce((a, b) => a + b.tasks, 0);

  return (
    <>
      {/* HERO */}
      <motion.div initial={{ opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.7 }} className="mb-10">
        <div className="flex items-end justify-between flex-wrap gap-4">
          <div>
            <motion.div
              initial={{ opacity: 0, x: -8 }} animate={{ opacity: 1, x: 0 }} transition={{ delay: 0.1 }}
              className="font-mono text-[10px] tracking-[0.4em] text-amber-400/90 mb-3 flex items-center gap-2"
            >
              <motion.span animate={{ scale: [1, 1.4, 1] }} transition={{ duration: 1.6, repeat: Infinity }}
                className="block h-1.5 w-1.5 rounded-full bg-amber-400"
                style={{ boxShadow: "0 0 8px #f5b400" }} />
              MISSION CONTROL · OPERATIONAL
            </motion.div>
            <h1 className="font-display text-5xl md:text-7xl text-white tracking-tight leading-[0.95]">
              Good evening,<br />
              <span className="bg-gradient-to-r from-white/40 via-white/60 to-white/30 bg-clip-text text-transparent">Commander.</span>
            </h1>
            <div className="mt-5 flex items-center gap-4 text-[12px] text-white/55 font-mono flex-wrap">
              <span>{AGENTS.length} AGENTS ONLINE</span>
              <span className="h-3 w-px bg-white/20" />
              <span>{activeTasks} ACTIVE TASKS</span>
              <span className="h-3 w-px bg-white/20" />
              <span className="text-emerald-400">● MESH NOMINAL</span>
            </div>
          </div>

          <div className="flex items-center gap-2">
            <button onClick={() => onGo("missions")}
              className="px-5 py-3 rounded-full border border-white/10 text-white/75 hover:text-white hover:border-white/30 text-[12px] tracking-[0.18em] font-mono flex items-center gap-2 transition-colors">
              NEW MISSION
            </button>
            <motion.button onClick={() => onGo("chat")}
              whileHover={{ y: -1 }} whileTap={{ scale: 0.97 }}
              className="px-5 py-3 rounded-full bg-amber-400 text-black hover:bg-amber-300 text-[12px] tracking-[0.18em] font-mono font-medium flex items-center gap-2"
              style={{ boxShadow: "0 0 20px rgba(245,180,0,0.4)" }}>
              <Sparkles className="h-3.5 w-3.5" strokeWidth={2} /> SUMMON CLAUDE
            </motion.button>
          </div>
        </div>

        {/* Cognition strip */}
        <motion.div
          initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.2 }}
          className="mt-8 rounded-2xl border border-white/[0.07] bg-white/[0.02] backdrop-blur px-5 py-4 flex items-center gap-5 flex-wrap"
        >
          <div className="flex items-center gap-2">
            <motion.span animate={{ scale: [1, 1.4, 1] }} transition={{ duration: 1.4, repeat: Infinity }}
              className="block h-2 w-2 rounded-full bg-amber-400"
              style={{ boxShadow: "0 0 8px #f5b400" }} />
            <span className="font-mono text-[10px] tracking-[0.28em] text-white/75">LIVE COGNITION</span>
          </div>
          <Waveform />
          <div className="ml-auto flex items-center gap-4 text-[11px] tracking-[0.18em] text-white/50 font-mono">
            <span className="tabular-nums">{fmtNum(tokensPerSec)} TOK/S</span>
            <span className="text-emerald-400">↑ +12%</span>
          </div>
        </motion.div>
      </motion.div>

      {/* STAT TILES */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-3 mb-12">
        <StatTile label="THROUGHPUT"   value={fmtNum(tokensPerSec)} sub="TOKENS / SEC"     accent="amber"   delay={0.05} sparkSeed={3} icon={Zap}      />
        <StatTile label="MESH LOAD"    value={`${meshLoad}%`}        sub="AVG · 6 AGENTS"   accent="cyan"    delay={0.10} sparkSeed={8} icon={Activity} />
        <StatTile label="ACTIVE TASKS" value={fmtNum(activeTasks)}   sub="IN-FLIGHT"        accent="emerald" delay={0.15} sparkSeed={5} icon={Bot}      />
        <StatTile label="MEMORY INDEX" value="1.42M"                 sub="VECTORIZED DOCS"  accent="violet"  delay={0.20} sparkSeed={2} icon={Database} />
      </div>

      {/* AGENTS */}
      <SectionHeader
        kicker="FLEET / 06"
        title="Your Agents"
        right={
          <button onClick={() => onGo("agents")}
            className="flex items-center gap-1.5 text-[12px] tracking-[0.18em] font-mono text-white/50 hover:text-white">
            ALL AGENTS <ArrowRight className="h-3 w-3" />
          </button>
        }
      />
      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-3 mb-12">
        {AGENTS.map((a, i) => (
          <AgentCard
            key={a.id} agent={a} index={i}
            onClick={onProfileAgent}
            onChat={onChatAgent}
          />
        ))}
      </div>

      {/* CHAT SHORTCUT + LIVE FEED */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-3 mb-12">
        <motion.div
          initial={{ opacity: 0, y: 10 }} whileInView={{ opacity: 1, y: 0 }} viewport={{ once: true }}
          className="lg:col-span-2 rounded-2xl border border-white/[0.07] bg-gradient-to-br from-white/[0.02] to-transparent overflow-hidden relative"
        >
          <div className="absolute inset-0 opacity-30 pointer-events-none"
            style={{ background: "radial-gradient(ellipse 80% 60% at 0% 100%, rgba(245,180,0,0.18), transparent 60%)" }} />
          <div className="relative p-6 md:p-8">
            <div className="font-mono text-[10px] tracking-[0.3em] text-amber-400/80 mb-2">DIRECT LINE</div>
            <h3 className="font-display text-2xl md:text-3xl text-white mb-2 tracking-tight">Talk to any agent.</h3>
            <p className="text-[14px] text-white/60 max-w-md leading-relaxed mb-6">
              Real Claude streaming, end-to-end. Each agent has its own personality, model, and system prompt.
            </p>

            <div className="flex items-center gap-2 mb-5">
              {AGENTS.map(a => (
                <button key={a.id} onClick={() => onChatAgent(a)}
                  className="group relative"
                  title={`Chat with ${a.shortName}`}>
                  <div className="transition-transform group-hover:scale-110">
                    <AgentAvatar agentId={a.id} size={40} />
                  </div>
                  <span className="absolute -bottom-5 left-1/2 -translate-x-1/2 font-mono text-[9px] tracking-[0.18em] text-white/0 group-hover:text-white/60 transition-colors whitespace-nowrap">
                    {a.shortName.toUpperCase()}
                  </span>
                </button>
              ))}
            </div>

            <button onClick={() => onGo("chat")}
              className="inline-flex items-center gap-2 px-5 py-2.5 rounded-full bg-amber-400 text-black hover:bg-amber-300 text-[12px] tracking-[0.18em] font-mono font-medium transition-colors"
              style={{ boxShadow: "0 0 16px rgba(245,180,0,0.3)" }}>
              <MessageSquare className="h-3.5 w-3.5" strokeWidth={2} />
              OPEN MESSENGER
              <ArrowRight className="h-3 w-3" />
            </button>
          </div>
        </motion.div>

        <div className="lg:col-span-1 min-h-[280px]">
          <LiveFeed />
        </div>
      </div>

      {/* MESH */}
      <SectionHeader kicker="TOPOLOGY" title="Agent Mesh" />
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-3 mb-16">
        <div className="lg:col-span-2">
          <Constellation agents={AGENTS} onSelect={onProfileAgent} />
        </div>
        <div className="rounded-2xl border border-white/[0.07] bg-white/[0.02] p-5 space-y-5">
          <div>
            <div className="flex items-center gap-2 mb-4">
              <Cpu className="h-3.5 w-3.5 text-amber-400" strokeWidth={1.5} />
              <span className="font-mono text-[10px] tracking-[0.28em] text-white/80">SYSTEM DIAGNOSTICS</span>
            </div>
            <div className="space-y-3.5">
              {[
                ["CONTEXT WINDOW",    64, "amber" as const],
                ["TOOL CALLS / MIN",  38, "cyan" as const],
                ["EVAL PASS RATE",    96, "emerald" as const],
                ["GUARDRAIL TENSION", 22, "rose" as const],
              ].map(([k, v, col]) => {
                const c = COLOR_MAP[col as keyof typeof COLOR_MAP];
                return (
                  <div key={k as string}>
                    <div className="flex items-center justify-between mb-1.5">
                      <span className="font-mono text-[10px] tracking-[0.2em] text-white/55">{k}</span>
                      <span className="font-mono text-[10px] text-white/80 tabular-nums">{v as number}%</span>
                    </div>
                    <div className="h-1 bg-white/[0.05] rounded-full overflow-hidden">
                      <motion.div className="h-full rounded-full" style={{ background: c.hex, boxShadow: `0 0 6px ${c.glow}` }}
                        initial={{ width: 0 }} whileInView={{ width: `${v}%` }} viewport={{ once: true }}
                        transition={{ duration: 1.2, ease: [0.22, 1, 0.36, 1] }} />
                    </div>
                  </div>
                );
              })}
            </div>
          </div>

          <div className="border-t border-white/[0.06] pt-4">
            <div className="flex items-center gap-2 mb-3">
              <Globe className="h-3.5 w-3.5 text-amber-400" strokeWidth={1.5} />
              <span className="font-mono text-[10px] tracking-[0.28em] text-white/80">UPLINKS</span>
            </div>
            <div className="space-y-2.5 font-mono">
              {[
                ["api.anthropic.com", "12ms", true],
                ["mcp/notion",        "84ms", true],
                ["mcp/gdrive",        "61ms", true],
                ["mcp/canva",         "—",    false],
              ].map(([host, lat, on]) => (
                <div key={host as string} className="flex items-center justify-between text-[11px]">
                  <div className="flex items-center gap-2 text-white/70">
                    <motion.span className={`h-1.5 w-1.5 rounded-full ${on ? "bg-emerald-400" : "bg-white/30"}`}
                      animate={on ? { opacity: [1, 0.4, 1] } : {}}
                      transition={{ duration: 1.8, repeat: Infinity }} />
                    {host}
                  </div>
                  <span className="text-white/40 tabular-nums">{lat}</span>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </>
  );
}
