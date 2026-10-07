"use client";
import { useState, useMemo } from "react";
import { motion, AnimatePresence } from "framer-motion";
import {
  ExternalLink, Github, Smartphone, X, AlertCircle, Plus,
  Search, FolderOpen, Mail, Layers,
} from "lucide-react";
import { Project, colorTokens, STATUS_COLOR, ProjectStatus, slugify } from "@/lib/projects";
import GithubImportModal from "@/components/GithubImportModal";

interface Props {
  projects: Project[];
  activeId: string | null;
  onActivate: (id: string) => void;
  onRefresh: () => void;
  loading: boolean;
}

const HOST_LABELS: Record<string, string> = {
  vercel: "Vercel", netlify: "Netlify", supabase: "Supabase", other: "Other",
};

// Status display order + labels
const STATUS_ORDER: ProjectStatus[] = ["live", "building", "idea", "archived"];
const STATUS_LABEL: Record<ProjectStatus, string> = {
  live: "LIVE", building: "IN DEVELOPMENT", idea: "CONCEPT", archived: "ARCHIVED",
};

export default function ProjectsView({ projects, activeId, onActivate, onRefresh, loading }: Props) {
  const [selected, setSelected] = useState<Project | null>(null);
  const [discovering, setDiscovering] = useState(false);
  const [discoveryReport, setDiscoveryReport] = useState<string | null>(null);
  const [filter, setFilter] = useState<"all" | "live" | "building" | "idea" | "ios">("all");
  const [showNew, setShowNew] = useState(false);
  const [showGithub, setShowGithub] = useState(false);

  const runDiscovery = async () => {
    if (discovering) return;
    setDiscovering(true);
    setDiscoveryReport(null);
    try {
      const res = await fetch("/api/projects/discover", { method: "POST" });
      const data = await res.json();
      if (data.ok) {
        const lines = [`✓ Scanned ${data.discoveredCount} repos`, `✓ Matched ${data.matchCount}`];
        if (data.unmatchedCount) lines.push(`⊙ ${data.unmatchedCount} unmatched`);
        setDiscoveryReport(lines.join("  ·  "));
        onRefresh();
      } else setDiscoveryReport("✗ " + (data.error || "Discovery failed"));
    } catch (err: any) {
      setDiscoveryReport("✗ " + (err?.message || "Network error"));
    } finally {
      setDiscovering(false);
      setTimeout(() => setDiscoveryReport(null), 8000);
    }
  };

  // Stat-tile filter: which projects are visible
  const visible = useMemo(() => {
    if (filter === "all") return projects;
    if (filter === "ios") return projects.filter(p => p.ios);
    return projects.filter(p => p.status === filter);
  }, [projects, filter]);

  // Group projects by status, with the umbrella (prive-systems) pinned first within live
  const grouped = useMemo(() => {
    const g: Record<ProjectStatus, Project[]> = { live: [], building: [], idea: [], archived: [] };
    for (const p of visible) (g[p.status] ||= []).push(p);
    // pin umbrella to front of its group
    for (const s of STATUS_ORDER) {
      g[s].sort((a, b) => {
        if (a.tags?.includes("umbrella")) return -1;
        if (b.tags?.includes("umbrella")) return 1;
        return a.name.localeCompare(b.name);
      });
    }
    return g;
  }, [visible]);

  const stats = useMemo(() => {
    const live = projects.filter(p => p.status === "live").length;
    const building = projects.filter(p => p.status === "building").length;
    const idea = projects.filter(p => p.status === "idea").length;
    const ios = projects.filter(p => p.ios).length;
    return { total: projects.length, live, building, idea, ios };
  }, [projects]);

  if (loading) {
    return <div className="font-mono text-[11px] tracking-[0.22em] text-white/40">LOADING PROJECTS…</div>;
  }

  return (
    <>
      {/* Hero */}
      <div className="mb-6 flex items-end justify-between flex-wrap gap-3">
        <div>
          <div className="font-mono text-[10px] tracking-[0.3em] text-amber-400/80 mb-1">PORTFOLIO</div>
          <h1 className="font-display text-[34px] md:text-[42px] font-light tracking-tight text-white leading-none">
            Projects
          </h1>
          <div className="text-[13px] text-white/55 mt-1.5 max-w-2xl">
            Pick one from the switcher to filter the workspace. Edit any project in Obsidian.
          </div>
        </div>
        <div className="flex items-center gap-2">
          <button onClick={runDiscovery} disabled={discovering}
            className="flex items-center gap-2 px-4 py-2 rounded-full border border-white/[0.08] hover:border-white/25 hover:bg-white/[0.04] font-mono text-[11px] tracking-[0.18em] text-white/70 hover:text-white disabled:opacity-50"
            title="Scan your Mac for local copies of these repos">
            <Search className="h-3 w-3" strokeWidth={2} />
            {discovering ? "SCANNING…" : "DISCOVER PATHS"}
          </button>
          <button onClick={() => setShowGithub(true)}
            className="flex items-center gap-2 px-4 py-2 rounded-full border border-white/[0.08] hover:border-white/25 hover:bg-white/[0.04] font-mono text-[11px] tracking-[0.18em] text-white/70 hover:text-white transition-colors">
            <Github className="h-3 w-3" strokeWidth={2} /> FROM GITHUB
          </button>
          <button onClick={() => setShowNew(true)}
            className="flex items-center gap-2 px-4 py-2 rounded-full border border-amber-400/30 bg-amber-400/[0.06] hover:bg-amber-400/[0.12] hover:border-amber-400/60 font-mono text-[11px] tracking-[0.18em] text-amber-300 transition-colors">
            <Plus className="h-3 w-3" strokeWidth={2} /> NEW PROJECT
          </button>
        </div>
      </div>

      {/* Portfolio stat strip */}
      <div className="grid grid-cols-2 md:grid-cols-5 gap-2 mb-6">
        <StatTile label="TOTAL" value={stats.total} hint="projects"
          active={filter === "all"} onClick={() => setFilter("all")} />
        <StatTile label="LIVE" value={stats.live} color="#34d399"
          active={filter === "live"} onClick={() => setFilter(f => f === "live" ? "all" : "live")} />
        <StatTile label="BUILDING" value={stats.building} color="#f5b400"
          active={filter === "building"} onClick={() => setFilter(f => f === "building" ? "all" : "building")} />
        <StatTile label="CONCEPT" value={stats.idea} color="#94a3b8"
          active={filter === "idea"} onClick={() => setFilter(f => f === "idea" ? "all" : "idea")} />
        <StatTile label="iOS APPS" value={stats.ios} color="#7dd3fc"
          active={filter === "ios"} onClick={() => setFilter(f => f === "ios" ? "all" : "ios")} />
      </div>

      {discoveryReport && (
        <motion.div initial={{ opacity: 0, y: -6 }} animate={{ opacity: 1, y: 0 }}
          className="mb-4 rounded-lg border border-emerald-400/30 bg-emerald-400/[0.06] px-3 py-2 font-mono text-[11px] text-emerald-300">
          {discoveryReport}
        </motion.div>
      )}

      {/* Status-grouped sections */}
      {STATUS_ORDER.map(status => {
        const list = grouped[status];
        if (!list || list.length === 0) return null;
        return (
          <div key={status} className="mb-9">
            <div className="flex items-center gap-2.5 mb-4">
              <span className="h-px w-7" style={{ background: STATUS_COLOR[status] + "80" }} />
              <span className="font-mono text-[10px] tracking-[0.32em]" style={{ color: STATUS_COLOR[status] }}>
                {STATUS_LABEL[status]}
              </span>
              <span className="font-mono text-[10px] text-white/30">({list.length})</span>
            </div>
            <motion.div
              className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3"
              initial="hidden" animate="show"
              variants={{ show: { transition: { staggerChildren: 0.04 } } }}
            >
              {list.map(p => (
                <ProjectCard key={p.id} project={p} isActive={p.id === activeId}
                  onClick={() => setSelected(p)} onActivate={() => onActivate(p.id)} />
              ))}
            </motion.div>
          </div>
        );
      })}

      <AnimatePresence>
        {showGithub && (
          <GithubImportModal
            projects={projects}
            onClose={() => setShowGithub(false)}
            onImported={() => onRefresh()}
          />
        )}
        {showNew && (
          <NewProjectModal
            existingIds={projects.map(p => p.id)}
            onClose={() => setShowNew(false)}
            onCreated={() => { setShowNew(false); onRefresh(); }}
          />
        )}
        {selected && (
          <ProjectDetail project={selected} onClose={() => setSelected(null)}
            onActivate={() => { onActivate(selected.id); setSelected(null); }} />
        )}
      </AnimatePresence>
    </>
  );
}

function StatTile({ label, value, hint, color, active, onClick }: {
  label: string; value: number; hint?: string; color?: string; active?: boolean; onClick?: () => void;
}) {
  const accent = color || "#f5b400";
  return (
    <button onClick={onClick}
      className={`rounded-xl border px-4 py-3 text-left transition-colors ${active
        ? "bg-white/[0.05]"
        : "border-white/[0.06] bg-white/[0.015] hover:border-white/20 hover:bg-white/[0.03]"}`}
      style={active ? { borderColor: accent + "99", boxShadow: `0 0 12px ${accent}22` } : undefined}
      title={active ? "Showing this group — click to show all" : `Show only ${label.toLowerCase()}`}>
      <div className={`font-mono text-[9px] tracking-[0.24em] mb-1 ${active ? "text-white/75" : "text-white/40"}`}>{label}</div>
      <div className="flex items-baseline gap-1.5">
        <span className="font-display text-[26px] leading-none tabular-nums"
          style={{ color: color || "#ffffff" }}>{value}</span>
        {hint && <span className="text-[10px] text-white/35">{hint}</span>}
      </div>
    </button>
  );
}

function ProjectCard({ project, isActive, onClick, onActivate }: {
  project: Project; isActive: boolean; onClick: () => void; onActivate: () => void;
}) {
  const c = colorTokens(project.color);
  const statusColor = STATUS_COLOR[project.status];
  const isUmbrella = project.tags?.includes("umbrella");

  return (
    <motion.div
      variants={{ hidden: { opacity: 0, y: 10 }, show: { opacity: 1, y: 0 } }}
      whileHover={{ y: -3 }}
      onClick={onClick}
      className={`relative rounded-2xl border bg-white/[0.02] p-4 cursor-pointer overflow-hidden transition-colors ${
        isActive ? "border-white/25" : "border-white/[0.07] hover:border-white/[0.16]"
      } ${isUmbrella ? "sm:col-span-2 lg:col-span-1" : ""}`}
      style={isActive ? { boxShadow: `0 0 28px ${c.glow}` } : {}}
    >
      {/* brand-color radial glow */}
      <div className="absolute -top-14 -right-14 h-36 w-36 rounded-full opacity-[0.18] pointer-events-none blur-xl"
        style={{ background: `radial-gradient(circle, ${c.hex}, transparent 70%)` }} />
      {/* top hairline in brand color */}
      <div className="absolute top-0 left-0 right-0 h-[2px] opacity-60"
        style={{ background: `linear-gradient(90deg, ${c.hex}, transparent)` }} />

      <div className="relative">
        <div className="flex items-start justify-between mb-2">
          <div className="flex items-center gap-2 min-w-0">
            <span className="h-2 w-2 rounded-full shrink-0" style={{ background: c.hex, boxShadow: `0 0 8px ${c.glow}` }} />
            <span className="font-display text-[15px] text-white font-medium truncate">{project.name}</span>
            {isUmbrella && <Layers className="h-3 w-3 text-white/40 shrink-0" strokeWidth={1.5} />}
          </div>
          {isActive && (
            <span className="font-mono text-[8px] tracking-[0.2em] text-amber-300 px-1.5 py-0.5 rounded bg-amber-400/15 shrink-0">ACTIVE</span>
          )}
        </div>

        <div className="text-[11.5px] text-white/55 line-clamp-2 mb-3 min-h-[32px]">{project.description}</div>

        <div className="flex items-center gap-1.5 flex-wrap mb-3">
          <span className="font-mono text-[8.5px] tracking-[0.15em] px-1.5 py-0.5 rounded" style={{ background: statusColor + "22", color: statusColor }}>
            {project.status.toUpperCase()}
          </span>
          {project.hosting.map(h => (
            <span key={h} className="font-mono text-[8.5px] tracking-[0.15em] px-1.5 py-0.5 rounded bg-white/[0.04] text-white/55">
              {(HOST_LABELS[h] || h).toUpperCase()}
            </span>
          ))}
          {project.ios && (
            <span className="font-mono text-[8.5px] tracking-[0.15em] px-1.5 py-0.5 rounded bg-white/[0.04] text-white/55 flex items-center gap-1">
              <Smartphone className="h-2.5 w-2.5" strokeWidth={2} /> iOS
            </span>
          )}
          {project.localPath && (
            <span className="font-mono text-[8.5px] tracking-[0.15em] px-1.5 py-0.5 rounded bg-emerald-400/[0.08] text-emerald-300/80 flex items-center gap-1">
              <FolderOpen className="h-2.5 w-2.5" strokeWidth={2} /> LOCAL
            </span>
          )}
          {project.email && (
            <span className="font-mono text-[8.5px] tracking-[0.15em] px-1.5 py-0.5 rounded bg-white/[0.04] text-white/45 flex items-center gap-1">
              <Mail className="h-2.5 w-2.5" strokeWidth={2} /> {project.emailProvider === "google-workspace" ? "GWS" : "MAIL"}
            </span>
          )}
        </div>

        <button onClick={(e) => { e.stopPropagation(); onActivate(); }}
          className="w-full font-mono text-[10px] tracking-[0.2em] py-1.5 rounded-full border border-white/[0.08] hover:border-white/20 hover:bg-white/[0.04] text-white/65 hover:text-white transition-colors">
          {isActive ? "✓ ACTIVE WORKSPACE" : "SET ACTIVE"}
        </button>
      </div>
    </motion.div>
  );
}

function ProjectDetail({ project, onClose, onActivate }: {
  project: Project; onClose: () => void; onActivate: () => void;
}) {
  const c = colorTokens(project.color);
  const statusColor = STATUS_COLOR[project.status];
  const [openErr, setOpenErr] = useState<string | null>(null);

  const openLocal = async () => {
    if (!project.localPath) return;
    setOpenErr(null);
    try {
      const res = await fetch("/api/projects/open", {
        method: "POST", headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ path: project.localPath }),
      });
      const data = await res.json();
      if (!data.ok) setOpenErr(data.error || "Couldn't open folder");
    } catch (err: any) { setOpenErr(err?.message || "Network error"); }
  };

  return (
    <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
      className="fixed inset-0 z-50 bg-black/70 backdrop-blur-sm flex items-center justify-center p-4" onClick={onClose}>
      <motion.div initial={{ scale: 0.96, opacity: 0 }} animate={{ scale: 1, opacity: 1 }} exit={{ scale: 0.96, opacity: 0 }}
        onClick={e => e.stopPropagation()}
        className="relative w-full max-w-2xl rounded-2xl border border-white/[0.1] bg-[#0a0a0a] p-6 overflow-hidden max-h-[85vh] overflow-y-auto"
        style={{ boxShadow: `0 0 60px ${c.glow}` }}>
        <div className="absolute -top-20 -right-20 h-48 w-48 rounded-full opacity-20 pointer-events-none blur-xl"
          style={{ background: `radial-gradient(circle, ${c.hex}, transparent 70%)` }} />
        <div className="relative">
          <button onClick={onClose} className="absolute top-0 right-0 h-7 w-7 grid place-items-center rounded-full hover:bg-white/5 text-white/40 hover:text-white">
            <X className="h-4 w-4" strokeWidth={1.5} />
          </button>
          <div className="flex items-center gap-3 mb-2">
            <span className="h-3 w-3 rounded-full" style={{ background: c.hex, boxShadow: `0 0 14px ${c.glow}` }} />
            <span className="font-mono text-[10px] tracking-[0.28em]" style={{ color: statusColor }}>{project.status.toUpperCase()}</span>
          </div>
          <h2 className="font-display text-[26px] text-white font-medium mb-1">{project.name}</h2>
          <p className="text-[13px] text-white/65 mb-5">{project.description}</p>

          <div className="flex flex-wrap gap-2 mb-5">
            {project.website && (
              <a href={project.website} target="_blank" rel="noopener noreferrer"
                className="flex items-center gap-1.5 px-3 py-1.5 rounded-full border border-white/[0.1] hover:border-white/25 hover:bg-white/[0.04] text-[11px] text-white/80">
                <ExternalLink className="h-3 w-3" strokeWidth={1.5} /> Website
              </a>
            )}
            {project.repos.map(r => (
              <a key={r} href={`https://github.com/${r}`} target="_blank" rel="noopener noreferrer"
                className="flex items-center gap-1.5 px-3 py-1.5 rounded-full border border-white/[0.1] hover:border-white/25 hover:bg-white/[0.04] text-[11px] text-white/80">
                <Github className="h-3 w-3" strokeWidth={1.5} /> {r.split("/")[1]}
              </a>
            ))}
            {project.localPath && (
              <button onClick={openLocal} className="flex items-center gap-1.5 px-3 py-1.5 rounded-full border text-[11px]"
                style={{ borderColor: c.hex + "55", color: c.hex, background: c.soft }}>
                <FolderOpen className="h-3 w-3" strokeWidth={1.5} /> Open local folder
              </button>
            )}
          </div>

          {openErr && (
            <div className="mb-4 rounded-lg border border-rose-400/30 bg-rose-400/[0.06] px-3 py-2 font-mono text-[11px] text-rose-300">{openErr}</div>
          )}

          <div className="grid grid-cols-2 gap-2 mb-3">
            <div className="rounded-lg border border-white/[0.05] p-3 bg-white/[0.015]">
              <div className="font-mono text-[9px] tracking-[0.22em] text-white/40 mb-1.5">HOSTING</div>
              <div className="flex flex-wrap gap-1">
                {project.hosting.length === 0 && <span className="text-[11px] text-white/40">—</span>}
                {project.hosting.map(h => (
                  <span key={h} className="font-mono text-[10px] tracking-[0.15em] px-1.5 py-0.5 rounded bg-white/[0.04] text-white/70">
                    {(HOST_LABELS[h] || h).toUpperCase()}
                  </span>
                ))}
              </div>
            </div>
            <div className="rounded-lg border border-white/[0.05] p-3 bg-white/[0.015]">
              <div className="font-mono text-[9px] tracking-[0.22em] text-white/40 mb-1.5">iOS APP</div>
              {project.ios ? (
                <div className="flex items-start gap-1.5">
                  <Smartphone className="h-3 w-3 text-white/60 mt-0.5 shrink-0" strokeWidth={1.5} />
                  <div>
                    <div className="font-mono text-[10.5px] text-white/80 break-all">{project.ios.bundleId}</div>
                    {!project.ios.verified && (
                      <div className="flex items-center gap-1 mt-1">
                        <AlertCircle className="h-2.5 w-2.5 text-amber-400" strokeWidth={2} />
                        <span className="font-mono text-[9px] tracking-[0.15em] text-amber-400/80">UNVERIFIED</span>
                      </div>
                    )}
                  </div>
                </div>
              ) : <span className="text-[11px] text-white/40">No iOS app</span>}
            </div>
          </div>

          {/* Email row */}
          <div className="rounded-lg border border-white/[0.05] p-3 bg-white/[0.015] mb-5">
            <div className="font-mono text-[9px] tracking-[0.22em] text-white/40 mb-1.5 flex items-center gap-1">
              <Mail className="h-3 w-3" strokeWidth={1.5} /> EMAIL
            </div>
            {project.email ? (
              <div className="flex items-center justify-between gap-2 flex-wrap">
                <span className="font-mono text-[11px] text-white/80 break-all">{project.email}</span>
                <span className="font-mono text-[9px] tracking-[0.15em] px-1.5 py-0.5 rounded shrink-0"
                  style={{
                    background: project.emailProvider === "google-workspace" ? "rgba(66,133,244,0.15)" : "rgba(148,163,184,0.12)",
                    color: project.emailProvider === "google-workspace" ? "#7dadff" : "#cbd5e1",
                  }}>
                  {project.emailProvider === "google-workspace" ? "GOOGLE WORKSPACE" :
                   project.emailProvider === "hostinger" ? "HOSTINGER" :
                   project.emailProvider === "forwarder" ? "FORWARDER" : "NONE"}
                </span>
              </div>
            ) : (
              <span className="text-[11px] text-white/40">{project.emailProvider === "none" ? "No email yet" : "TBD"}</span>
            )}
          </div>

          {project.localPath && (
            <div className="mb-5 rounded-lg border border-white/[0.05] p-3 bg-white/[0.015]">
              <div className="font-mono text-[9px] tracking-[0.22em] text-white/40 mb-1.5 flex items-center gap-1">
                <FolderOpen className="h-3 w-3" strokeWidth={1.5} /> LOCAL PATH
              </div>
              <div className="font-mono text-[10.5px] text-white/75 break-all">{project.localPath}</div>
            </div>
          )}

          {project.tags.length > 0 && (
            <div className="mb-5">
              <div className="font-mono text-[9px] tracking-[0.22em] text-white/40 mb-1.5">TAGS</div>
              <div className="flex flex-wrap gap-1.5">
                {project.tags.map(t => (
                  <span key={t} className="text-[10px] px-2 py-0.5 rounded-full border border-white/[0.06] bg-white/[0.02] text-white/55">#{t}</span>
                ))}
              </div>
            </div>
          )}

          {project.notes && (
            <div className="mb-5">
              <div className="font-mono text-[9px] tracking-[0.22em] text-white/40 mb-1.5">NOTES</div>
              <div className="rounded-lg border border-white/[0.05] bg-white/[0.015] p-3 text-[12px] text-white/70 whitespace-pre-wrap">{project.notes}</div>
            </div>
          )}

          <button onClick={onActivate}
            className="w-full py-2.5 rounded-full font-mono text-[11px] tracking-[0.2em] font-medium"
            style={{ background: c.hex, color: "#000", boxShadow: `0 0 18px ${c.glow}` }}>
            SET AS ACTIVE WORKSPACE
          </button>
          <div className="mt-4 text-[10.5px] text-white/35 text-center font-mono tracking-[0.15em]">
            EDIT IN OBSIDIAN · AEGIS/Projects/{project.id}.md
          </div>
        </div>
      </motion.div>
    </motion.div>
  );
}


// --- New Project modal -------------------------------------------------------
const PRESET_COLORS = ["#F5B400", "#3B82F6", "#10B981", "#A855F7", "#E11D48", "#00E888", "#F59E0B", "#14B8A6", "#285ED2", "#94A3B8"];

function NewProjectModal({ existingIds, onClose, onCreated }: {
  existingIds: string[]; onClose: () => void; onCreated: () => void;
}) {
  const [name, setName] = useState("");
  const [description, setDescription] = useState("");
  const [status, setStatus] = useState<ProjectStatus>("idea");
  const [color, setColor] = useState(PRESET_COLORS[0]);
  const [website, setWebsite] = useState("");
  const [tags, setTags] = useState("");
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const id = slugify(name);
  const duplicate = !!id && existingIds.includes(id);

  const submit = async () => {
    if (!name.trim() || !id || duplicate || saving) return;
    setSaving(true); setError(null);
    try {
      const res = await fetch("/api/projects", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          id, name: name.trim(),
          description: description.trim(),
          status, color,
          website: website.trim() || undefined,
          tags: tags.split(",").map(t => t.trim()).filter(Boolean),
          repos: [], hosting: [],
        }),
      });
      const data = await res.json();
      if (data.ok) onCreated();
      else setError(data.error || "Create failed");
    } catch (err: any) {
      setError(err?.message || "Network error");
    } finally { setSaving(false); }
  };

  const field = "w-full rounded-xl border border-white/10 bg-black/40 px-3.5 py-2.5 text-[13px] text-white placeholder-white/25 outline-none focus:border-amber-400/50";
  const label = "block font-mono text-[9px] tracking-[0.25em] text-white/45 mb-1.5";

  return (
    <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
      className="fixed inset-0 z-50 bg-black/70 backdrop-blur-sm flex items-center justify-center p-4" onClick={onClose}>
      <motion.div initial={{ opacity: 0, scale: 0.96, y: 10 }} animate={{ opacity: 1, scale: 1, y: 0 }} exit={{ opacity: 0, scale: 0.96, y: 10 }}
        className="w-full max-w-md rounded-2xl border border-white/[0.09] bg-[#0b0b0b] p-6 max-h-[85vh] overflow-y-auto"
        onClick={e => e.stopPropagation()}>
        <div className="flex items-center justify-between mb-5">
          <div>
            <div className="font-mono text-[10px] tracking-[0.28em] text-amber-300/80 mb-1">PORTFOLIO</div>
            <div className="text-[18px] text-white font-medium">New Project</div>
          </div>
          <button onClick={onClose} className="h-7 w-7 grid place-items-center rounded-full hover:bg-white/5 text-white/40 hover:text-white">
            <X className="h-4 w-4" strokeWidth={1.5} />
          </button>
        </div>

        <div className="space-y-4">
          <div>
            <label className={label}>NAME *</label>
            <input autoFocus value={name} onChange={e => setName(e.target.value)} placeholder="e.g. Loc8ID" className={field} />
            {id && (
              <div className="mt-1 font-mono text-[10px] text-white/30">
                id: {id}{duplicate && <span className="text-rose-400 ml-2">already exists</span>}
              </div>
            )}
          </div>
          <div>
            <label className={label}>DESCRIPTION</label>
            <input value={description} onChange={e => setDescription(e.target.value)} placeholder="One sharp sentence" className={field} />
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className={label}>STATUS</label>
              <select value={status} onChange={e => setStatus(e.target.value as ProjectStatus)}
                className={field + " appearance-none"}>
                <option value="idea">Concept</option>
                <option value="building">In development</option>
                <option value="live">Live</option>
                <option value="archived">Archived</option>
              </select>
            </div>
            <div>
              <label className={label}>WEBSITE</label>
              <input value={website} onChange={e => setWebsite(e.target.value)} placeholder="https://…" className={field} />
            </div>
          </div>
          <div>
            <label className={label}>COLOR</label>
            <div className="flex items-center gap-2 flex-wrap">
              {PRESET_COLORS.map(c => (
                <button key={c} onClick={() => setColor(c)}
                  className={`h-6 w-6 rounded-full border-2 transition-transform ${color === c ? "border-white scale-110" : "border-transparent hover:scale-105"}`}
                  style={{ background: c, boxShadow: color === c ? `0 0 10px ${c}aa` : "none" }} />
              ))}
              <input value={color} onChange={e => setColor(e.target.value)}
                className="w-24 rounded-lg border border-white/10 bg-black/40 px-2 py-1 font-mono text-[11px] text-white/70 outline-none focus:border-amber-400/50" />
            </div>
          </div>
          <div>
            <label className={label}>TAGS (COMMA-SEPARATED)</label>
            <input value={tags} onChange={e => setTags(e.target.value)} placeholder="saas, web3, ios" className={field} />
          </div>

          {error && <div className="rounded-xl border border-rose-500/25 bg-rose-500/[0.06] px-3.5 py-2.5 text-[12px] text-rose-300/90">{error}</div>}

          <button onClick={submit} disabled={!name.trim() || !id || duplicate || saving}
            className="w-full mt-1 rounded-full bg-amber-400 hover:bg-amber-300 disabled:opacity-40 disabled:cursor-not-allowed text-black font-mono text-[12px] tracking-[0.2em] font-medium py-3 transition-colors">
            {saving ? "CREATING…" : "CREATE PROJECT"}
          </button>
          <div className="text-[10px] text-white/30 leading-relaxed">
            Creates AEGIS/Projects/{id || "<id>"}.md in your vault with proper frontmatter. Add the brief later under ## Notes.
          </div>
        </div>
      </motion.div>
    </motion.div>
  );
}
