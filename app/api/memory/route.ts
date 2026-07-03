import { promises as fs } from "fs";
import path from "path";
import matter from "gray-matter";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

function vaultRoot(): string | null {
  return process.env.OBSIDIAN_VAULT || null;
}
function aegisDir(root: string, ...p: string[]): string {
  return path.join(root, "AEGIS", ...p);
}

interface MemFile {
  name: string;
  kind: "brief" | "conversation" | "context" | "source" | "strategy" | "other";
  project?: string;
  path: string;
  size: number;
  updated: string; // ISO
}

// Recursively collect .md files under a dir, tagging kind + project.
async function collect(root: string): Promise<MemFile[]> {
  const out: MemFile[] = [];

  async function walk(dir: string, kind: MemFile["kind"], project?: string) {
    let entries: any[] = [];
    try { entries = await fs.readdir(dir, { withFileTypes: true }); } catch { return; }
    for (const e of entries) {
      const full = path.join(dir, e.name);
      if (e.isDirectory()) {
        // Projects/<id>/ subfolders: source-docs, strategies
        if (kind === "brief") {
          if (e.name === "source-docs") await walk(full, "source", project);
          else if (e.name === "strategies") await walk(full, "strategy", project);
          else await walk(full, kind, e.name);
        } else if (kind === "conversation") {
          await walk(full, "conversation", e.name); // Chats/<agent>/
        } else {
          await walk(full, kind, project);
        }
        continue;
      }
      if (!e.name.endsWith(".md")) continue;
      try {
        const st = await fs.stat(full);
        const proj = kind === "brief" && !project ? e.name.replace(/\.md$/, "") : project;
        out.push({
          name: e.name.replace(/\.md$/, ""),
          kind,
          project: proj,
          path: full,
          size: st.size,
          updated: st.mtime.toISOString(),
        });
      } catch {}
    }
  }

  await walk(aegisDir(root, "Projects"), "brief");
  await walk(aegisDir(root, "Chats"), "conversation");
  await walk(aegisDir(root, "Context"), "context");
  return out;
}

export async function GET(req: Request) {
  const root = vaultRoot();
  if (!root) {
    return Response.json({ ok: false, error: "OBSIDIAN_VAULT not set in .env.local" }, { status: 500 });
  }
  const url = new URL(req.url);
  const q = (url.searchParams.get("q") || "").trim().toLowerCase();

  let files: MemFile[];
  try { files = await collect(root); }
  catch (e: any) { return Response.json({ ok: false, error: String(e?.message || e) }, { status: 500 }); }

  // Search mode: scan file contents for the query, return matches + snippet.
  if (q) {
    const results: any[] = [];
    for (const f of files) {
      try {
        const raw = await fs.readFile(f.path, "utf8");
        const body = matter(raw).content || raw;
        const idx = body.toLowerCase().indexOf(q);
        if (idx >= 0) {
          const start = Math.max(0, idx - 60);
          const snippet = body.slice(start, idx + 120).replace(/\s+/g, " ").trim();
          results.push({ name: f.name, kind: f.kind, project: f.project, snippet, updated: f.updated });
        }
      } catch {}
    }
    results.sort((a, b) => (a.name > b.name ? 1 : -1));
    return Response.json({ ok: true, mode: "search", query: q, count: results.length, results: results.slice(0, 40) });
  }

  // Overview mode: stats + breakdown + recent.
  const byKind: Record<string, number> = {};
  let totalSize = 0;
  for (const f of files) { byKind[f.kind] = (byKind[f.kind] || 0) + 1; totalSize += f.size; }

  const recent = [...files]
    .sort((a, b) => (a.updated < b.updated ? 1 : -1))
    .slice(0, 8)
    .map(f => ({ name: f.name, kind: f.kind, project: f.project, updated: f.updated, size: f.size }));

  return Response.json({
    ok: true,
    mode: "overview",
    stats: {
      total: files.length,
      briefs: byKind["brief"] || 0,
      conversations: byKind["conversation"] || 0,
      context: byKind["context"] || 0,
      sources: byKind["source"] || 0,
      strategies: byKind["strategy"] || 0,
      totalSize,
    },
    recent,
  });
}
