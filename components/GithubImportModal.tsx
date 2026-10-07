"use client";
import { useEffect, useMemo, useState } from "react";
import { motion } from "framer-motion";
import { X, Github, Lock, Check, Loader2, AlertTriangle, Search } from "lucide-react";
import { Project, slugify } from "@/lib/projects";

interface GhRepo {
  fullName: string; name: string; description: string;
  private: boolean; language: string; pushedAt: string; homepage: string;
}
type RowState = "idle" | "cloning" | "done" | "error";

const IMPORT_COLORS = ["#F5B400", "#3B82F6", "#10B981", "#A855F7", "#E11D48", "#00E888", "#F59E0B", "#14B8A6", "#285ED2", "#94A3B8"];

function ago(iso: string): string {
  if (!iso) return "";
  const d = Date.now() - new Date(iso).getTime();
  const days = Math.floor(d / 86400000);
  if (days < 1) return "today";
  if (days < 30) return `${days}d ago`;
  if (days < 365) return `${Math.floor(days / 30)}mo ago`;
  return `${Math.floor(days / 365)}y ago`;
}

export default function GithubImportModal({ projects, onClose, onImported }: {
  projects: Project[]; onClose: () => void; onImported: () => void;
}) {
  const [repos, setRepos] = useState<GhRepo[] | null>(null);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [note, setNote] = useState<string | null>(null);
  const [query, setQuery] = useState("");
  const [sel, setSel] = useState<Set<string>>(new Set());
  const [rows, setRows] = useState<Record<string, { state: RowState; msg?: string }>>({});
  const [running, setRunning] = useState(false);
  const [finished, setFinished] = useState(false);

  useEffect(() => {
    fetch("/api/github/repos").then(r => r.json()).then(j => {
      if (j.ok) { setRepos(j.repos); if (j.note) setNote(j.note); }
      else setLoadError(j.error || "Could not list repos");
    }).catch(e => setLoadError(e?.message || "Network error"));
  }, []);

  const linked = useMemo(() => {
    const s = new Set<string>();
    for (const p of projects) for (const r of p.repos || []) s.add(r.toLowerCase());
    return s;
  }, [projects]);
  const existingIds = useMemo(() => new Set(projects.map(p => p.id)), [projects]);

  const visible = useMemo(() => {
    if (!repos) return [];
    const q = query.trim().toLowerCase();
    return repos.filter(r => !q || r.fullName.toLowerCase().includes(q) || (r.description || "").toLowerCase().includes(q));
  }, [repos, query]);

  const toggle = (fullName: string) => {
    if (running || finished) return;
    setSel(prev => {
      const n = new Set(prev);
      if (n.has(fullName)) n.delete(fullName); else n.add(fullName);
      return n;
    });
  };

  const runImport = async () => {
    if (!repos || sel.size === 0 || running) return;
    setRunning(true);
    let colorIdx = 0;
    for (const fullName of Array.from(sel)) {
      const repo = repos.find(r => r.fullName === fullName);
      if (!repo) continue;
      setRows(p => ({ ...p, [fullName]: { state: "cloning" } }));
      try {
        const cloneRes = await fetch("/api/github/clone", {
          method: "POST", headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ repo: fullName }),
        });
        const clone = await cloneRes.json();
        if (!clone.ok) throw new Error(clone.error || "Clone failed");

        const id = slugify(repo.name);
        if (!existingIds.has(id)) {
          const prettyName = repo.name.replace(/[-_]+/g, " ").replace(/\b\w/g, c => c.toUpperCase());
          const projRes = await fetch("/api/projects", {
            method: "POST", headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
              id, name: prettyName,
              description: repo.description || `Imported from ${fullName}`,
              website: repo.homepage || undefined,
              repos: [fullName], hosting: [],
              status: "building",
              color: IMPORT_COLORS[colorIdx++ % IMPORT_COLORS.length],
              localPath: clone.localPath,
              tags: repo.language ? [repo.language.toLowerCase()] : [],
            }),
          });
          const proj = await projRes.json();
          if (!proj.ok) throw new Error(proj.error || "Project create failed");
        }
        setRows(p => ({ ...p, [fullName]: { state: "done", msg: clone.existing ? "already cloned · project added" : "cloned" } }));
      } catch (e: any) {
        setRows(p => ({ ...p, [fullName]: { state: "error", msg: (e?.message || "failed").slice(0, 120) } }));
      }
    }
    setRunning(false);
    setFinished(true);
    onImported();
  };

  return (
    <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
      className="fixed inset-0 z-50 bg-black/70 backdrop-blur-sm flex items-center justify-center p-4" onClick={onClose}>
      <motion.div initial={{ opacity: 0, scale: 0.96, y: 10 }} animate={{ opacity: 1, scale: 1, y: 0 }} exit={{ opacity: 0, scale: 0.96, y: 10 }}
        className="w-full max-w-lg rounded-2xl border border-white/[0.09] bg-[#0b0b0b] p-6 max-h-[85vh] flex flex-col"
        onClick={e => e.stopPropagation()}>
        <div className="flex items-center justify-between mb-4 shrink-0">
          <div>
            <div className="font-mono text-[10px] tracking-[0.28em] text-amber-300/80 mb-1 flex items-center gap-1.5">
              <Github className="h-3 w-3" /> GITHUB
            </div>
            <div className="text-[18px] text-white font-medium">Import Repositories</div>
          </div>
          <button onClick={onClose} className="h-7 w-7 grid place-items-center rounded-full hover:bg-white/5 text-white/40 hover:text-white">
            <X className="h-4 w-4" strokeWidth={1.5} />
          </button>
        </div>

        {note && <div className="mb-3 shrink-0 text-[11px] text-amber-300/70 flex items-center gap-1.5"><AlertTriangle className="h-3 w-3 shrink-0" />{note}</div>}

        <div className="relative mb-3 shrink-0">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-3.5 w-3.5 text-white/30" />
          <input value={query} onChange={e => setQuery(e.target.value)} placeholder="Filter repos…"
            className="w-full rounded-xl border border-white/10 bg-black/40 pl-9 pr-3.5 py-2.5 text-[13px] text-white placeholder-white/25 outline-none focus:border-amber-400/50" />
        </div>

        <div className="flex-1 min-h-0 overflow-y-auto rounded-xl border border-white/[0.06] divide-y divide-white/[0.05]">
          {loadError && <div className="p-4 text-[12px] text-rose-300">{loadError}</div>}
          {!repos && !loadError && (
            <div className="p-6 flex items-center justify-center gap-2 text-white/40 text-[12px]">
              <Loader2 className="h-3.5 w-3.5 animate-spin" /> Loading repos…
            </div>
          )}
          {repos && visible.length === 0 && <div className="p-4 text-[12px] text-white/35">No matching repos.</div>}
          {visible.map(r => {
            const isLinked = linked.has(r.fullName.toLowerCase());
            const row = rows[r.fullName];
            const checked = sel.has(r.fullName);
            return (
              <button key={r.fullName} onClick={() => !isLinked && toggle(r.fullName)} disabled={isLinked || running || finished}
                className={`w-full flex items-start gap-3 px-3.5 py-3 text-left transition-colors ${isLinked ? "opacity-40" : checked ? "bg-amber-400/[0.07]" : "hover:bg-white/[0.03]"}`}>
                <span className={`mt-0.5 h-4 w-4 shrink-0 grid place-items-center rounded border ${checked ? "border-amber-400 bg-amber-400 text-black" : "border-white/20"}`}>
                  {checked && <Check className="h-3 w-3" strokeWidth={3} />}
                </span>
                <span className="min-w-0 flex-1">
                  <span className="flex items-center gap-1.5">
                    <span className="text-[13px] text-white/90 truncate">{r.name}</span>
                    {r.private && <Lock className="h-3 w-3 text-white/35 shrink-0" />}
                    {r.language && <span className="font-mono text-[9px] text-white/30 shrink-0">{r.language}</span>}
                    <span className="font-mono text-[9px] text-white/25 ml-auto shrink-0">{isLinked ? "LINKED" : ago(r.pushedAt)}</span>
                  </span>
                  {r.description && <span className="block text-[11px] text-white/40 truncate mt-0.5">{r.description}</span>}
                  {row && (
                    <span className={`flex items-center gap-1.5 mt-1 text-[10px] font-mono ${row.state === "error" ? "text-rose-300" : row.state === "done" ? "text-emerald-300" : "text-amber-300"}`}>
                      {row.state === "cloning" && <Loader2 className="h-3 w-3 animate-spin" />}
                      {row.state === "done" && <Check className="h-3 w-3" />}
                      {row.state === "error" && <AlertTriangle className="h-3 w-3" />}
                      {row.state === "cloning" ? "CLONING…" : (row.msg || row.state).toUpperCase()}
                    </span>
                  )}
                </span>
              </button>
            );
          })}
        </div>

        <div className="flex items-center justify-between gap-3 mt-4 shrink-0">
          <span className="font-mono text-[10px] tracking-[0.18em] text-white/40">
            {finished ? "DONE" : `${sel.size} SELECTED`}
          </span>
          {finished ? (
            <button onClick={onClose}
              className="px-5 py-2.5 rounded-full border border-white/15 hover:bg-white/5 font-mono text-[11px] tracking-[0.18em] text-white/80">
              CLOSE
            </button>
          ) : (
            <button onClick={runImport} disabled={sel.size === 0 || running}
              className="flex items-center gap-2 px-5 py-2.5 rounded-full border border-amber-400/30 bg-amber-400/[0.08] hover:bg-amber-400/[0.15] font-mono text-[11px] tracking-[0.18em] text-amber-300 disabled:opacity-40">
              {running && <Loader2 className="h-3 w-3 animate-spin" />}
              {running ? "IMPORTING…" : `CLONE + ADD ${sel.size > 0 ? sel.size : ""}`}
            </button>
          )}
        </div>
      </motion.div>
    </motion.div>
  );
}
