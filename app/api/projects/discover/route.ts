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
