"use client";
import { useState, useRef, useEffect } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { ChevronDown, Layers, Check } from "lucide-react";
import { Project, colorTokens, STATUS_COLOR } from "@/lib/projects";

interface Props {
  projects: Project[];
  activeId: string | null;
  onChange: (id: string | null) => void;
  onOpenProjects: () => void;
}

export default function ProjectSwitcher({ projects, activeId, onChange, onOpenProjects }: Props) {
  const [open, setOpen] = useState(false);
  const wrapRef = useRef<HTMLDivElement>(null);
  const active = activeId ? projects.find(p => p.id === activeId) : null;

  useEffect(() => {
    const onClickAway = (e: MouseEvent) => {
      if (!wrapRef.current?.contains(e.target as Node)) setOpen(false);
    };
    if (open) document.addEventListener("mousedown", onClickAway);
    return () => document.removeEventListener("mousedown", onClickAway);
  }, [open]);

  const activeTokens = active ? colorTokens(active.color) : null;

  return (
    <div ref={wrapRef} className="relative">
      <button
        onClick={() => setOpen(v => !v)}
        className="flex items-center gap-2 px-3 py-1.5 rounded-full border border-white/[0.08] hover:border-white/20 bg-white/[0.02] hover:bg-white/[0.04] transition-colors"
        title="Switch project workspace"
      >
        {active ? (
          <>
            <span className="h-2 w-2 rounded-full shrink-0" style={{
              background: activeTokens!.hex,
              boxShadow: `0 0 8px ${activeTokens!.glow}`,
            }} />
            <span className="text-[11px] font-mono tracking-[0.15em] text-white/85">{active.name.toUpperCase()}</span>
          </>
        ) : (
          <>
            <Layers className="h-3 w-3 text-white/55" strokeWidth={1.5} />
            <span className="text-[11px] font-mono tracking-[0.18em] text-white/55">ALL PROJECTS</span>
          </>
        )}
        <ChevronDown className={`h-3 w-3 text-white/40 transition-transform ${open ? "rotate-180" : ""}`} strokeWidth={2} />
      </button>

      <AnimatePresence>
        {open && (
          <motion.div
            initial={{ opacity: 0, y: -6 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -6 }}
            transition={{ duration: 0.15 }}
            className="absolute right-0 top-full mt-2 w-[280px] rounded-xl border border-white/[0.08] bg-black/95 backdrop-blur-xl shadow-2xl z-50 overflow-hidden"
          >
            <button
              onClick={() => { onChange(null); setOpen(false); }}
              className={`w-full flex items-center gap-2 px-3.5 py-2.5 hover:bg-white/[0.04] transition-colors ${!activeId ? "bg-white/[0.03]" : ""}`}
            >
              <Layers className="h-3.5 w-3.5 text-white/50" strokeWidth={1.5} />
              <span className="flex-1 text-left text-[12px] text-white/85 font-medium">All projects</span>
              {!activeId && <Check className="h-3 w-3 text-amber-400" strokeWidth={2.5} />}
            </button>

            <div className="border-t border-white/[0.04] max-h-[320px] overflow-y-auto">
              {projects.length === 0 && (
                <div className="px-3.5 py-4 text-[11px] text-white/40 text-center">
                  No projects yet
                </div>
              )}
              {projects.map(p => {
                const c = colorTokens(p.color);
                const isActive = p.id === activeId;
                return (
                  <button
                    key={p.id}
                    onClick={() => { onChange(p.id); setOpen(false); }}
                    className={`w-full flex items-center gap-2.5 px-3.5 py-2 hover:bg-white/[0.04] transition-colors ${isActive ? "bg-white/[0.03]" : ""}`}
                  >
                    <span className="h-1.5 w-1.5 rounded-full shrink-0" style={{
                      background: c.hex, boxShadow: `0 0 6px ${c.glow}`,
                    }} />
                    <span className="flex-1 text-left text-[12px] text-white/85 truncate">{p.name}</span>
                    <span className="text-[9px] font-mono tracking-[0.15em] shrink-0" style={{
                      color: STATUS_COLOR[p.status],
                    }}>
                      {p.status.toUpperCase()}
                    </span>
                    {isActive && <Check className="h-3 w-3 text-amber-400 ml-1" strokeWidth={2.5} />}
                  </button>
                );
              })}
            </div>

            <button
              onClick={() => { onOpenProjects(); setOpen(false); }}
              className="w-full px-3.5 py-2.5 border-t border-white/[0.04] hover:bg-white/[0.04] text-left text-[11px] font-mono tracking-[0.15em] text-amber-300/80 hover:text-amber-300"
            >
              MANAGE PROJECTS →
            </button>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
