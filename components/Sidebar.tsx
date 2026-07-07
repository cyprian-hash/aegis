"use client";
import { motion } from "framer-motion";
import {
  Gauge, Bot, MessageSquare, Activity, Network, Database, Wallet,
  ScrollText, Compass, Plug, Briefcase,
} from "lucide-react";

export type ViewId =
  | "overview" | "agents" | "chat" | "projects" | "telemetry" | "network" | "memory"
  | "logs" | "missions" | "mcp" | "ledger";

export const NAV: { id: ViewId; label: string; icon: any; group?: string }[] = [
  { id: "overview",  label: "Overview",   icon: Gauge },
  { id: "agents",    label: "Agents",     icon: Bot },
  { id: "chat",      label: "Chat",       icon: MessageSquare },
  { id: "projects", label: "Projects",  icon: Briefcase, group: "WORKSPACE" },
  { id: "missions",  label: "Missions",   icon: Compass,   group: "OPERATIONS" },
  { id: "logs",      label: "Logs",       icon: ScrollText },
  { id: "mcp",       label: "MCP",        icon: Plug },
  { id: "telemetry", label: "Telemetry",  icon: Activity,  group: "SYSTEM" },
  { id: "network",   label: "Network",    icon: Network },
  { id: "memory",    label: "Memory",     icon: Database },
  { id: "ledger",    label: "Ledger",     icon: Wallet },
];

export default function Sidebar({ active, setActive }: { active: ViewId; setActive: (v: ViewId) => void }) {
  return (
    <aside className="hidden md:flex w-[220px] flex-col border-r border-white/[0.06] bg-black/40 backdrop-blur-xl shrink-0">
      <div className="px-5 pt-6 pb-5 border-b border-white/[0.06]">
        <button onClick={() => setActive("overview")} className="flex items-center gap-2.5 group">
          <div className="relative h-9 w-9">
            <motion.div
              className="absolute inset-0 rounded-lg border border-amber-400/50"
              animate={{ rotate: 360 }}
              transition={{ duration: 18, repeat: Infinity, ease: "linear" }}
            />
            <div className="absolute inset-[6px] rounded-md bg-gradient-to-br from-amber-300 to-amber-600 group-hover:from-amber-200 group-hover:to-amber-500 transition-colors" />
          </div>
          <div className="leading-tight text-left">
            <div className="font-display text-[16px] font-semibold tracking-[0.16em] text-white">AEGIS</div>
            <div className="font-mono text-[9px] tracking-[0.3em] text-white/40">CMD CENTER</div>
          </div>
        </button>
      </div>

      <nav className="flex-1 px-3 py-4 space-y-0.5 overflow-y-auto">
        {NAV.map((n) => {
          const Icon = n.icon;
          const isActive = active === n.id;
          return (
            <div key={n.id}>
              {n.group && (
                <div className="mt-5 mb-1.5 px-3 font-mono text-[8px] tracking-[0.3em] text-white/25">
                  {n.group}
                </div>
              )}
              <button onClick={() => setActive(n.id)} className="group relative w-full text-left">
                <div className={`flex items-center gap-3 px-3 py-2.5 rounded-xl transition-all ${
                  isActive ? "bg-white/[0.06] text-white" : "text-white/55 hover:text-white hover:bg-white/[0.03]"
                }`}>
                  <Icon className="h-4 w-4 shrink-0" strokeWidth={1.5} />
                  <span className="text-[13px] font-medium">{n.label}</span>
                  {isActive && (
                    <motion.span layoutId="nav-dot"
                      className="ml-auto h-1.5 w-1.5 rounded-full bg-amber-400"
                      style={{ boxShadow: "0 0 8px #f5b400" }} />
                  )}
                </div>
              </button>
            </div>
          );
        })}
      </nav>

      <div className="border-t border-white/[0.06] p-4">
        <div className="font-mono text-[9px] tracking-[0.3em] text-white/30 mb-2.5">OPERATOR</div>
        <div className="flex items-center gap-2.5">
          <div className="h-9 w-9 rounded-full bg-gradient-to-br from-amber-300 to-amber-600 grid place-items-center text-black text-[12px] font-bold">
            C
          </div>
          <div className="leading-tight">
            <div className="text-[13px] text-white">Commander</div>
            <div className="font-mono text-[9px] tracking-[0.2em] text-emerald-400">● AUTHED</div>
          </div>
        </div>
      </div>
    </aside>
  );
}
