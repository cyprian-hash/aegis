"use client";
import { motion } from "framer-motion";
import { Users } from "lucide-react";
import { AGENTS, Agent } from "@/lib/agents";
import AgentCard from "./AgentCard";
import SectionHeader from "./SectionHeader";

export default function AgentsView({
  onSelectProfile, onSelectChat,
}: {
  onSelectProfile: (a: Agent) => void;
  onSelectChat: (a: Agent) => void;
}) {
  return (
    <div>
      <SectionHeader
        kicker="FLEET / FULL ROSTER"
        title="Your Agents"
        right={
          <div className="flex items-center gap-2 font-mono text-[10px] tracking-[0.25em] text-white/50">
            <Users className="h-3 w-3" />
            {AGENTS.length} AGENTS
            <span className="text-white/20">·</span>
            <span className="text-emerald-400">{AGENTS.filter(a => a.status === "online").length} ONLINE</span>
          </div>
        }
      />

      <motion.p
        initial={{ opacity: 0 }} animate={{ opacity: 1 }}
        className="text-[14px] text-white/60 max-w-2xl mb-7 leading-relaxed"
      >
        Each agent has a specialty, a personality, and its own system prompt. Click any card to read its profile, or jump straight into a chat.
      </motion.p>

      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-3">
        {AGENTS.map((a, i) => (
          <AgentCard
            key={a.id}
            agent={a}
            index={i}
            onClick={onSelectProfile}
            onChat={onSelectChat}
          />
        ))}
      </div>
    </div>
  );
}
