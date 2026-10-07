import { promises as fs } from "fs";
import path from "path";
import matter from "gray-matter";

export interface Decision {
  id: string;
  title: string;
  body: string;
  source: string;        // routine name or agent name
  agentId?: string;      // for jump-to-chat
  status: "open" | "resolved" | "dismissed";
  createdAt: string;
  closedAt?: string;
}

function vaultRoot(): string | null {
  return process.env.OBSIDIAN_VAULT || null;
}
function decisionsDir(root: string): string {
  return path.join(root, "AEGIS", "Decisions");
}
function slug(s: string): string {
  return s.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "").slice(0, 48) || "decision";
}

export async function listDecisions(): Promise<Decision[]> {
  const root = vaultRoot();
  if (!root) return [];
  const dir = decisionsDir(root);
  let files: string[] = [];
  try { files = (await fs.readdir(dir)).filter(f => f.endsWith(".md")); } catch { return []; }
  const out: Decision[] = [];
  for (const f of files) {
    try {
      const parsed = matter(await fs.readFile(path.join(dir, f), "utf8"));
      const d = parsed.data as Partial<Decision>;
      if (!d.id || !d.title) continue;
      out.push({
        id: d.id, title: d.title, body: (parsed.content || "").trim(),
        source: d.source || "unknown", agentId: d.agentId,
        status: (d.status as Decision["status"]) || "open",
        createdAt: d.createdAt || "", closedAt: d.closedAt,
      });
    } catch {}
  }
  out.sort((a, b) => (a.createdAt < b.createdAt ? 1 : -1));
  return out;
}

export async function createDecision(input: { title: string; body: string; source: string; agentId?: string }): Promise<Decision | null> {
  const root = vaultRoot();
  if (!root) return null;
  const dir = decisionsDir(root);
  await fs.mkdir(dir, { recursive: true });
  const createdAt = new Date().toISOString();
  const id = `${createdAt.slice(0, 10)}-${Date.now() % 100000}-${slug(input.title)}`;
  const fm: Record<string, unknown> = {
    id, title: input.title, source: input.source, status: "open", createdAt,
  };
  if (input.agentId) fm.agentId = input.agentId;
  const md = matter.stringify(`\n${input.body.trim()}\n`, fm);
  await fs.writeFile(path.join(dir, `${id}.md`), md, "utf8");
  return { id, title: input.title, body: input.body.trim(), source: input.source, agentId: input.agentId, status: "open", createdAt };
}

export async function setDecisionStatus(id: string, status: "resolved" | "dismissed" | "open"): Promise<boolean> {
  const root = vaultRoot();
  if (!root) return false;
  const file = path.join(decisionsDir(root), `${id}.md`);
  try {
    const parsed = matter(await fs.readFile(file, "utf8"));
    parsed.data.status = status;
    if (status === "open") delete parsed.data.closedAt;
    else parsed.data.closedAt = new Date().toISOString();
    await fs.writeFile(file, matter.stringify(parsed.content, parsed.data), "utf8");
    return true;
  } catch { return false; }
}
