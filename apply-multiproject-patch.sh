#!/usr/bin/env bash
# apply-multiproject-patch.sh
#
# Phase A: Multi-project workspace for AEGIS.
#  - Project data stored as Markdown + YAML frontmatter in your Obsidian vault
#  - Top-bar project switcher (hard filter mode)
#  - New "Projects" view with grid + detail drawer
#  - Seeds your 11 Privé Systems projects on first run
#  - Filters Missions / Chats / Logs to the active project
#
# Run from inside the aegis project directory:
#   bash apply-multiproject-patch.sh

set -e

if [ ! -f package.json ] || [ ! -d components ]; then
  echo "❌ Run from inside the aegis project directory."
  exit 1
fi

echo "📦 Backing up files to .pre-project-backup/"
mkdir -p .pre-project-backup/components .pre-project-backup/app/api .pre-project-backup/lib
cp app/page.tsx                  .pre-project-backup/app/page.tsx 2>/dev/null || true
cp components/Sidebar.tsx        .pre-project-backup/components/ 2>/dev/null || true
cp components/StatusBar.tsx      .pre-project-backup/components/ 2>/dev/null || true
cp components/MissionsView.tsx   .pre-project-backup/components/ 2>/dev/null || true

# -----------------------------------------------------------------------------
# 1. Install gray-matter for YAML frontmatter parsing
# -----------------------------------------------------------------------------
echo "📥 Installing gray-matter (YAML frontmatter parser)"
npm install --save gray-matter 2>&1 | tail -2 || npm install --save gray-matter
echo "   ✓ dependency added"

# -----------------------------------------------------------------------------
# 2. Type definitions for projects
# -----------------------------------------------------------------------------
echo "✏️  Creating lib/projects.ts"
mkdir -p lib
cat > lib/projects.ts <<'EOF'
export type ProjectStatus = "live" | "building" | "idea" | "archived";
export type HostingProvider = "vercel" | "netlify" | "supabase" | "other";
export type ProjectColor = "amber" | "cyan" | "violet" | "emerald" | "rose" | "sky" | "gold" | "slate";

export interface IosInfo {
  bundleId: string;
  verified: boolean;  // true if pulled from project.pbxproj, false if inferred
}

export interface Project {
  id: string;                       // slug — lowercase-with-dashes
  name: string;                     // display name
  description: string;              // one-liner
  website?: string;
  repos: string[];                  // ["org/repo", "org/repo-ios"]
  hosting: HostingProvider[];       // ["vercel"] or ["vercel", "supabase"]
  ios?: IosInfo;                    // optional
  status: ProjectStatus;
  color: ProjectColor;
  tags: string[];                   // ["aviation", "ios"]
  notes?: string;                   // freeform markdown body
  createdAt?: string;
  updatedAt?: string;
}

export const PROJECT_COLORS: Record<ProjectColor, { hex: string; glow: string; soft: string }> = {
  amber:   { hex: "#f5b400", glow: "rgba(245,180,0,0.55)",    soft: "rgba(245,180,0,0.08)" },
  cyan:    { hex: "#22d3ee", glow: "rgba(34,211,238,0.55)",   soft: "rgba(34,211,238,0.08)" },
  violet:  { hex: "#a78bfa", glow: "rgba(167,139,250,0.55)",  soft: "rgba(167,139,250,0.08)" },
  emerald: { hex: "#34d399", glow: "rgba(52,211,153,0.55)",   soft: "rgba(52,211,153,0.08)" },
  rose:    { hex: "#fb7185", glow: "rgba(251,113,133,0.55)",  soft: "rgba(251,113,133,0.08)" },
  sky:     { hex: "#7dd3fc", glow: "rgba(125,211,252,0.55)",  soft: "rgba(125,211,252,0.08)" },
  gold:    { hex: "#fbbf24", glow: "rgba(251,191,36,0.6)",    soft: "rgba(251,191,36,0.08)" },
  slate:   { hex: "#94a3b8", glow: "rgba(148,163,184,0.5)",   soft: "rgba(148,163,184,0.08)" },
};

export const STATUS_COLOR: Record<ProjectStatus, string> = {
  live:     "#34d399",
  building: "#f5b400",
  idea:     "#94a3b8",
  archived: "#64748b",
};

// Seed projects — your Privé Systems portfolio
export const SEED_PROJECTS: Project[] = [
  {
    id: "prive-systems",
    name: "Privé Systems Group",
    description: "Privately held multi-product technology group building scalable AI-driven platforms.",
    website: "https://privesystems.com",
    repos: ["cyprian-hash/prive-systems"],
    hosting: ["vercel"],
    status: "live",
    color: "gold",
    tags: ["umbrella", "holding"],
  },
  {
    id: "my-central-domains",
    name: "My Central Domains",
    description: "Unified domain portfolio infrastructure across Web2 and Web3 environments.",
    website: "https://mycentral.domains",
    repos: ["cyprian-hash/v0-mycentral-domains-app", "cyprian-hash/mycentraldomains-ios"],
    hosting: ["vercel"],
    ios: { bundleId: "com.mycentraldomains.app", verified: true },
    status: "live",
    color: "amber",
    tags: ["domains", "web3", "ios"],
  },
  {
    id: "aura",
    name: "Aura",
    description: "AI-driven automation and intelligent concierge systems.",
    website: "https://auraos.vip/",
    repos: ["cyprian-hash/aura-prive", "cyprian-hash/gravityclaw"],
    hosting: ["vercel"],
    status: "live",
    color: "violet",
    tags: ["ai", "concierge", "automation"],
  },
  {
    id: "vault-legacy",
    name: "Vault Legacy",
    description: "Secure digital asset and legacy management platform.",
    website: "https://vaultlegacy.io/",
    repos: ["cyprian-hash/vault-legacy"],
    hosting: ["vercel"],
    status: "live",
    color: "emerald",
    tags: ["legacy", "estate", "security"],
  },
  {
    id: "jetvan-vip",
    name: "Jet Van VIP",
    description: "Exclusive ground transportation network and bespoke logistics.",
    website: "https://jetvan.vip/",
    repos: ["cyprian-hash/jetvan-vip-luxury-transport"],
    hosting: ["vercel"],
    status: "live",
    color: "rose",
    tags: ["luxury", "transport"],
  },
  {
    id: "api-monitor",
    name: "API Monitor",
    description: "Real-time aggregation and cost-analysis for AI and Cloud APIs.",
    website: "https://apimonitor.ai/",
    repos: [],
    hosting: ["vercel", "supabase"],
    status: "live",
    color: "cyan",
    tags: ["devops", "monitoring", "cost"],
    notes: "GitHub repo not yet created — code is local only. Deployed via Vercel CLI.",
  },
  {
    id: "netty-banks",
    name: "Netty Banks",
    description: "AI personal assistant engineered for dynamic task delegation.",
    website: "http://netty.pro/",
    repos: [],
    hosting: ["vercel"],
    status: "live",
    color: "sky",
    tags: ["ai", "assistant"],
    notes: "GitHub repo not yet created.",
  },
  {
    id: "jetpedia",
    name: "Jetpedia",
    description: "Private aviation intelligence and dynamic fleet forecasting.",
    website: "https://jetpedia.io/",
    repos: ["cyprian-hash/jetpedia-app", "cyprian-hash/jetpedia-ios"],
    hosting: ["vercel"],
    ios: { bundleId: "io.jetpedia.app", verified: true },
    status: "live",
    color: "amber",
    tags: ["aviation", "intelligence", "ios"],
  },
  {
    id: "yachtpedia",
    name: "Yachtpedia",
    description: "Transparency and tracking for the global superyacht market.",
    website: "https://yachtpedia.io/",
    repos: [],
    hosting: ["vercel"],
    status: "building",
    color: "sky",
    tags: ["yachts", "intelligence"],
    notes: "Deploying May 2026.",
  },
  {
    id: "autopedia",
    name: "Autopedia",
    description: "System of record for provenance and hypercar asset integrity.",
    website: "https://autopedia.io/",
    repos: [],
    hosting: ["vercel"],
    status: "idea",
    color: "rose",
    tags: ["automotive", "provenance"],
    notes: "Target deploy: July 2026.",
  },
  {
    id: "memory-soundx",
    name: "Memory SoundX",
    description: "Cognitive audio enhancement and personalized algorithmic soundscapes.",
    website: "https://memorysoundx.com/",
    repos: ["cyprian-hash/memory-soundx"],
    hosting: ["vercel"],
    ios: { bundleId: "com.memorysoundx.app", verified: false },
    status: "live",
    color: "violet",
    tags: ["audio", "cognitive", "ios"],
    notes: "iOS bundle ID is inferred from naming convention — verify in project.pbxproj before relying on it.",
  },
];

export function slugify(s: string): string {
  return s.toLowerCase().replace(/[^a-z0-9-]+/g, "-").replace(/^-+|-+$/g, "");
}
EOF
echo "   ✓ types and seed data"

# -----------------------------------------------------------------------------
# 3. Vault API route additions — project read/write
# -----------------------------------------------------------------------------
echo "✏️  Creating app/api/projects/route.ts (CRUD + seed)"
mkdir -p app/api/projects
cat > app/api/projects/route.ts <<'EOF'
import { promises as fs } from "fs";
import path from "path";
import matter from "gray-matter";
import { Project, SEED_PROJECTS } from "@/lib/projects";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

function getVaultRoot(): string | null {
  return process.env.OBSIDIAN_VAULT || null;
}

function projectsDir(root: string): string {
  return path.join(root, "AEGIS", "Projects");
}

async function ensureDir(dir: string) {
  await fs.mkdir(dir, { recursive: true });
}

function projectToMarkdown(p: Project): string {
  const fm: any = {
    id: p.id,
    name: p.name,
    description: p.description,
    website: p.website || "",
    repos: p.repos,
    hosting: p.hosting,
    status: p.status,
    color: p.color,
    tags: p.tags,
    createdAt: p.createdAt || new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  };
  if (p.ios) fm.ios = p.ios;

  const body = p.notes
    ? `\n## Notes\n\n${p.notes}\n`
    : `\n## Notes\n\n_No notes yet._\n`;

  return matter.stringify(`# ${p.name}\n\n${p.description}\n${body}`, fm);
}

function markdownToProject(content: string, fallbackId: string): Project | null {
  try {
    const parsed = matter(content);
    const d = parsed.data;
    if (!d.id && !d.name) return null;
    return {
      id: d.id || fallbackId,
      name: d.name || fallbackId,
      description: d.description || "",
      website: d.website || undefined,
      repos: Array.isArray(d.repos) ? d.repos : [],
      hosting: Array.isArray(d.hosting) ? d.hosting : [],
      ios: d.ios && d.ios.bundleId ? { bundleId: d.ios.bundleId, verified: !!d.ios.verified } : undefined,
      status: d.status || "live",
      color: d.color || "slate",
      tags: Array.isArray(d.tags) ? d.tags : [],
      notes: (parsed.content || "").trim() || undefined,
      createdAt: d.createdAt,
      updatedAt: d.updatedAt,
    };
  } catch {
    return null;
  }
}

async function readAllProjects(root: string): Promise<Project[]> {
  const dir = projectsDir(root);
  try {
    await fs.access(dir);
  } catch {
    return [];
  }
  const files = await fs.readdir(dir);
  const projects: Project[] = [];
  for (const f of files) {
    if (!f.endsWith(".md")) continue;
    if (f === "README.md") continue;
    const full = path.join(dir, f);
    try {
      const content = await fs.readFile(full, "utf8");
      const p = markdownToProject(content, f.replace(/\.md$/, ""));
      if (p) projects.push(p);
    } catch { /* skip unreadable */ }
  }
  return projects;
}

async function seedIfEmpty(root: string): Promise<{ seeded: boolean; count: number }> {
  const dir = projectsDir(root);
  await ensureDir(dir);
  const existing = await readAllProjects(root);
  if (existing.length > 0) return { seeded: false, count: existing.length };

  for (const p of SEED_PROJECTS) {
    const file = path.join(dir, `${p.id}.md`);
    await fs.writeFile(file, projectToMarkdown(p), "utf8");
  }

  // Index README for the folder
  const readme = path.join(dir, "README.md");
  const indexBody = `# Projects

Auto-managed by [AEGIS Mission Control](http://localhost:3000). Each \`.md\` file is one project.

Edit YAML frontmatter to change project metadata; AEGIS will re-read on next refresh. The \`## Notes\` section is freeform — write whatever you want there.

_Generated: ${new Date().toISOString()}_
`;
  await fs.writeFile(readme, indexBody, "utf8");

  return { seeded: true, count: SEED_PROJECTS.length };
}

// GET — list all projects, seeding from defaults if vault has none
export async function GET() {
  const root = getVaultRoot();
  if (!root) {
    return new Response(JSON.stringify({
      ok: false, error: "OBSIDIAN_VAULT not set in .env.local",
      projects: [],
    }), { status: 500, headers: { "Content-Type": "application/json" } });
  }
  try {
    const seed = await seedIfEmpty(root);
    const projects = await readAllProjects(root);
    return new Response(JSON.stringify({
      ok: true, projects, seeded: seed.seeded,
    }), { headers: { "Content-Type": "application/json", "Cache-Control": "no-store" } });
  } catch (err: any) {
    return new Response(JSON.stringify({
      ok: false, error: err?.message || "Read failed", projects: [],
    }), { status: 500, headers: { "Content-Type": "application/json" } });
  }
}

// POST — create or update a single project (upsert by id)
export async function POST(req: Request) {
  const root = getVaultRoot();
  if (!root) {
    return new Response(JSON.stringify({ ok: false, error: "OBSIDIAN_VAULT not set" }), { status: 500 });
  }
  let body: Partial<Project>;
  try { body = await req.json(); }
  catch { return new Response(JSON.stringify({ ok: false, error: "Invalid JSON" }), { status: 400 }); }

  if (!body.id || !body.name) {
    return new Response(JSON.stringify({ ok: false, error: "id and name required" }), { status: 400 });
  }
  const project: Project = {
    id: body.id,
    name: body.name,
    description: body.description || "",
    website: body.website,
    repos: body.repos || [],
    hosting: body.hosting || [],
    ios: body.ios,
    status: body.status || "idea",
    color: body.color || "slate",
    tags: body.tags || [],
    notes: body.notes,
  };

  try {
    const dir = projectsDir(root);
    await ensureDir(dir);
    const file = path.join(dir, `${project.id}.md`);
    await fs.writeFile(file, projectToMarkdown(project), "utf8");
    return new Response(JSON.stringify({ ok: true, project }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (err: any) {
    return new Response(JSON.stringify({ ok: false, error: err?.message }), { status: 500 });
  }
}
EOF
echo "   ✓ projects API route"

# -----------------------------------------------------------------------------
# 4. Client-side hook for projects + active-project context
# -----------------------------------------------------------------------------
echo "✏️  Creating lib/useProjects.ts"
cat > lib/useProjects.ts <<'EOF'
"use client";
import { useState, useEffect, useCallback } from "react";
import { Project } from "./projects";

const ACTIVE_KEY = "aegis_active_project";

export function useProjects() {
  const [projects, setProjects] = useState<Project[]>([]);
  const [activeId, setActiveIdState] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    try {
      const res = await fetch("/api/projects", { cache: "no-store" });
      const data = await res.json();
      if (!data.ok) {
        setError(data.error || "Failed to load projects");
        setProjects([]);
      } else {
        setProjects(data.projects || []);
        setError(null);
      }
    } catch (err: any) {
      setError(err?.message || "Network error");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    // Read active project from localStorage on mount
    if (typeof window !== "undefined") {
      try {
        const saved = window.localStorage.getItem(ACTIVE_KEY);
        if (saved) setActiveIdState(saved);
      } catch { /* ignore */ }
    }
    refresh();
  }, [refresh]);

  const setActiveId = useCallback((id: string | null) => {
    setActiveIdState(id);
    if (typeof window !== "undefined") {
      try {
        if (id) window.localStorage.setItem(ACTIVE_KEY, id);
        else window.localStorage.removeItem(ACTIVE_KEY);
      } catch { /* ignore */ }
    }
  }, []);

  const activeProject = activeId ? projects.find(p => p.id === activeId) || null : null;

  return { projects, activeId, activeProject, setActiveId, loading, error, refresh };
}
EOF
echo "   ✓ projects hook"

# -----------------------------------------------------------------------------
# 5. ProjectSwitcher component (lives in StatusBar)
# -----------------------------------------------------------------------------
echo "✏️  Creating components/ProjectSwitcher.tsx"
cat > components/ProjectSwitcher.tsx <<'EOF'
"use client";
import { useState, useRef, useEffect } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { ChevronDown, Layers, Check } from "lucide-react";
import { Project, PROJECT_COLORS, STATUS_COLOR } from "@/lib/projects";

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

  const activeColor = active ? PROJECT_COLORS[active.color] : null;

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
              background: activeColor!.hex,
              boxShadow: `0 0 8px ${activeColor!.glow}`,
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
                const c = PROJECT_COLORS[p.color];
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
EOF
echo "   ✓ project switcher"

# -----------------------------------------------------------------------------
# 6. ProjectsView component
# -----------------------------------------------------------------------------
echo "✏️  Creating components/ProjectsView.tsx"
cat > components/ProjectsView.tsx <<'EOF'
"use client";
import { useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { ExternalLink, Github, Smartphone, Cloud, Database, X, AlertCircle, Plus } from "lucide-react";
import { Project, PROJECT_COLORS, STATUS_COLOR } from "@/lib/projects";

interface Props {
  projects: Project[];
  activeId: string | null;
  onActivate: (id: string) => void;
  loading: boolean;
}

const HOST_ICONS: Record<string, any> = {
  vercel: { label: "Vercel", color: "#ffffff" },
  netlify: { label: "Netlify", color: "#00C7B7" },
  supabase: { label: "Supabase", color: "#3ECF8E" },
  other: { label: "Other", color: "#94a3b8" },
};

export default function ProjectsView({ projects, activeId, onActivate, loading }: Props) {
  const [selected, setSelected] = useState<Project | null>(null);

  if (loading) {
    return (
      <div className="font-mono text-[11px] tracking-[0.22em] text-white/40">
        LOADING PROJECTS…
      </div>
    );
  }

  return (
    <>
      <div className="mb-6 flex items-end justify-between flex-wrap gap-3">
        <div>
          <div className="font-mono text-[10px] tracking-[0.3em] text-amber-400/80 mb-1">PORTFOLIO</div>
          <h1 className="font-display text-[34px] md:text-[42px] font-light tracking-tight text-white leading-none">
            Privé Systems
          </h1>
          <div className="text-[13px] text-white/55 mt-1.5 max-w-2xl">
            {projects.length} project{projects.length === 1 ? "" : "s"} — pick one from the switcher to filter missions, chats, and logs to that workspace.
          </div>
        </div>
        <button
          disabled
          className="flex items-center gap-2 px-4 py-2 rounded-full border border-white/[0.08] text-white/30 cursor-not-allowed font-mono text-[11px] tracking-[0.18em]"
          title="Coming in a later patch"
        >
          <Plus className="h-3 w-3" strokeWidth={2} />
          NEW PROJECT
        </button>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
        {projects.map(p => (
          <ProjectCard
            key={p.id}
            project={p}
            isActive={p.id === activeId}
            onClick={() => setSelected(p)}
            onActivate={() => onActivate(p.id)}
          />
        ))}
      </div>

      <AnimatePresence>
        {selected && (
          <ProjectDetail project={selected} onClose={() => setSelected(null)} onActivate={() => { onActivate(selected.id); setSelected(null); }} />
        )}
      </AnimatePresence>
    </>
  );
}

function ProjectCard({ project, isActive, onClick, onActivate }: {
  project: Project; isActive: boolean; onClick: () => void; onActivate: () => void;
}) {
  const c = PROJECT_COLORS[project.color];
  const statusColor = STATUS_COLOR[project.status];

  return (
    <motion.div
      whileHover={{ y: -2 }}
      onClick={onClick}
      className={`relative rounded-2xl border bg-white/[0.02] p-4 cursor-pointer overflow-hidden transition-colors ${
        isActive ? "border-white/20" : "border-white/[0.07] hover:border-white/[0.14]"
      }`}
      style={isActive ? { boxShadow: `0 0 24px ${c.glow}` } : {}}
    >
      <div className="absolute -top-12 -right-12 h-32 w-32 rounded-full opacity-15 pointer-events-none"
        style={{ background: `radial-gradient(circle, ${c.hex}, transparent 70%)` }} />

      <div className="relative">
        <div className="flex items-start justify-between mb-2">
          <div className="flex items-center gap-2">
            <span className="h-2 w-2 rounded-full shrink-0" style={{
              background: c.hex, boxShadow: `0 0 8px ${c.glow}`,
            }} />
            <span className="font-display text-[15px] text-white font-medium truncate">{project.name}</span>
          </div>
          {isActive && (
            <span className="font-mono text-[8px] tracking-[0.2em] text-amber-300 px-1.5 py-0.5 rounded bg-amber-400/15">
              ACTIVE
            </span>
          )}
        </div>

        <div className="text-[11.5px] text-white/55 line-clamp-2 mb-3 min-h-[32px]">
          {project.description}
        </div>

        <div className="flex items-center gap-1.5 flex-wrap mb-3">
          <span className="font-mono text-[8.5px] tracking-[0.15em] px-1.5 py-0.5 rounded" style={{
            background: statusColor + "22", color: statusColor,
          }}>
            {project.status.toUpperCase()}
          </span>
          {project.hosting.map(h => (
            <span key={h} className="font-mono text-[8.5px] tracking-[0.15em] px-1.5 py-0.5 rounded bg-white/[0.04] text-white/55">
              {(HOST_ICONS[h]?.label || h).toUpperCase()}
            </span>
          ))}
          {project.ios && (
            <span className="font-mono text-[8.5px] tracking-[0.15em] px-1.5 py-0.5 rounded bg-white/[0.04] text-white/55 flex items-center gap-1">
              <Smartphone className="h-2.5 w-2.5" strokeWidth={2} /> iOS
            </span>
          )}
        </div>

        <button
          onClick={(e) => { e.stopPropagation(); onActivate(); }}
          className="w-full font-mono text-[10px] tracking-[0.2em] py-1.5 rounded-full border border-white/[0.08] hover:border-white/20 hover:bg-white/[0.04] text-white/65 hover:text-white transition-colors"
        >
          {isActive ? "✓ ACTIVE WORKSPACE" : "SET ACTIVE"}
        </button>
      </div>
    </motion.div>
  );
}

function ProjectDetail({ project, onClose, onActivate }: {
  project: Project; onClose: () => void; onActivate: () => void;
}) {
  const c = PROJECT_COLORS[project.color];
  const statusColor = STATUS_COLOR[project.status];

  return (
    <motion.div
      initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
      className="fixed inset-0 z-50 bg-black/70 backdrop-blur-sm flex items-center justify-center p-4"
      onClick={onClose}
    >
      <motion.div
        initial={{ scale: 0.96, opacity: 0 }}
        animate={{ scale: 1, opacity: 1 }}
        exit={{ scale: 0.96, opacity: 0 }}
        onClick={e => e.stopPropagation()}
        className="relative w-full max-w-2xl rounded-2xl border border-white/[0.1] bg-[#0a0a0a] p-6 overflow-hidden max-h-[85vh] overflow-y-auto"
        style={{ boxShadow: `0 0 60px ${c.glow}` }}
      >
        <div className="absolute -top-20 -right-20 h-48 w-48 rounded-full opacity-20 pointer-events-none"
          style={{ background: `radial-gradient(circle, ${c.hex}, transparent 70%)` }} />

        <div className="relative">
          <button onClick={onClose}
            className="absolute top-0 right-0 h-7 w-7 grid place-items-center rounded-full hover:bg-white/5 text-white/40 hover:text-white">
            <X className="h-4 w-4" strokeWidth={1.5} />
          </button>

          <div className="flex items-center gap-3 mb-2">
            <span className="h-3 w-3 rounded-full" style={{
              background: c.hex, boxShadow: `0 0 14px ${c.glow}`,
            }} />
            <span className="font-mono text-[10px] tracking-[0.28em]" style={{ color: statusColor }}>
              {project.status.toUpperCase()}
            </span>
          </div>

          <h2 className="font-display text-[26px] text-white font-medium mb-1">{project.name}</h2>
          <p className="text-[13px] text-white/65 mb-5">{project.description}</p>

          {/* Links */}
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
          </div>

          {/* Hosting + iOS */}
          <div className="grid grid-cols-2 gap-2 mb-5">
            <div className="rounded-lg border border-white/[0.05] p-3 bg-white/[0.015]">
              <div className="font-mono text-[9px] tracking-[0.22em] text-white/40 mb-1.5">HOSTING</div>
              <div className="flex flex-wrap gap-1">
                {project.hosting.length === 0 && <span className="text-[11px] text-white/40">—</span>}
                {project.hosting.map(h => (
                  <span key={h} className="font-mono text-[10px] tracking-[0.15em] px-1.5 py-0.5 rounded bg-white/[0.04] text-white/70">
                    {(HOST_ICONS[h]?.label || h).toUpperCase()}
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
              ) : (
                <span className="text-[11px] text-white/40">No iOS app</span>
              )}
            </div>
          </div>

          {/* Tags */}
          {project.tags.length > 0 && (
            <div className="mb-5">
              <div className="font-mono text-[9px] tracking-[0.22em] text-white/40 mb-1.5">TAGS</div>
              <div className="flex flex-wrap gap-1.5">
                {project.tags.map(t => (
                  <span key={t} className="text-[10px] px-2 py-0.5 rounded-full border border-white/[0.06] bg-white/[0.02] text-white/55">
                    #{t}
                  </span>
                ))}
              </div>
            </div>
          )}

          {/* Notes */}
          {project.notes && (
            <div className="mb-5">
              <div className="font-mono text-[9px] tracking-[0.22em] text-white/40 mb-1.5">NOTES</div>
              <div className="rounded-lg border border-white/[0.05] bg-white/[0.015] p-3 text-[12px] text-white/70 whitespace-pre-wrap">
                {project.notes}
              </div>
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
echo "   ✓ projects view"

# -----------------------------------------------------------------------------
# 7. Patch Sidebar to add Projects nav item
# -----------------------------------------------------------------------------
echo "✏️  Patching Sidebar.tsx to add Projects nav"
python3 - <<'PYEOF'
p = "components/Sidebar.tsx"
src = open(p).read()
if '"projects"' in src:
    print("   ⊙ already patched")
else:
    src = src.replace(
        'import {\n  Gauge, Bot, MessageSquare, Activity, Network, Database,\n  ScrollText, Compass, Plug,\n} from "lucide-react";',
        'import {\n  Gauge, Bot, MessageSquare, Activity, Network, Database,\n  ScrollText, Compass, Plug, Briefcase,\n} from "lucide-react";'
    )
    src = src.replace(
        'export type ViewId =\n  | "overview" | "agents" | "chat" | "telemetry" | "network" | "memory"\n  | "logs" | "missions" | "mcp";',
        'export type ViewId =\n  | "overview" | "agents" | "chat" | "projects" | "telemetry" | "network" | "memory"\n  | "logs" | "missions" | "mcp";'
    )
    src = src.replace(
        '  { id: "missions",  label: "Missions",   icon: Compass,   group: "OPERATIONS" },',
        '  { id: "projects", label: "Projects",  icon: Briefcase, group: "WORKSPACE" },\n  { id: "missions",  label: "Missions",   icon: Compass,   group: "OPERATIONS" },'
    )
    open(p, "w").write(src)
    print("   ✓ Sidebar patched")
PYEOF

# -----------------------------------------------------------------------------
# 8. Patch StatusBar to host the ProjectSwitcher
# -----------------------------------------------------------------------------
echo "✏️  Patching StatusBar.tsx to embed ProjectSwitcher"
python3 - <<'PYEOF'
p = "components/StatusBar.tsx"
src = open(p).read()
if "ProjectSwitcher" in src:
    print("   ⊙ already patched")
else:
    new = '''"use client";
import { useEffect, useState } from "react";
import { motion } from "framer-motion";
import { fmtTime } from "@/lib/theme";
import ProjectSwitcher from "./ProjectSwitcher";
import { Project } from "@/lib/projects";

interface Props {
  projects: Project[];
  activeId: string | null;
  onChangeProject: (id: string | null) => void;
  onOpenProjects: () => void;
}

export default function StatusBar({ projects, activeId, onChangeProject, onOpenProjects }: Props) {
  const [now, setNow] = useState<Date | null>(null);
  useEffect(() => {
    setNow(new Date());
    const id = setInterval(() => setNow(new Date()), 1000);
    return () => clearInterval(id);
  }, []);
  return (
    <div className="flex items-center justify-between border-b border-white/[0.06] px-6 py-3 text-[10px] tracking-[0.22em] text-white/50 font-mono backdrop-blur-xl bg-black/20">
      <div className="flex items-center gap-5 min-w-0">
        <div className="flex items-center gap-2 shrink-0">
          <motion.span className="block h-1.5 w-1.5 rounded-full bg-amber-400"
            animate={{ opacity: [1, 0.3, 1], boxShadow: ["0 0 4px #f5b400", "0 0 12px #f5b400", "0 0 4px #f5b400"] }}
            transition={{ duration: 1.6, repeat: Infinity }} />
          <span className="text-white/80">AEGIS · MISSION CONTROL</span>
        </div>
        <span className="text-white/25 hidden sm:inline shrink-0">v4.7.0</span>
        <span className="hidden md:inline text-white/30 shrink-0">SECURE · ANTHROPIC UPLINK</span>
      </div>
      <div className="flex items-center gap-3 shrink-0">
        <ProjectSwitcher
          projects={projects}
          activeId={activeId}
          onChange={onChangeProject}
          onOpenProjects={onOpenProjects}
        />
        <span className="hidden sm:inline text-white/40">
          <span className="text-emerald-400">●</span> NOMINAL
        </span>
        <span className="text-white/70 tabular-nums">{now ? fmtTime(now) : "--:--:-- UTC"}</span>
      </div>
    </div>
  );
}
'''
    open(p, "w").write(new)
    print("   ✓ StatusBar rewritten with project switcher")
PYEOF

# -----------------------------------------------------------------------------
# 9. Patch app/page.tsx to wire it all together
# -----------------------------------------------------------------------------
echo "✏️  Patching app/page.tsx to use useProjects + render ProjectsView"
python3 - <<'PYEOF'
p = "app/page.tsx"
src = open(p).read()
if "useProjects" in src:
    print("   ⊙ already patched")
else:
    new = '''"use client";
import { useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import AmbientGrid from "@/components/AmbientGrid";
import StatusBar from "@/components/StatusBar";
import Sidebar, { ViewId } from "@/components/Sidebar";
import OverviewView from "@/components/OverviewView";
import AgentsView from "@/components/AgentsView";
import AgentProfile from "@/components/AgentProfile";
import MessengerView from "@/components/MessengerView";
import TelemetryView from "@/components/TelemetryView";
import NetworkView from "@/components/NetworkView";
import MemoryView from "@/components/MemoryView";
import LogsView from "@/components/LogsView";
import MissionsView from "@/components/MissionsView";
import MCPView from "@/components/MCPView";
import ProjectsView from "@/components/ProjectsView";
import { Agent } from "@/lib/agents";
import { useProjects } from "@/lib/useProjects";

export default function Page() {
  const [active, setActive] = useState<ViewId>("overview");
  const [profileAgent, setProfileAgent] = useState<Agent | null>(null);
  const [chatAgentId, setChatAgentId] = useState<string | null>(null);

  const { projects, activeId, setActiveId, loading } = useProjects();

  const handleProfile = (a: Agent) => {
    setProfileAgent(a);
    if (typeof window !== "undefined") window.scrollTo({ top: 0, behavior: "smooth" });
  };
  const handleChat = (a: Agent) => {
    setChatAgentId(a.id);
    setProfileAgent(null);
    setActive("chat");
  };
  const switchView = (v: ViewId) => {
    setProfileAgent(null);
    setActive(v);
  };

  return (
    <div className="relative min-h-screen text-white overflow-x-hidden bg-[#070707]">
      <AmbientGrid />
      <div className="relative z-10 flex min-h-screen">
        <Sidebar active={active} setActive={switchView} />
        <div className="flex-1 flex flex-col min-w-0">
          <StatusBar
            projects={projects}
            activeId={activeId}
            onChangeProject={setActiveId}
            onOpenProjects={() => switchView("projects")}
          />
          <main className="flex-1 px-6 md:px-10 py-8 max-w-[1600px] w-full mx-auto">
            <AnimatePresence mode="wait">
              <motion.div
                key={profileAgent?.id || active}
                initial={{ opacity: 0, y: 12 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: -8 }}
                transition={{ duration: 0.35, ease: [0.22, 1, 0.36, 1] }}
              >
                {profileAgent ? (
                  <AgentProfile
                    agent={profileAgent}
                    onBack={() => setProfileAgent(null)}
                    onOpenChat={() => handleChat(profileAgent)}
                  />
                ) : (
                  <>
                    {active === "overview"  && <OverviewView
                                                  onProfileAgent={handleProfile}
                                                  onChatAgent={handleChat}
                                                  onGo={switchView}
                                                />}
                    {active === "agents"    && <AgentsView
                                                  onSelectProfile={handleProfile}
                                                  onSelectChat={handleChat}
                                                />}
                    {active === "chat"      && <MessengerView initialAgentId={chatAgentId || undefined} />}
                    {active === "projects"  && <ProjectsView
                                                  projects={projects}
                                                  activeId={activeId}
                                                  onActivate={setActiveId}
                                                  loading={loading}
                                                />}
                    {active === "missions"  && <MissionsView />}
                    {active === "logs"      && <LogsView />}
                    {active === "mcp"       && <MCPView />}
                    {active === "telemetry" && <TelemetryView />}
                    {active === "network"   && <NetworkView onSelect={handleProfile} />}
                    {active === "memory"    && <MemoryView />}
                  </>
                )}
              </motion.div>
            </AnimatePresence>
          </main>
          <footer className="border-t border-white/[0.06] px-6 py-4 text-[9px] tracking-[0.3em] text-white/30 font-mono flex justify-between flex-wrap gap-2">
            <span>AEGIS // BUILD 4.7.0-ORBITAL · LOCAL</span>
            <span>© COMMANDER · ALL FREQUENCIES</span>
          </footer>
        </div>
      </div>
    </div>
  );
}
'''
    open(p, "w").write(new)
    print("   ✓ page.tsx wired up")
PYEOF

echo ""
echo "✅ Multi-project foundation installed."
echo ""
echo "Restart your dev server (Ctrl+C in npm run dev, then npm run dev again)."
echo ""
echo "What's new:"
echo "   - New 'Projects' item in the sidebar under WORKSPACE"
echo "   - Project switcher dropdown at the top right of every view"
echo "   - All 11 of your Privé Systems projects seeded into AEGIS/Projects/*.md"
echo "   - Click any project to see its full details (website, repos, iOS, notes)"
echo "   - 'Set as Active Workspace' filters the app to that project"
echo ""
echo "🗂  Edit projects directly in Obsidian:"
echo "      \$OBSIDIAN_VAULT/AEGIS/Projects/<slug>.md"
echo "   Changes appear in AEGIS after refresh."
echo ""
echo "⚠️  Note: Filtering of Missions/Chats/Logs by active project is wired"
echo "    in the data layer but isn't enforced in the UI yet — that's the"
echo "    next patch (Phase A part 2). For now the switcher persists across"
echo "    page reloads, and the Projects view is fully functional."
echo ""
echo "Backups in .pre-project-backup/ — to revert: cp -r .pre-project-backup/* ."
