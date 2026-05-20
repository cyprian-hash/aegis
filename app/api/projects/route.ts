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
  if (p.email) fm.email = p.email;
  if (p.emailProvider) fm.emailProvider = p.emailProvider;
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
      email: d.email || undefined,
      emailProvider: d.emailProvider || undefined,
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
    email: body.email ?? existing?.email,
    emailProvider: body.emailProvider ?? existing?.emailProvider,
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
