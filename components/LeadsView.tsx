"use client";
import { useCallback, useEffect, useMemo, useState } from "react";
import { motion } from "framer-motion";
import { ContactRound, Mail, Phone, RefreshCw, AlertTriangle, ChevronDown } from "lucide-react";
import { Project } from "@/lib/projects";

interface Lead {
  id: string; projectId: string; name: string; email: string;
  phone?: string; message?: string; created: string; status: string;
  internalNotes?: string; extra: Record<string, string>;
}
interface SourceInfo { projectId: string; label: string; configured: boolean; statuses: string[]; keyEnv: string; }

const STATUS_COLOR: Record<string, string> = {
  new: "#F5B400", contacted: "#38BDF8", qualified: "#A78BFA",
  viewing: "#FB923C", won: "#34D399", lost: "#64748B",
};

function ago(iso: string): string {
  if (!iso) return "";
  const d = Date.now() - new Date(iso).getTime();
  const m = Math.floor(d / 60000);
  if (m < 60) return `${Math.max(m, 0)}m ago`;
  const h = Math.floor(m / 60);
  if (h < 24) return `${h}h ago`;
  const days = Math.floor(h / 24);
  if (days < 30) return `${days}d ago`;
  return `${Math.floor(days / 30)}mo ago`;
}

export default function LeadsView({ projects }: { projects: Project[] }) {
  const [leads, setLeads] = useState<Lead[]>([]);
  const [sources, setSources] = useState<SourceInfo[]>([]);
  const [errors, setErrors] = useState<string[]>([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState<string>("all");
  const [statusFilter, setStatusFilter] = useState<string>("all");
  const [expanded, setExpanded] = useState<string | null>(null);

  const load = useCallback(async () => {
    try {
      const res = await fetch("/api/crm", { cache: "no-store" });
      const j = await res.json();
      if (j.ok) { setLeads(j.leads || []); setSources(j.sources || []); setErrors(j.errors || []); }
      else setErrors([j.error || "CRM load failed"]);
    } catch (e: any) { setErrors([e?.message || "Network error"]); }
    finally { setLoading(false); }
  }, []);
  useEffect(() => { load(); const id = setInterval(load, 30000); return () => clearInterval(id); }, [load]);

  const colorOf = (projectId: string) =>
    projects.find(p => p.id === projectId)?.color || "#94A3B8";
  const nameOf = (projectId: string) =>
    projects.find(p => p.id === projectId)?.name || sources.find(s => s.projectId === projectId)?.label || projectId;

  const visible = useMemo(() => leads.filter(l =>
    (filter === "all" || l.projectId === filter) &&
    (statusFilter === "all" || l.status === statusFilter)
  ), [leads, filter, statusFilter]);

  const newCount = leads.filter(l => l.status === "new").length;
  const unconfigured = sources.filter(s => !s.configured);

  const setStatus = async (lead: Lead, status: string) => {
    setLeads(prev => prev.map(l => l.id === lead.id && l.projectId === lead.projectId ? { ...l, status } : l));
    try {
      const res = await fetch("/api/crm", {
        method: "PATCH", headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ projectId: lead.projectId, id: lead.id, status }),
      });
      const j = await res.json();
      if (!j.ok) throw new Error(j.error);
    } catch { load(); /* revert to server truth */ }
  };

  const chip = "px-3 py-1.5 rounded-full border font-mono text-[10px] tracking-[0.16em] transition-colors";

  return (
    <>
      <div className="mb-6">
        <div className="flex items-center gap-2 font-mono text-[10px] tracking-[0.3em] text-amber-300/80 mb-1.5">
          <span className="h-px w-5 bg-gradient-to-r from-amber-400 to-transparent" /> OPERATIONS / LEADS
        </div>
        <div className="flex items-end justify-between gap-3 flex-wrap">
          <h1 className="font-display text-[28px] md:text-[34px] text-white font-semibold">Leads</h1>
          <div className="font-mono text-[11px] text-white/45">
            {leads.length} TOTAL · <span className="text-amber-300">{newCount} NEW</span>
          </div>
        </div>
      </div>

      {unconfigured.length > 0 && (
        <div className="mb-4 rounded-xl border border-amber-400/20 bg-amber-400/[0.05] px-4 py-3 text-[12px] text-amber-200/90 flex items-start gap-2">
          <AlertTriangle className="h-3.5 w-3.5 mt-0.5 shrink-0" />
          <span>
            {unconfigured.map(s => s.label).join(" and ")} not connected — add{" "}
            {unconfigured.map(s => s.keyEnv).join(" and ")} (service role key) to .env.local and restart.
          </span>
        </div>
      )}
      {errors.map((e, i) => (
        <div key={i} className="mb-4 rounded-xl border border-rose-400/20 bg-rose-400/[0.05] px-4 py-3 text-[12px] text-rose-200/90">{e}</div>
      ))}

      <div className="flex items-center gap-2 flex-wrap mb-3">
        <button onClick={() => setFilter("all")}
          className={`${chip} ${filter === "all" ? "border-white/40 text-white bg-white/[0.06]" : "border-white/[0.08] text-white/50 hover:text-white"}`}>
          ALL CRMS
        </button>
        {sources.map(s => (
          <button key={s.projectId} onClick={() => setFilter(f => f === s.projectId ? "all" : s.projectId)}
            className={`${chip} flex items-center gap-1.5 ${filter === s.projectId ? "text-white bg-white/[0.06]" : "border-white/[0.08] text-white/50 hover:text-white"}`}
            style={filter === s.projectId ? { borderColor: colorOf(s.projectId) + "99" } : undefined}>
            <span className="h-1.5 w-1.5 rounded-full" style={{ background: colorOf(s.projectId) }} />
            {s.label.toUpperCase()}
            <span className="text-white/85 tabular-nums">{leads.filter(l => l.projectId === s.projectId).length}</span>
          </button>
        ))}
      </div>
      <div className="flex items-center gap-2 flex-wrap mb-6">
        {["all", ...Object.keys(STATUS_COLOR)].map(st => (
          <button key={st} onClick={() => setStatusFilter(f => f === st ? "all" : st)}
            className={`${chip} ${statusFilter === st ? "text-white bg-white/[0.06] border-white/30" : "border-white/[0.07] text-white/40 hover:text-white/80"}`}
            style={st !== "all" && statusFilter === st ? { borderColor: STATUS_COLOR[st] + "99" } : undefined}>
            {st === "all" ? "ANY STATUS" : st.toUpperCase()}
            {st !== "all" && <span className="ml-1.5 text-white/70 tabular-nums">{leads.filter(l => l.status === st).length}</span>}
          </button>
        ))}
        <button onClick={() => { setLoading(true); load(); }} title="Refresh"
          className="ml-auto h-8 w-8 grid place-items-center rounded-full border border-white/10 hover:bg-white/5 text-white/40 hover:text-white">
          <RefreshCw className={`h-3.5 w-3.5 ${loading ? "animate-spin" : ""}`} strokeWidth={1.5} />
        </button>
      </div>

      {visible.length === 0 && !loading && (
        <div className="rounded-2xl border border-white/[0.07] bg-white/[0.02] px-6 py-14 text-center">
          <ContactRound className="h-7 w-7 mx-auto mb-3 text-white/20" strokeWidth={1.2} />
          <div className="font-mono text-[11px] tracking-[0.25em] text-white/40">NO LEADS IN THIS VIEW</div>
          <div className="text-[12px] text-white/30 mt-1.5">New enquiries from your sites land here automatically.</div>
        </div>
      )}

      <div className="space-y-2.5">
        {visible.map(l => {
          const key = `${l.projectId}:${l.id}`;
          const open = expanded === key;
          const src = sources.find(s => s.projectId === l.projectId);
          return (
            <motion.div key={key} layout
              className="relative rounded-2xl border border-white/[0.07] bg-white/[0.02] overflow-hidden">
              <span className="absolute left-0 top-0 bottom-0 w-[3px]" style={{ background: colorOf(l.projectId) }} />
              <button onClick={() => setExpanded(open ? null : key)} className="w-full text-left px-5 py-4">
                <div className="flex items-center gap-3 flex-wrap">
                  <span className="text-[14px] text-white font-medium">{l.name}</span>
                  <span className="font-mono text-[9px] tracking-[0.18em] px-2 py-0.5 rounded-full border"
                    style={{ color: STATUS_COLOR[l.status] || "#94A3B8", borderColor: (STATUS_COLOR[l.status] || "#94A3B8") + "55" }}>
                    {l.status.toUpperCase()}
                  </span>
                  <span className="font-mono text-[10px]" style={{ color: colorOf(l.projectId) }}>{nameOf(l.projectId)}</span>
                  <span className="ml-auto flex items-center gap-2 font-mono text-[10px] text-white/35">
                    {ago(l.created)}
                    <ChevronDown className={`h-3.5 w-3.5 transition-transform ${open ? "rotate-180" : ""}`} strokeWidth={1.5} />
                  </span>
                </div>
                <div className="flex items-center gap-4 mt-1.5 text-[12px] text-white/50 flex-wrap">
                  <span className="flex items-center gap-1.5"><Mail className="h-3 w-3" />{l.email}</span>
                  {l.phone && <span className="flex items-center gap-1.5"><Phone className="h-3 w-3" />{l.phone}</span>}
                </div>
              </button>
              {open && (
                <div className="px-5 pb-4 border-t border-white/[0.05] pt-3.5">
                  {l.message && <p className="text-[13px] text-white/70 leading-relaxed mb-3 whitespace-pre-wrap">{l.message}</p>}
                  {Object.keys(l.extra).length > 0 && (
                    <div className="grid grid-cols-2 md:grid-cols-3 gap-x-6 gap-y-1.5 mb-3.5">
                      {Object.entries(l.extra).map(([k, v]) => (
                        <div key={k} className="text-[11px]">
                          <span className="font-mono text-[9px] tracking-[0.14em] text-white/35 block">{k.replace(/_/g, " ").toUpperCase()}</span>
                          <span className="text-white/75">{v}</span>
                        </div>
                      ))}
                    </div>
                  )}
                  <div className="flex items-center gap-1.5 flex-wrap">
                    {(src?.statuses || []).map(st => (
                      <button key={st} onClick={() => setStatus(l, st)}
                        className={`${chip} ${l.status === st ? "text-black font-medium" : "border-white/[0.08] text-white/45 hover:text-white"}`}
                        style={l.status === st ? { background: STATUS_COLOR[st], borderColor: STATUS_COLOR[st] } : undefined}>
                        {st.toUpperCase()}
                      </button>
                    ))}
                    <a href={`mailto:${l.email}`}
                      className={`${chip} ml-auto border-amber-400/30 bg-amber-400/[0.08] text-amber-300 hover:bg-amber-400/[0.15]`}>
                      REPLY →
                    </a>
                  </div>
                </div>
              )}
            </motion.div>
          );
        })}
      </div>
    </>
  );
}
