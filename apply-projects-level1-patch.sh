#!/usr/bin/env bash
# apply-projects-level1-patch.sh
#
# Two things bundled:
#   PATH A — captures the email inventory: adds email + emailProvider to every project
#   LEVEL 1 — Projects view glow-up: status-grouped sections, portfolio stat strip,
#             brand-color glow, entrance animations, umbrella project pinned to top
#
# Run from inside the aegis project directory:
#   bash apply-projects-level1-patch.sh

set -e

if [ ! -f package.json ] || [ ! -d components ]; then
  echo "❌ Run from inside the aegis project directory."
  exit 1
fi
if [ ! -f lib/projects.ts ]; then
  echo "❌ run apply-multiproject-patch.sh + apply-branding-patch.sh first."
  exit 1
fi

VAULT="${OBSIDIAN_VAULT:-$(grep ^OBSIDIAN_VAULT .env.local 2>/dev/null | cut -d= -f2-)}"

echo "📦 Backing up to .pre-level1-backup/"
mkdir -p .pre-level1-backup/lib .pre-level1-backup/components .pre-level1-backup/app/api/projects
cp lib/projects.ts                .pre-level1-backup/lib/
cp components/ProjectsView.tsx    .pre-level1-backup/components/
cp app/api/projects/route.ts      .pre-level1-backup/app/api/projects/

# -----------------------------------------------------------------------------
# 1. Add email fields + emailProvider to the Project type and seed data
# -----------------------------------------------------------------------------
echo "✏️  Adding email inventory to lib/projects.ts"
python3 - <<'PYEOF'
p = "lib/projects.ts"
src = open(p).read()

# 1a. Add fields to interface
if "emailProvider" not in src:
    src = src.replace(
        "  /** Absolute path on local filesystem if the code lives on this Mac */\n  localPath?: string;",
        "  /** Absolute path on local filesystem if the code lives on this Mac */\n  localPath?: string;\n  /** Primary contact email for the project */\n  email?: string;\n  /** Where that email is hosted */\n  emailProvider?: \"hostinger\" | \"google-workspace\" | \"forwarder\" | \"none\";",
        1
    )

# 1b. Map of project id -> (email, provider)
email_map = {
    "prive-systems":      ("hub@privesystems.com",     "hostinger"),
    "my-central-domains": ("hello@mycentral.domains",  "hostinger"),
    "aura":               ("hello@auraos.vip",         "hostinger"),
    "vault-legacy":       (None,                        None),          # TBD
    "jetvan-vip":         ("hello@jetvan.vip",         "google-workspace"),
    "api-monitor":        ("ping@apimonitor.ai",       "hostinger"),
    "netty-banks":        ("hello@netty.pro",          "hostinger"),
    "jetpedia":           ("fly@jetpedia.io",          "hostinger"),
    "yachtpedia":         ("helm@yachtpedia.io",       "hostinger"),
    "autopedia":          (None,                        "none"),
    "memory-soundx":      ("play@memorysoundx.com",    "hostinger"),
}

import re
for pid, (email, provider) in email_map.items():
    # find the seed object for this id and inject email fields after its `tags:` line
    # we match: id: "<pid>", ... up to the tags line
    pattern = re.compile(
        r'(\{\s*\n\s*id: "' + re.escape(pid) + r'",.*?tags: \[[^\]]*\],\n)',
        re.DOTALL
    )
    m = pattern.search(src)
    if not m:
        print(f"   ⚠ couldn't find seed for {pid}")
        continue
    block = m.group(1)
    if "email:" in block:
        continue  # already has it
    inject = ""
    if email:
        inject += f'    email: "{email}",\n'
    if provider:
        inject += f'    emailProvider: "{provider}",\n'
    if inject:
        src = src.replace(block, block + inject, 1)

open(p, "w").write(src)
print("   ✓ email fields added to type + seeds")
PYEOF

# -----------------------------------------------------------------------------
# 2. Update the projects API to serialize email fields to/from markdown
# -----------------------------------------------------------------------------
echo "✏️  Updating app/api/projects/route.ts to persist email fields"
python3 - <<'PYEOF'
p = "app/api/projects/route.ts"
src = open(p).read()

# serialize: add to projectToMarkdown frontmatter
if "if (p.email)" not in src:
    src = src.replace(
        "  if (p.localPath) fm.localPath = p.localPath;",
        "  if (p.localPath) fm.localPath = p.localPath;\n  if (p.email) fm.email = p.email;\n  if (p.emailProvider) fm.emailProvider = p.emailProvider;",
        1
    )

# deserialize: add to markdownToProject
if "email: d.email" not in src:
    src = src.replace(
        "      localPath: d.localPath || undefined,",
        "      localPath: d.localPath || undefined,\n      email: d.email || undefined,\n      emailProvider: d.emailProvider || undefined,",
        1
    )

# upsert preserve in POST
if "email: body.email" not in src:
    src = src.replace(
        "    localPath: body.localPath ?? existing?.localPath,",
        "    localPath: body.localPath ?? existing?.localPath,\n    email: body.email ?? existing?.email,\n    emailProvider: body.emailProvider ?? existing?.emailProvider,",
        1
    )

open(p, "w").write(src)
print("   ✓ API persists email fields")
PYEOF

# -----------------------------------------------------------------------------
# 3. Rewrite ProjectsView.tsx — status grouping + stat strip + polish
# -----------------------------------------------------------------------------
echo "✏️  Rewriting components/ProjectsView.tsx (Level 1 glow-up)"
cat > components/ProjectsView.tsx <<'EOF'
"use client";
import { useState, useMemo } from "react";
import { motion, AnimatePresence } from "framer-motion";
import {
  ExternalLink, Github, Smartphone, X, AlertCircle, Plus,
  Search, FolderOpen, Mail, Layers,
} from "lucide-react";
import { Project, colorTokens, STATUS_COLOR, ProjectStatus } from "@/lib/projects";

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

  // Group projects by status, with the umbrella (prive-systems) pinned first within live
  const grouped = useMemo(() => {
    const g: Record<ProjectStatus, Project[]> = { live: [], building: [], idea: [], archived: [] };
    for (const p of projects) (g[p.status] ||= []).push(p);
    // pin umbrella to front of its group
    for (const s of STATUS_ORDER) {
      g[s].sort((a, b) => {
        if (a.tags?.includes("umbrella")) return -1;
        if (b.tags?.includes("umbrella")) return 1;
        return a.name.localeCompare(b.name);
      });
    }
    return g;
  }, [projects]);

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
          <button disabled
            className="flex items-center gap-2 px-4 py-2 rounded-full border border-white/[0.08] text-white/30 cursor-not-allowed font-mono text-[11px] tracking-[0.18em]">
            <Plus className="h-3 w-3" strokeWidth={2} /> NEW PROJECT
          </button>
        </div>
      </div>

      {/* Portfolio stat strip */}
      <div className="grid grid-cols-2 md:grid-cols-5 gap-2 mb-6">
        <StatTile label="TOTAL" value={stats.total} hint="projects" />
        <StatTile label="LIVE" value={stats.live} color="#34d399" />
        <StatTile label="BUILDING" value={stats.building} color="#f5b400" />
        <StatTile label="CONCEPT" value={stats.idea} color="#94a3b8" />
        <StatTile label="iOS APPS" value={stats.ios} color="#7dd3fc" />
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
        {selected && (
          <ProjectDetail project={selected} onClose={() => setSelected(null)}
            onActivate={() => { onActivate(selected.id); setSelected(null); }} />
        )}
      </AnimatePresence>
    </>
  );
}

function StatTile({ label, value, hint, color }: { label: string; value: number; hint?: string; color?: string }) {
  return (
    <div className="rounded-xl border border-white/[0.06] bg-white/[0.015] px-4 py-3">
      <div className="font-mono text-[9px] tracking-[0.24em] text-white/40 mb-1">{label}</div>
      <div className="flex items-baseline gap-1.5">
        <span className="font-display text-[26px] leading-none tabular-nums"
          style={{ color: color || "#ffffff" }}>{value}</span>
        {hint && <span className="text-[10px] text-white/35">{hint}</span>}
      </div>
    </div>
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
EOF
echo "   ✓ ProjectsView rewritten with status grouping + glow-up"

# -----------------------------------------------------------------------------
# 4. Update existing vault files with email fields (so they show now)
# -----------------------------------------------------------------------------
if [ -n "$VAULT" ] && [ -d "$VAULT/AEGIS/Projects" ]; then
  echo "✏️  Updating existing project files in vault with email fields"
  python3 - "$VAULT/AEGIS/Projects" <<'PYEOF'
import sys, os, re
d = sys.argv[1]
emails = {
    "prive-systems": ("hub@privesystems.com", "hostinger"),
    "my-central-domains": ("hello@mycentral.domains", "hostinger"),
    "aura": ("hello@auraos.vip", "hostinger"),
    "jetvan-vip": ("hello@jetvan.vip", "google-workspace"),
    "api-monitor": ("ping@apimonitor.ai", "hostinger"),
    "netty-banks": ("hello@netty.pro", "hostinger"),
    "jetpedia": ("fly@jetpedia.io", "hostinger"),
    "yachtpedia": ("helm@yachtpedia.io", "hostinger"),
    "autopedia": (None, "none"),
    "memory-soundx": ("play@memorysoundx.com", "hostinger"),
}
updated = 0
for pid, (email, provider) in emails.items():
    f = os.path.join(d, pid + ".md")
    if not os.path.exists(f):
        continue
    txt = open(f).read()
    if "email:" in txt and "emailProvider:" in txt:
        continue
    # insert after the status: line in frontmatter
    lines = txt.split("\n")
    out = []
    for ln in lines:
        out.append(ln)
        if ln.startswith("status:") and email is not None and "email:" not in txt:
            out.append(f'email: {email}')
            out.append(f'emailProvider: {provider}')
        elif ln.startswith("status:") and email is None:
            out.append(f'emailProvider: {provider}')
    open(f, "w").write("\n".join(out))
    updated += 1
print(f"   ✓ updated {updated} vault files with email metadata")
PYEOF
else
  echo "   ⊙ vault not found — email fields will appear on next re-seed"
fi

echo ""
echo "✅ Level 1 + email inventory installed."
echo ""
echo "Refresh AEGIS (no restart needed) and open Projects. You'll see:"
echo "   - Portfolio stat strip (total / live / building / concept / iOS)"
echo "   - Projects grouped into LIVE / IN DEVELOPMENT / CONCEPT sections"
echo "   - Brand-color glow + top hairline on each card"
echo "   - Entrance stagger animation"
echo "   - Email pill on cards; full email + provider in the detail modal"
echo "   - Privé Systems (umbrella) pinned to top of LIVE with a layers icon"
echo ""
echo "Vault Legacy email is marked TBD (no email field). Edit its .md when known."
echo ""
echo "Backups in .pre-level1-backup/ — to revert: cp -r .pre-level1-backup/* ."
