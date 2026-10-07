"use client";
import { useEffect, useState } from "react";
import { AnimatePresence, motion } from "framer-motion";
import { MoreHorizontal, X } from "lucide-react";
import { NAV, ViewId } from "./Sidebar";

const PRIMARY: ViewId[] = ["overview", "agents", "chat", "decisions", "memory"];

export default function MobileNav({ active, setActive }: { active: ViewId; setActive: (v: ViewId) => void }) {
  const [open, setOpen] = useState(false);
  const [openDecisions, setOpenDecisions] = useState(0);
  useEffect(() => {
    const load = () => fetch("/api/decisions").then(r => r.json()).then(j => setOpenDecisions(j.openCount || 0)).catch(() => {});
    load();
    const id = setInterval(load, 45000);
    return () => clearInterval(id);
  }, []);

  const primary = PRIMARY.map(id => NAV.find(n => n.id === id)!).filter(Boolean);
  const rest = NAV.filter(n => !PRIMARY.includes(n.id));
  const moreActive = rest.some(n => n.id === active);
  const go = (v: ViewId) => { setActive(v); setOpen(false); };

  return (
    <>
      <AnimatePresence>
        {open && (
          <>
            <motion.div key="scrim" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
              className="fixed inset-0 z-40 bg-black/60 md:hidden" onClick={() => setOpen(false)} />
            <motion.div key="sheet" initial={{ y: "100%" }} animate={{ y: 0 }} exit={{ y: "100%" }}
              transition={{ type: "tween", duration: 0.22, ease: [0.22, 1, 0.36, 1] }}
              className="fixed bottom-0 left-0 right-0 z-50 md:hidden rounded-t-2xl border-t border-white/10 bg-[#0b0b0b]/95 backdrop-blur-xl px-4 pt-4"
              style={{ paddingBottom: "calc(env(safe-area-inset-bottom) + 88px)" }}>
              <div className="flex items-center justify-between mb-3 px-1">
                <span className="font-mono text-[10px] tracking-[0.3em] text-white/40">ALL SYSTEMS</span>
                <button onClick={() => setOpen(false)} className="h-7 w-7 grid place-items-center rounded-full hover:bg-white/10 text-white/50">
                  <X className="h-3.5 w-3.5" strokeWidth={1.5} />
                </button>
              </div>
              <div className="grid grid-cols-4 gap-2">
                {rest.map(({ id, label, icon: Icon }) => (
                  <button key={id} onClick={() => go(id)}
                    className={`flex flex-col items-center gap-1.5 rounded-xl border py-3 ${active === id ? "border-amber-400/40 bg-amber-400/10 text-amber-300" : "border-white/[0.07] bg-white/[0.03] text-white/60"}`}>
                    <Icon className="h-4 w-4" strokeWidth={1.5} />
                    <span className="text-[10px] font-mono tracking-wide">{label}</span>
                  </button>
                ))}
              </div>
            </motion.div>
          </>
        )}
      </AnimatePresence>

      <nav className="fixed bottom-0 left-0 right-0 z-50 md:hidden border-t border-white/[0.08] bg-black/85 backdrop-blur-xl"
        style={{ paddingBottom: "env(safe-area-inset-bottom)" }}>
        <div className="grid grid-cols-6">
          {primary.map(({ id, label, icon: Icon }) => (
            <button key={id} onClick={() => go(id)}
              className={`relative flex flex-col items-center gap-1 py-2.5 ${active === id && !open ? "text-amber-300" : "text-white/45"}`}>
              {active === id && !open && <span className="absolute top-0 h-0.5 w-8 rounded-full bg-amber-400" style={{ boxShadow: "0 0 8px #f5b400" }} />}
              <Icon className="h-[18px] w-[18px]" strokeWidth={1.5} />
              <span className="text-[9px] font-mono tracking-wide">{label}</span>
              {id === "decisions" && openDecisions > 0 && (
                <span className="absolute top-1 right-1/2 translate-x-4 min-w-[15px] h-[15px] px-1 grid place-items-center rounded-full bg-amber-400 text-black text-[8px] font-bold tabular-nums">{openDecisions}</span>
              )}
            </button>
          ))}
          <button onClick={() => setOpen(o => !o)}
            className={`flex flex-col items-center gap-1 py-2.5 ${open || moreActive ? "text-amber-300" : "text-white/45"}`}>
            <MoreHorizontal className="h-[18px] w-[18px]" strokeWidth={1.5} />
            <span className="text-[9px] font-mono tracking-wide">More</span>
          </button>
        </div>
      </nav>
    </>
  );
}
