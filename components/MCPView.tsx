"use client";
import { useState, useMemo } from "react";
import { motion, AnimatePresence } from "framer-motion";
import {
  Plug, Plus, X, Search, CheckCircle2, AlertCircle, PowerOff, Settings2,
  FileText, Cloud, Mail, Calendar, Image, Database, Triangle, CreditCard, Sparkles,
} from "lucide-react";
import { COLOR_MAP, pad } from "@/lib/theme";
import SectionHeader from "./SectionHeader";

type Status = "connected" | "available" | "error" | "disabled";

interface Server {
  id: string;
  name: string;
  category: string;
  icon: any;
  color: keyof typeof COLOR_MAP;
  status: Status;
  url: string;
  tools: string[];
  description: string;
}

const SEED: Server[] = [
  { id: "notion", name: "Notion", category: "DOCS", icon: FileText, color: "violet", status: "connected", url: "https://mcp.notion.com/mcp",
    tools: ["notion-search", "notion-create-pages", "notion-update-page", "notion-fetch", "notion-query-database-view"],
    description: "Pages, databases, search, comments. Used by ARCHIVE-03 for knowledge persistence." },
  { id: "gdrive", name: "Google Drive", category: "DOCS", icon: Cloud, color: "amber", status: "connected", url: "https://drivemcp.googleapis.com/mcp/v1",
    tools: ["search_files", "read_file_content", "create_file", "copy_file", "get_file_metadata"],
    description: "Drive files, folders, metadata. PRIME pulls briefings from here." },
  { id: "gmail", name: "Gmail", category: "COMMS", icon: Mail, color: "rose", status: "connected", url: "https://gmailmcp.googleapis.com/mcp/v1",
    tools: ["search_messages", "send_message", "create_draft", "get_thread"],
    description: "Read and compose mail. WEAVER-04 routes outbound messages through this." },
  { id: "gcal", name: "Google Calendar", category: "COMMS", icon: Calendar, color: "cyan", status: "connected", url: "https://calendarmcp.googleapis.com/mcp/v1",
    tools: ["list_events", "create_event", "update_event", "delete_event", "search_calendars"],
    description: "Calendar events and scheduling. PRIME uses this for time-aware planning." },
  { id: "canva", name: "Canva", category: "CREATIVE", icon: Image, color: "rose", status: "available", url: "https://mcp.canva.com/mcp",
    tools: ["generate-design", "search-designs", "export-design", "import-design-from-url"],
    description: "Generate and edit designs. Not yet enabled in the fleet." },
  { id: "supabase", name: "Supabase", category: "DATA", icon: Database, color: "emerald", status: "connected", url: "https://mcp.supabase.com/mcp",
    tools: ["execute_sql", "list_tables", "apply_migration", "create_branch", "deploy_edge_function"],
    description: "Postgres + edge functions. Backs the mission log persistence layer." },
  { id: "vercel", name: "Vercel", category: "DATA", icon: Triangle, color: "sky", status: "connected", url: "https://mcp.vercel.com",
    tools: ["deploy_to_vercel", "list_deployments", "get_deployment_build_logs", "get_runtime_logs"],
    description: "Deployments and runtime logs. FORGE-02 ships through this." },
  { id: "stripe", name: "Stripe", category: "OPS", icon: CreditCard, color: "violet", status: "disabled", url: "https://mcp.stripe.com",
    tools: ["create_customer", "create_charge", "list_subscriptions", "create_invoice"],
    description: "Payments and billing. Disabled — not in scope for current operator." },
  { id: "gamma", name: "Gamma", category: "CREATIVE", icon: Sparkles, color: "amber", status: "error", url: "https://mcp.gamma.app/mcp",
    tools: ["generate", "get_gammas", "read_gamma", "get_themes"],
    description: "Generate decks and docs. Currently returning 502 — retrying every 5min." },
];

const CATEGORIES = ["ALL", "DOCS", "COMMS", "CREATIVE", "DATA", "OPS"];

export default function MCPView() {
  const [servers, setServers] = useState<Server[]>(SEED);
  const [query, setQuery] = useState("");
  const [activeCat, setActiveCat] = useState("ALL");
  const [selected, setSelected] = useState<Server | null>(null);
  const [showAdd, setShowAdd] = useState(false);

  const filtered = useMemo(() => {
    return servers.filter(s =>
      (activeCat === "ALL" || s.category === activeCat) &&
      (query === "" || s.name.toLowerCase().includes(query.toLowerCase()) || s.tools.some(t => t.toLowerCase().includes(query.toLowerCase())))
    );
  }, [servers, activeCat, query]);

  const summary = useMemo(() => ({
    connected: servers.filter(s => s.status === "connected").length,
    available: servers.filter(s => s.status === "available").length,
    error:     servers.filter(s => s.status === "error").length,
    tools:     servers.reduce((a, b) => a + b.tools.length, 0),
  }), [servers]);

  const toggleStatus = (id: string) => {
    setServers(prev => prev.map(s =>
      s.id === id
        ? { ...s, status: s.status === "connected" ? "disabled" : "connected" }
        : s
    ));
  };

  return (
    <div>
      <SectionHeader
        kicker="OPERATIONS / INTEGRATIONS"
        title="MCP Server Manager"
        right={
          <motion.button
            whileHover={{ y: -1 }} whileTap={{ scale: 0.97 }}
            onClick={() => setShowAdd(true)}
            className="flex items-center gap-2 px-4 py-2.5 rounded-full bg-amber-400 text-black text-[11px] tracking-[0.18em] font-mono font-medium"
            style={{ boxShadow: "0 0 14px rgba(245,180,0,0.3)" }}
          >
            <Plus className="h-3.5 w-3.5" strokeWidth={2.5} /> ADD SERVER
          </motion.button>
        }
      />

      <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mb-6">
        {[
          ["CONNECTED", summary.connected, "emerald"],
          ["AVAILABLE", summary.available, "cyan"],
          ["ERRORS",    summary.error,     "rose"],
          ["TOOLS EXPOSED", summary.tools, "amber"],
        ].map(([k, v, col]) => {
          const c = COLOR_MAP[col as keyof typeof COLOR_MAP];
          return (
            <div key={k as string} className="rounded-2xl border border-white/[0.07] bg-white/[0.02] p-4">
              <div className="flex items-center justify-between mb-1.5">
                <span className="font-mono text-[9px] tracking-[0.25em] text-white/40">{k}</span>
                <span className="h-1.5 w-1.5 rounded-full" style={{ background: c.hex, boxShadow: `0 0 6px ${c.glow}` }} />
              </div>
              <div className="font-display text-2xl text-white tabular-nums">{pad(v as number)}</div>
            </div>
          );
        })}
      </div>

      <div className="flex items-center gap-3 mb-4 flex-wrap">
        <div className="flex items-center gap-2 rounded-full border border-white/10 bg-black/40 px-4 flex-1 min-w-[280px]">
          <Search className="h-3.5 w-3.5 text-white/40" strokeWidth={1.5} />
          <input
            value={query} onChange={e => setQuery(e.target.value)}
            placeholder="Search servers or tools…"
            className="flex-1 bg-transparent py-2.5 text-[12px] text-white placeholder-white/30 outline-none"
          />
        </div>
        <div className="flex items-center gap-1.5">
          {CATEGORIES.map(c => (
            <button key={c} onClick={() => setActiveCat(c)}
              className={`px-3 py-2 rounded-full font-mono text-[10px] tracking-[0.2em] transition-colors ${
                activeCat === c
                  ? "bg-amber-400/15 text-amber-300 border border-amber-400/40"
                  : "border border-white/10 text-white/50 hover:text-white hover:border-white/30"
              }`}>
              {c}
            </button>
          ))}
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-3">
        {filtered.map((s, i) => (
          <ServerCard key={s.id} s={s} index={i} onClick={() => setSelected(s)} onToggle={() => toggleStatus(s.id)} />
        ))}
        {filtered.length === 0 && (
          <div className="col-span-full p-12 text-center font-mono text-[11px] tracking-[0.18em] text-white/30 rounded-2xl border border-white/[0.07] bg-white/[0.02]">
            NO SERVERS MATCH FILTERS
          </div>
        )}
      </div>

      <AnimatePresence>
        {selected && <ServerDetail s={selected} onClose={() => setSelected(null)} onToggle={() => toggleStatus(selected.id)} />}
      </AnimatePresence>
      <AnimatePresence>
        {showAdd && <AddServerModal onClose={() => setShowAdd(false)} onAdd={(s) => { setServers(prev => [...prev, s]); setShowAdd(false); }} />}
      </AnimatePresence>
    </div>
  );
}

function ServerCard({ s, index, onClick, onToggle }: { s: Server; index: number; onClick: () => void; onToggle: () => void }) {
  const c = COLOR_MAP[s.color];
  const Icon = s.icon;
  const StatusIcon =
    s.status === "connected" ? CheckCircle2 :
    s.status === "error"     ? AlertCircle :
    s.status === "disabled"  ? PowerOff : Plug;
  const statusColor =
    s.status === "connected" ? "text-emerald-400" :
    s.status === "error"     ? "text-rose-400" :
    s.status === "disabled"  ? "text-white/40" : "text-cyan-300";

  return (
    <motion.div
      initial={{ opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }}
      transition={{ delay: index * 0.04, duration: 0.4 }}
      whileHover={{ y: -2 }}
      className="group relative rounded-2xl border border-white/[0.07] bg-white/[0.02] hover:border-white/20 transition-colors overflow-hidden cursor-pointer"
      onClick={onClick}
    >
      <div className="absolute inset-0 opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none"
        style={{ background: `radial-gradient(60% 60% at 50% 0%, ${c.soft}, transparent)` }} />
      <div className="relative p-5">
        <div className="flex items-start justify-between mb-3">
          <div className="flex items-center gap-3">
            <div className="h-11 w-11 rounded-xl grid place-items-center"
              style={{ background: c.soft, border: `1px solid ${c.hex}33` }}>
              <Icon className="h-5 w-5" style={{ color: c.hex }} strokeWidth={1.5} />
            </div>
            <div>
              <div className="font-display text-[14px] text-white font-medium">{s.name}</div>
              <div className="font-mono text-[9px] tracking-[0.2em] text-white/40">{s.category}</div>
            </div>
          </div>
          <StatusIcon className={`h-4 w-4 ${statusColor}`} strokeWidth={1.5} />
        </div>
        <div className="text-[11px] text-white/60 leading-relaxed mb-3 line-clamp-2 min-h-[32px]">{s.description}</div>
        <div className="flex items-center justify-between gap-2 mb-3 pt-3 border-t border-white/[0.05]">
          <span className="font-mono text-[10px] tracking-[0.2em] text-white/50">{pad(s.tools.length)} TOOLS</span>
          <button
            onClick={(e) => { e.stopPropagation(); onToggle(); }}
            className="font-mono text-[10px] tracking-[0.18em] px-3 py-1 rounded-full transition-colors"
            style={s.status === "connected"
              ? { background: "rgba(52,211,153,0.1)", color: "#34d399" }
              : { background: "rgba(255,255,255,0.05)", color: "rgba(255,255,255,0.6)" }}
          >
            {s.status === "connected" ? "● ENABLED" : "○ DISABLED"}
          </button>
        </div>
      </div>
    </motion.div>
  );
}

function ServerDetail({ s, onClose, onToggle }: { s: Server; onClose: () => void; onToggle: () => void }) {
  const c = COLOR_MAP[s.color];
  const Icon = s.icon;
  return (
    <>
      <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
        onClick={onClose} className="fixed inset-0 bg-black/70 backdrop-blur-sm z-40" />
      <motion.div
        initial={{ opacity: 0, x: 40 }} animate={{ opacity: 1, x: 0 }} exit={{ opacity: 0, x: 40 }}
        transition={{ duration: 0.3, ease: [0.22, 1, 0.36, 1] }}
        className="fixed right-0 top-0 bottom-0 w-full md:w-[480px] bg-[#0c0c0c] border-l border-white/10 z-50 overflow-y-auto"
      >
        <div className="sticky top-0 bg-[#0c0c0c]/95 backdrop-blur-xl border-b border-white/[0.06] px-6 py-4 flex items-center justify-between z-10">
          <div className="flex items-center gap-3">
            <div className="h-10 w-10 rounded-xl grid place-items-center"
              style={{ background: c.soft, border: `1px solid ${c.hex}33` }}>
              <Icon className="h-5 w-5" style={{ color: c.hex }} strokeWidth={1.5} />
            </div>
            <div>
              <div className="font-display text-[16px] text-white">{s.name}</div>
              <div className="font-mono text-[9px] tracking-[0.2em] text-white/40">{s.category}</div>
            </div>
          </div>
          <button onClick={onClose} className="h-8 w-8 grid place-items-center rounded-full hover:bg-white/5 text-white/50 hover:text-white">
            <X className="h-4 w-4" />
          </button>
        </div>

        <div className="p-6 space-y-5">
          <div>
            <div className="font-mono text-[9px] tracking-[0.25em] text-white/40 mb-2">DESCRIPTION</div>
            <div className="text-[13px] text-white/80 leading-relaxed">{s.description}</div>
          </div>
          <div>
            <div className="font-mono text-[9px] tracking-[0.25em] text-white/40 mb-2">ENDPOINT</div>
            <div className="font-mono text-[11px] text-white/85 bg-black/40 border border-white/[0.06] rounded-lg p-3 break-all">{s.url}</div>
          </div>
          <div>
            <div className="font-mono text-[9px] tracking-[0.25em] text-white/40 mb-2">
              EXPOSED TOOLS · {s.tools.length}
            </div>
            <div className="space-y-1">
              {s.tools.map(t => (
                <div key={t} className="flex items-center gap-2 px-3 py-2 rounded-lg bg-white/[0.02] border border-white/[0.04]">
                  <span className="h-1.5 w-1.5 rounded-full" style={{ background: c.hex }} />
                  <span className="font-mono text-[11px] text-white/80">{t}</span>
                </div>
              ))}
            </div>
          </div>
          <div className="pt-3 border-t border-white/[0.06] flex gap-2">
            <button
              onClick={onToggle}
              className="flex-1 flex items-center justify-center gap-2 py-2.5 rounded-full font-mono text-[11px] tracking-[0.18em] font-medium transition-colors"
              style={s.status === "connected"
                ? { background: "rgba(244,63,94,0.15)", color: "#fb7185", border: "1px solid rgba(244,63,94,0.3)" }
                : { background: "#f5b400", color: "#000", boxShadow: "0 0 12px rgba(245,180,0,0.3)" }}
            >
              {s.status === "connected"
                ? <><PowerOff className="h-3.5 w-3.5" strokeWidth={2} /> DISABLE</>
                : <><Plug className="h-3.5 w-3.5" strokeWidth={2} /> ENABLE</>}
            </button>
            <button className="px-4 py-2.5 rounded-full border border-white/10 hover:border-white/30 hover:bg-white/5 font-mono text-[11px] tracking-[0.18em] text-white/70">
              <Settings2 className="h-3.5 w-3.5 inline mr-1" strokeWidth={2} /> CONFIG
            </button>
          </div>
        </div>
      </motion.div>
    </>
  );
}

function AddServerModal({ onClose, onAdd }: { onClose: () => void; onAdd: (s: Server) => void }) {
  const [name, setName] = useState("");
  const [url, setUrl] = useState("");
  const [category, setCategory] = useState("DOCS");

  const submit = () => {
    if (!name.trim() || !url.trim()) return;
    onAdd({
      id: name.toLowerCase().replace(/\s+/g, "-"),
      name: name.trim(), url: url.trim(), category,
      icon: Plug, color: "cyan", status: "available",
      tools: [],
      description: "Custom MCP server. Tools will be discovered on connection.",
    });
  };

  return (
    <>
      <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
        onClick={onClose} className="fixed inset-0 bg-black/70 backdrop-blur-sm z-40" />
      <motion.div
        initial={{ opacity: 0, scale: 0.96, y: 20 }} animate={{ opacity: 1, scale: 1, y: 0 }} exit={{ opacity: 0, scale: 0.96, y: 20 }}
        transition={{ duration: 0.3, ease: [0.22, 1, 0.36, 1] }}
        className="fixed inset-x-4 top-1/2 -translate-y-1/2 md:inset-x-auto md:left-1/2 md:-translate-x-1/2 md:w-[460px] rounded-2xl border border-white/10 bg-[#0c0c0c] z-50"
      >
        <div className="border-b border-white/[0.06] px-6 py-4 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Plug className="h-3.5 w-3.5 text-amber-400" strokeWidth={1.5} />
            <span className="font-mono text-[10px] tracking-[0.28em] text-white/80">ADD MCP SERVER</span>
          </div>
          <button onClick={onClose} className="h-8 w-8 grid place-items-center rounded-full hover:bg-white/5 text-white/50 hover:text-white">
            <X className="h-4 w-4" />
          </button>
        </div>
        <div className="p-6 space-y-4">
          <div>
            <div className="font-mono text-[9px] tracking-[0.25em] text-white/40 mb-2">NAME</div>
            <input value={name} onChange={e => setName(e.target.value)} autoFocus
              placeholder="My MCP Server"
              className="w-full bg-black/40 border border-white/10 focus:border-white/30 rounded-xl px-4 py-2.5 text-[13px] text-white placeholder-white/30 outline-none" />
          </div>
          <div>
            <div className="font-mono text-[9px] tracking-[0.25em] text-white/40 mb-2">URL</div>
            <input value={url} onChange={e => setUrl(e.target.value)}
              placeholder="https://example.com/mcp"
              className="w-full bg-black/40 border border-white/10 focus:border-white/30 rounded-xl px-4 py-2.5 text-[13px] text-white placeholder-white/30 outline-none font-mono" />
          </div>
          <div>
            <div className="font-mono text-[9px] tracking-[0.25em] text-white/40 mb-2">CATEGORY</div>
            <div className="flex flex-wrap gap-1.5">
              {CATEGORIES.filter(c => c !== "ALL").map(c => (
                <button key={c} onClick={() => setCategory(c)}
                  className={`px-3 py-1.5 rounded-full font-mono text-[10px] tracking-[0.18em] transition-colors ${
                    category === c
                      ? "bg-amber-400/15 text-amber-300 border border-amber-400/40"
                      : "border border-white/10 text-white/50 hover:text-white hover:border-white/30"
                  }`}>
                  {c}
                </button>
              ))}
            </div>
          </div>
          <div className="pt-3 border-t border-white/[0.06] flex gap-2">
            <button onClick={onClose}
              className="px-5 py-2.5 rounded-full border border-white/10 hover:border-white/30 font-mono text-[11px] tracking-[0.18em] text-white/70">
              CANCEL
            </button>
            <button onClick={submit}
              disabled={!name.trim() || !url.trim()}
              className="flex-1 py-2.5 rounded-full bg-amber-400 text-black hover:bg-amber-300 disabled:opacity-30 font-mono text-[11px] tracking-[0.18em] font-medium"
              style={{ boxShadow: name.trim() && url.trim() ? "0 0 14px rgba(245,180,0,0.3)" : "none" }}>
              ADD SERVER
            </button>
          </div>
        </div>
      </motion.div>
    </>
  );
}
