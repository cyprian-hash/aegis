#!/usr/bin/env bash
# apply-branding-patch.sh
#
# Builds on the multi-project foundation:
#  - Switches each project to its exact brand hex color
#  - Adds "PRIVÉ SYSTEMS" wordmark to the AEGIS top bar
#  - Adds a filesystem discovery API + button that finds local repo paths
#  - Adds "OPEN LOCAL FOLDER" button in project detail (when localPath is set)
#
# Run from inside the aegis project directory:
#   bash apply-branding-patch.sh

set -e

if [ ! -f package.json ] || [ ! -d components ]; then
  echo "❌ Run from inside the aegis project directory."
  exit 1
fi

if [ ! -f lib/projects.ts ]; then
  echo "❌ Run apply-multiproject-patch.sh first."
  exit 1
fi

echo "📦 Backing up to .pre-branding-backup/"
mkdir -p .pre-branding-backup/lib .pre-branding-backup/components .pre-branding-backup/app/api
cp lib/projects.ts                .pre-branding-backup/lib/ 2>/dev/null || true
cp components/StatusBar.tsx       .pre-branding-backup/components/ 2>/dev/null || true
cp components/ProjectSwitcher.tsx .pre-branding-backup/components/ 2>/dev/null || true
cp components/ProjectsView.tsx    .pre-branding-backup/components/ 2>/dev/null || true
cp -r app/api/projects            .pre-branding-backup/app/api/ 2>/dev/null || true

# -----------------------------------------------------------------------------
# 1. Rewrite lib/projects.ts — hex colors + localPath + brand-correct seeds
# -----------------------------------------------------------------------------
echo "✏️  Rewriting lib/projects.ts with brand hex colors"
cat > lib/projects.ts <<'EOF'
export type ProjectStatus = "live" | "building" | "idea" | "archived";
export type HostingProvider = "vercel" | "netlify" | "supabase" | "other";

export interface IosInfo {
  bundleId: string;
  verified: boolean;
}

export interface Project {
  id: string;
  name: string;
  description: string;
  website?: string;
  repos: string[];
  hosting: HostingProvider[];
  ios?: IosInfo;
  status: ProjectStatus;
  /** Hex color including the leading # — e.g. "#285ED2" */
  color: string;
  /** Optional secondary brand color, e.g. for paper / accent variants */
  colorAlt?: string;
  /** Absolute path on local filesystem if the code lives on this Mac */
  localPath?: string;
  tags: string[];
  notes?: string;
  createdAt?: string;
  updatedAt?: string;
}

/** Derive a glow + soft-fill from a base hex. */
export function colorTokens(hex: string): { hex: string; glow: string; soft: string } {
  const m = hex.replace("#", "").match(/^([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})$/i);
  if (!m) return { hex, glow: hex + "88", soft: hex + "14" };
  const [r, g, b] = [m[1], m[2], m[3]].map((v) => parseInt(v, 16));
  return {
    hex,
    glow: `rgba(${r},${g},${b},0.55)`,
    soft: `rgba(${r},${g},${b},0.08)`,
  };
}

export const STATUS_COLOR: Record<ProjectStatus, string> = {
  live: "#34d399",
  building: "#f5b400",
  idea: "#94a3b8",
  archived: "#64748b",
};

// Privé Systems portfolio with exact brand colors
export const SEED_PROJECTS: Project[] = [
  {
    id: "prive-systems",
    name: "Privé Systems Group",
    description: "Privately held multi-product technology group building scalable AI-driven platforms.",
    website: "https://privesystems.com",
    repos: ["cyprian-hash/prive-systems"],
    hosting: ["vercel"],
    status: "live",
    color: "#A8A29E", // stone-gray umbrella accent (derived from #0A0A0A ink / #F5F5F4 paper)
    colorAlt: "#F5F5F4",
    tags: ["umbrella", "holding"],
    notes: "Brand: Ink (#0A0A0A) on Paper (#F5F5F4). Stone-gray used in AEGIS for visibility on dark background.",
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
    color: "#285ED2", // --color-central-blue
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
    color: "#EDBB2F", // --color-aura-accent
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
    color: "#10B981", // --color-vault-green
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
    color: "#F59E0B", // --color-jetvan-accent
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
    color: "#00E888", // --color-apimonitor-accent
    tags: ["devops", "monitoring", "cost"],
    notes: "GitHub repo not yet created.",
  },
  {
    id: "netty-banks",
    name: "Netty Banks",
    description: "AI personal assistant engineered for dynamic task delegation.",
    website: "http://netty.pro/",
    repos: [],
    hosting: ["vercel"],
    status: "live",
    color: "#A855F7", // --color-netty-accent
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
    color: "#3B82F6", // --color-jetpedia-accent
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
    color: "#0088CC", // --color-yachtpedia-accent
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
    color: "#15803D", // --color-autopedia-accent
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
    color: "#A855F7", // single anchor color (purple) from the multi-stop brand gradient
    tags: ["audio", "cognitive", "ios"],
    notes: "Brand uses a multi-stop gradient (#285ED2 → #10B981 → #EDBB2F → #A855F7 → #F59E0B). Anchor purple chosen for UI fidelity. iOS bundle ID inferred — verify before relying on it.",
  },
];

export function slugify(s: string): string {
  return s.toLowerCase().replace(/[^a-z0-9-]+/g, "-").replace(/^-+|-+$/g, "");
}
EOF
echo "   ✓ projects.ts rewritten with brand hex colors"

# -----------------------------------------------------------------------------
# 2. Update projects API route to support color as a string + localPath
# -----------------------------------------------------------------------------
echo "✏️  Updating app/api/projects/route.ts to serialize new fields"
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
    createdAt: p.createdAt || new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  };
  if (p.colorAlt) fm.colorAlt = p.colorAlt;
  if (p.localPath) fm.localPath = p.localPath;
  if (p.ios) fm.ios = p.ios;
  if (p.tags && p.tags.length) fm.tags = p.tags;

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
      color: d.color || "#94a3b8",
      colorAlt: d.colorAlt || undefined,
      localPath: d.localPath || undefined,
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
  try { await fs.access(dir); } catch { return []; }
  const files = await fs.readdir(dir);
  const projects: Project[] = [];
  for (const f of files) {
    if (!f.endsWith(".md")) continue;
    if (f === "README.md") continue;
    try {
      const content = await fs.readFile(path.join(dir, f), "utf8");
      const p = markdownToProject(content, f.replace(/\.md$/, ""));
      if (p) projects.push(p);
    } catch { /* skip */ }
  }
  return projects;
}

async function seedIfEmpty(root: string): Promise<boolean> {
  const dir = projectsDir(root);
  await ensureDir(dir);
  const existing = await readAllProjects(root);
  if (existing.length > 0) return false;
  for (const p of SEED_PROJECTS) {
    await fs.writeFile(path.join(dir, `${p.id}.md`), projectToMarkdown(p), "utf8");
  }
  await fs.writeFile(
    path.join(dir, "README.md"),
    `# Projects\n\nAuto-managed by AEGIS. Edit YAML frontmatter to change project metadata.\n\n_Generated: ${new Date().toISOString()}_\n`,
    "utf8"
  );
  return true;
}

export async function GET() {
  const root = getVaultRoot();
  if (!root) {
    return new Response(JSON.stringify({
      ok: false, error: "OBSIDIAN_VAULT not set in .env.local", projects: [],
    }), { status: 500, headers: { "Content-Type": "application/json" } });
  }
  try {
    await seedIfEmpty(root);
    const projects = await readAllProjects(root);
    return new Response(JSON.stringify({ ok: true, projects }), {
      headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
    });
  } catch (err: any) {
    return new Response(JSON.stringify({
      ok: false, error: err?.message, projects: [],
    }), { status: 500, headers: { "Content-Type": "application/json" } });
  }
}

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

  // Load existing to preserve fields not in body
  const projects = await readAllProjects(root);
  const existing = projects.find(p => p.id === body.id);
  const project: Project = {
    id: body.id!,
    name: body.name!,
    description: body.description ?? existing?.description ?? "",
    website: body.website ?? existing?.website,
    repos: body.repos ?? existing?.repos ?? [],
    hosting: body.hosting ?? existing?.hosting ?? [],
    ios: body.ios ?? existing?.ios,
    status: body.status ?? existing?.status ?? "idea",
    color: body.color ?? existing?.color ?? "#94a3b8",
    colorAlt: body.colorAlt ?? existing?.colorAlt,
    localPath: body.localPath ?? existing?.localPath,
    tags: body.tags ?? existing?.tags ?? [],
    notes: body.notes ?? existing?.notes,
    createdAt: existing?.createdAt,
  };
  try {
    const dir = projectsDir(root);
    await ensureDir(dir);
    await fs.writeFile(path.join(dir, `${project.id}.md`), projectToMarkdown(project), "utf8");
    return new Response(JSON.stringify({ ok: true, project }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (err: any) {
    return new Response(JSON.stringify({ ok: false, error: err?.message }), { status: 500 });
  }
}
EOF
echo "   ✓ projects API supports color string + localPath"

# -----------------------------------------------------------------------------
# 3. New /api/projects/discover — scans filesystem for repo paths
# -----------------------------------------------------------------------------
echo "✏️  Creating app/api/projects/discover/route.ts"
mkdir -p app/api/projects/discover
cat > app/api/projects/discover/route.ts <<'EOF'
import { promises as fs } from "fs";
import path from "path";
import os from "os";
import matter from "gray-matter";
import { execSync } from "child_process";
import { Project } from "@/lib/projects";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const HOME = os.homedir();
// Common roots people keep code in. Limited depth + skipping node_modules etc.
const SEARCH_ROOTS = [HOME, path.join(HOME, "Desktop"), path.join(HOME, "Documents"),
  path.join(HOME, "projects"), path.join(HOME, "Developer"), path.join(HOME, "Code"),
  path.join(HOME, "repos")];
const SKIP = new Set(["node_modules", ".git", "Library", "Applications", "Pictures",
  "Movies", "Music", ".Trash", ".cache", ".npm", ".vscode", ".cursor",
  "Public", "iCloud", "Mobile Documents"]);

interface DiscoveredRepo {
  path: string;
  remoteUrl: string | null;
  repoSlug: string | null; // e.g. "cyprian-hash/jetpedia-app"
}

async function findGitRepos(root: string, maxDepth = 4): Promise<DiscoveredRepo[]> {
  const out: DiscoveredRepo[] = [];
  async function walk(dir: string, depth: number) {
    if (depth > maxDepth) return;
    let entries: any[] = [];
    try { entries = await fs.readdir(dir, { withFileTypes: true }); }
    catch { return; }
    for (const e of entries) {
      if (!e.isDirectory()) continue;
      if (SKIP.has(e.name) || e.name.startsWith(".")) continue;
      const full = path.join(dir, e.name);
      // is THIS dir a git repo?
      try {
        await fs.access(path.join(full, ".git"));
        let remoteUrl: string | null = null;
        try {
          remoteUrl = execSync("git -C " + JSON.stringify(full) + " config --get remote.origin.url", {
            encoding: "utf8", timeout: 1500,
          }).trim() || null;
        } catch { /* no remote */ }
        const repoSlug = remoteUrl ? extractRepoSlug(remoteUrl) : null;
        out.push({ path: full, remoteUrl, repoSlug });
        // don't descend into a repo
        continue;
      } catch { /* not a repo, keep walking */ }
      await walk(full, depth + 1);
    }
  }
  await walk(root, 0);
  return out;
}

function extractRepoSlug(url: string): string | null {
  // git@github.com:org/repo.git    -> org/repo
  // https://github.com/org/repo.git -> org/repo
  const m = url.match(/github\.com[:/]([^/]+)\/([^/]+?)(\.git)?$/);
  if (!m) return null;
  return `${m[1]}/${m[2]}`;
}

function projectsDir(root: string): string {
  return path.join(root, "AEGIS", "Projects");
}

async function readAllProjects(root: string): Promise<Project[]> {
  const dir = projectsDir(root);
  try { await fs.access(dir); } catch { return []; }
  const files = await fs.readdir(dir);
  const projects: Project[] = [];
  for (const f of files) {
    if (!f.endsWith(".md") || f === "README.md") continue;
    try {
      const parsed = matter(await fs.readFile(path.join(dir, f), "utf8"));
      const d = parsed.data;
      projects.push({
        id: d.id || f.replace(/\.md$/, ""),
        name: d.name,
        description: d.description,
        website: d.website,
        repos: d.repos || [],
        hosting: d.hosting || [],
        ios: d.ios,
        status: d.status,
        color: d.color || "#94a3b8",
        colorAlt: d.colorAlt,
        localPath: d.localPath,
        tags: d.tags || [],
        notes: parsed.content?.trim(),
        createdAt: d.createdAt,
      });
    } catch { /* skip */ }
  }
  return projects;
}

function projectToMarkdown(p: Project): string {
  const fm: any = {
    id: p.id, name: p.name, description: p.description,
    website: p.website || "", repos: p.repos, hosting: p.hosting,
    status: p.status, color: p.color,
    createdAt: p.createdAt || new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  };
  if (p.colorAlt) fm.colorAlt = p.colorAlt;
  if (p.localPath) fm.localPath = p.localPath;
  if (p.ios) fm.ios = p.ios;
  if (p.tags?.length) fm.tags = p.tags;
  const body = p.notes ? `\n## Notes\n\n${p.notes}\n` : `\n## Notes\n\n_No notes yet._\n`;
  return matter.stringify(`# ${p.name}\n\n${p.description}\n${body}`, fm);
}

export async function POST() {
  const root = process.env.OBSIDIAN_VAULT;
  if (!root) {
    return new Response(JSON.stringify({ ok: false, error: "OBSIDIAN_VAULT not set" }), { status: 500 });
  }

  // 1. Find every git repo under the common roots
  const discovered: DiscoveredRepo[] = [];
  const seenPaths = new Set<string>();
  for (const r of SEARCH_ROOTS) {
    try { await fs.access(r); } catch { continue; }
    const found = await findGitRepos(r);
    for (const f of found) {
      if (seenPaths.has(f.path)) continue;
      seenPaths.add(f.path);
      discovered.push(f);
    }
  }

  // 2. Match each project's repo names to a discovered local path
  const projects = await readAllProjects(root);
  const matches: { projectId: string; matchedRepo: string; localPath: string }[] = [];
  const updatedProjects: Project[] = [];

  for (const proj of projects) {
    let bestMatch: DiscoveredRepo | null = null;
    // Try by repo slug first (most reliable)
    for (const repo of proj.repos) {
      const found = discovered.find(d => d.repoSlug === repo);
      if (found) { bestMatch = found; break; }
    }
    // Fallback: try matching the project's slug or name against the folder basename
    if (!bestMatch) {
      const candidates = [proj.id, proj.id.replace(/-/g, ""),
        proj.name.toLowerCase().replace(/[^a-z0-9]+/g, "-")];
      bestMatch = discovered.find(d => candidates.includes(path.basename(d.path).toLowerCase())) || null;
    }

    if (bestMatch) {
      const updated = { ...proj, localPath: bestMatch.path };
      updatedProjects.push(updated);
      matches.push({
        projectId: proj.id,
        matchedRepo: bestMatch.repoSlug || path.basename(bestMatch.path),
        localPath: bestMatch.path,
      });
      // persist
      try {
        await fs.writeFile(path.join(projectsDir(root), `${proj.id}.md`), projectToMarkdown(updated), "utf8");
      } catch { /* skip on failure, still report */ }
    }
  }

  return new Response(JSON.stringify({
    ok: true,
    discoveredCount: discovered.length,
    matchCount: matches.length,
    matches,
    unmatchedCount: projects.length - matches.length,
  }), { headers: { "Content-Type": "application/json" } });
}
EOF
echo "   ✓ discovery API created"

# -----------------------------------------------------------------------------
# 4. New /api/projects/open — opens a folder in Finder
# -----------------------------------------------------------------------------
echo "✏️  Creating app/api/projects/open/route.ts"
mkdir -p app/api/projects/open
cat > app/api/projects/open/route.ts <<'EOF'
import { spawn } from "child_process";
import { promises as fs } from "fs";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function POST(req: Request) {
  let body: { path: string };
  try { body = await req.json(); }
  catch { return new Response(JSON.stringify({ ok: false, error: "Invalid JSON" }), { status: 400 }); }
  if (!body?.path) {
    return new Response(JSON.stringify({ ok: false, error: "path required" }), { status: 400 });
  }
  try {
    await fs.access(body.path);
  } catch {
    return new Response(JSON.stringify({
      ok: false, error: `Path doesn't exist: ${body.path}`,
    }), { status: 404 });
  }

  try {
    const proc = spawn("open", [body.path], { detached: true, stdio: "ignore" });
    proc.unref();
    return new Response(JSON.stringify({ ok: true, opened: body.path }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (err: any) {
    return new Response(JSON.stringify({ ok: false, error: err?.message }), { status: 500 });
  }
}
EOF
echo "   ✓ open-folder API created"

# -----------------------------------------------------------------------------
# 5. Rewrite ProjectSwitcher to use raw hex color
# -----------------------------------------------------------------------------
echo "✏️  Rewriting components/ProjectSwitcher.tsx for hex color support"
cat > components/ProjectSwitcher.tsx <<'EOF'
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
EOF
echo "   ✓ ProjectSwitcher now uses hex colors"

# -----------------------------------------------------------------------------
# 6. Rewrite ProjectsView for hex colors + discover button + open folder
# -----------------------------------------------------------------------------
echo "✏️  Rewriting components/ProjectsView.tsx"
cat > components/ProjectsView.tsx <<'EOF'
"use client";
import { useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import {
  ExternalLink, Github, Smartphone, X, AlertCircle, Plus,
  Search, FolderOpen, CheckCircle2,
} from "lucide-react";
import { Project, colorTokens, STATUS_COLOR } from "@/lib/projects";

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
        const lines = [
          `✓ Scanned ${data.discoveredCount} git repos`,
          `✓ Matched ${data.matchCount} project${data.matchCount === 1 ? "" : "s"}`,
        ];
        if (data.unmatchedCount) lines.push(`⊙ ${data.unmatchedCount} unmatched (edit in Obsidian)`);
        setDiscoveryReport(lines.join("  ·  "));
        onRefresh();
      } else {
        setDiscoveryReport("✗ " + (data.error || "Discovery failed"));
      }
    } catch (err: any) {
      setDiscoveryReport("✗ " + (err?.message || "Network error"));
    } finally {
      setDiscovering(false);
      setTimeout(() => setDiscoveryReport(null), 8000);
    }
  };

  if (loading) {
    return <div className="font-mono text-[11px] tracking-[0.22em] text-white/40">LOADING PROJECTS…</div>;
  }

  return (
    <>
      <div className="mb-6 flex items-end justify-between flex-wrap gap-3">
        <div>
          <div className="font-mono text-[10px] tracking-[0.3em] text-amber-400/80 mb-1">PORTFOLIO</div>
          <h1 className="font-display text-[34px] md:text-[42px] font-light tracking-tight text-white leading-none">
            Projects
          </h1>
          <div className="text-[13px] text-white/55 mt-1.5 max-w-2xl">
            {projects.length} project{projects.length === 1 ? "" : "s"} — pick one from the switcher to filter missions, chats, and logs to that workspace.
          </div>
        </div>
        <div className="flex items-center gap-2">
          <button
            onClick={runDiscovery}
            disabled={discovering}
            className="flex items-center gap-2 px-4 py-2 rounded-full border border-white/[0.08] hover:border-white/25 hover:bg-white/[0.04] font-mono text-[11px] tracking-[0.18em] text-white/70 hover:text-white disabled:opacity-50"
            title="Scan your Mac for local copies of these repos and update each project's path"
          >
            <Search className="h-3 w-3" strokeWidth={2} />
            {discovering ? "SCANNING…" : "DISCOVER PATHS"}
          </button>
          <button
            disabled
            className="flex items-center gap-2 px-4 py-2 rounded-full border border-white/[0.08] text-white/30 cursor-not-allowed font-mono text-[11px] tracking-[0.18em]"
            title="Coming in a later patch"
          >
            <Plus className="h-3 w-3" strokeWidth={2} />
            NEW PROJECT
          </button>
        </div>
      </div>

      {discoveryReport && (
        <motion.div initial={{ opacity: 0, y: -6 }} animate={{ opacity: 1, y: 0 }}
          className="mb-4 rounded-lg border border-emerald-400/30 bg-emerald-400/[0.06] px-3 py-2 font-mono text-[11px] text-emerald-300">
          {discoveryReport}
        </motion.div>
      )}

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
          <ProjectDetail project={selected}
            onClose={() => setSelected(null)}
            onActivate={() => { onActivate(selected.id); setSelected(null); }} />
        )}
      </AnimatePresence>
    </>
  );
}

function ProjectCard({ project, isActive, onClick, onActivate }: {
  project: Project; isActive: boolean; onClick: () => void; onActivate: () => void;
}) {
  const c = colorTokens(project.color);
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
          <div className="flex items-center gap-2 min-w-0">
            <span className="h-2 w-2 rounded-full shrink-0" style={{
              background: c.hex, boxShadow: `0 0 8px ${c.glow}`,
            }} />
            <span className="font-display text-[15px] text-white font-medium truncate">{project.name}</span>
          </div>
          {isActive && (
            <span className="font-mono text-[8px] tracking-[0.2em] text-amber-300 px-1.5 py-0.5 rounded bg-amber-400/15 shrink-0">
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
    } catch (err: any) {
      setOpenErr(err?.message || "Network error");
    }
  };

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
              <button onClick={openLocal}
                className="flex items-center gap-1.5 px-3 py-1.5 rounded-full border text-[11px]"
                style={{ borderColor: c.hex + "55", color: c.hex, background: c.soft }}>
                <FolderOpen className="h-3 w-3" strokeWidth={1.5} /> Open local folder
              </button>
            )}
          </div>

          {openErr && (
            <div className="mb-4 rounded-lg border border-rose-400/30 bg-rose-400/[0.06] px-3 py-2 font-mono text-[11px] text-rose-300">
              {openErr}
            </div>
          )}

          <div className="grid grid-cols-2 gap-2 mb-5">
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
              ) : (
                <span className="text-[11px] text-white/40">No iOS app</span>
              )}
            </div>
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
                  <span key={t} className="text-[10px] px-2 py-0.5 rounded-full border border-white/[0.06] bg-white/[0.02] text-white/55">
                    #{t}
                  </span>
                ))}
              </div>
            </div>
          )}

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
echo "   ✓ ProjectsView rewritten"

# -----------------------------------------------------------------------------
# 7. Patch StatusBar to add PRIVÉ SYSTEMS wordmark
# -----------------------------------------------------------------------------
echo "✏️  Patching StatusBar to add PRIVÉ SYSTEMS branding"
python3 - <<'PYEOF'
p = "components/StatusBar.tsx"
src = open(p).read()
if "PRIVÉ SYSTEMS" in src:
    print("   ⊙ already patched")
else:
    src = src.replace(
        '<span className="text-white/80">AEGIS · MISSION CONTROL</span>',
        '<span className="text-white/80">AEGIS · MISSION CONTROL</span>\n          <span className="hidden lg:inline text-white/30 font-mono tracking-[0.32em]" style={{ letterSpacing: "0.32em" }}>PRIVÉ SYSTEMS</span>',
        1
    )
    open(p, "w").write(src)
    print("   ✓ StatusBar shows PRIVÉ SYSTEMS in the top bar")
PYEOF

# -----------------------------------------------------------------------------
# 8. Patch app/page.tsx so ProjectsView gets onRefresh wired up
# -----------------------------------------------------------------------------
echo "✏️  Wiring onRefresh into ProjectsView in app/page.tsx"
python3 - <<'PYEOF'
p = "app/page.tsx"
src = open(p).read()
# Make sure refresh is destructured from useProjects
if "{ projects, activeId, setActiveId, loading }" in src:
    src = src.replace(
        "const { projects, activeId, setActiveId, loading } = useProjects();",
        "const { projects, activeId, setActiveId, loading, refresh } = useProjects();",
        1
    )
# Pass refresh prop into ProjectsView
src = src.replace(
    '''<ProjectsView
                                                  projects={projects}
                                                  activeId={activeId}
                                                  onActivate={setActiveId}
                                                  loading={loading}
                                                />''',
    '''<ProjectsView
                                                  projects={projects}
                                                  activeId={activeId}
                                                  onActivate={setActiveId}
                                                  onRefresh={refresh}
                                                  loading={loading}
                                                />''',
    1
)
open(p, "w").write(src)
print("   ✓ refresh wired into ProjectsView")
PYEOF

echo ""
echo "✅ Branding + path discovery installed."
echo ""
echo "⚠️  IMPORTANT: Your existing AEGIS/Projects/*.md files in Obsidian still have"
echo "    the old palette-key colors (amber/cyan/violet/etc.). Re-seed them by:"
echo ""
echo "    1. Restart npm run dev"
echo "    2. In Obsidian, delete the AEGIS/Projects/ folder OR delete individual"
echo "       project .md files you want to re-seed"
echo "    3. Reload AEGIS (or click 'Projects' in sidebar) — AEGIS sees empty"
echo "       folder and re-seeds from the new SEED_PROJECTS with brand hex colors"
echo ""
echo "    Alternative: open each .md file in Obsidian and manually change"
echo "       color: amber  →  color: \"#EDBB2F\"  (etc.)"
echo ""
echo "Restart npm run dev once you've handled the re-seed."
echo ""
echo "What's new:"
echo "   - All projects use exact brand hex colors"
echo "   - 'PRIVÉ SYSTEMS' wordmark in the top bar (visible on wide screens)"
echo "   - 'DISCOVER PATHS' button scans your Mac and fills in localPath"
echo "   - Project cards show a 'LOCAL' pill when the path is set"
echo "   - 'Open local folder' button in detail modal opens it in Finder"
echo ""
echo "Backups in .pre-branding-backup/ — to revert: cp -r .pre-branding-backup/* ."
