import { promises as fs } from "fs";
import path from "path";
import matter from "gray-matter";

const MAX_CONTEXT_CHARS = 8000; // safety cap so prompts don't balloon

function vaultRoot(): string | null {
  return process.env.OBSIDIAN_VAULT || null;
}

/** Read the global context files (about-me, business, voice-and-style). */
export async function loadGlobalContext(): Promise<string> {
  const root = vaultRoot();
  if (!root) return "";
  const dir = path.join(root, "AEGIS", "Context");
  const files = ["about-me.md", "business.md", "voice-and-style.md"];
  const parts: string[] = [];
  for (const f of files) {
    try {
      const raw = await fs.readFile(path.join(dir, f), "utf8");
      // strip frontmatter if any, keep body
      const body = matter(raw).content.trim();
      if (body) parts.push(body);
    } catch { /* file may not exist; skip */ }
  }
  let joined = parts.join("\n\n---\n\n");
  if (joined.length > MAX_CONTEXT_CHARS) joined = joined.slice(0, MAX_CONTEXT_CHARS) + "\n…(truncated)";
  return joined;
}

/** Read a single project's useful fields for context. */
export async function loadProjectContext(projectId: string): Promise<string> {
  const root = vaultRoot();
  if (!root || !projectId) return "";
  const file = path.join(root, "AEGIS", "Projects", `${projectId}.md`);
  try {
    const raw = await fs.readFile(file, "utf8");
    const parsed = matter(raw);
    const d = parsed.data;
    const lines: string[] = [];
    if (d.name) lines.push(`Active project: ${d.name}`);
    if (d.description) lines.push(`Description: ${d.description}`);
    if (d.status) lines.push(`Status: ${d.status}`);
    if (d.website) lines.push(`Website: ${d.website}`);
    if (Array.isArray(d.tags) && d.tags.length) lines.push(`Tags: ${d.tags.join(", ")}`);
    const notes = (parsed.content || "").trim();
    if (notes) lines.push(`Notes:\n${notes}`);
    let out = lines.join("\n");
    if (out.length > MAX_CONTEXT_CHARS) out = out.slice(0, MAX_CONTEXT_CHARS) + "\n…(truncated)";
    return out;
  } catch {
    return "";
  }
}

/** Compose the full context block to prepend to a system prompt. */
export async function buildContextBlock(activeProjectId?: string | null): Promise<string> {
  const global = await loadGlobalContext();
  const project = activeProjectId ? await loadProjectContext(activeProjectId) : "";
  const blocks: string[] = [];
  if (global) blocks.push("## Operator & business context\n\n" + global);
  if (project) blocks.push("## Active project context\n\n" + project);
  if (blocks.length === 0) return "";
  return (
    "The following is persistent context about the operator you are assisting. " +
    "Use it to inform your responses without restating it verbatim.\n\n" +
    blocks.join("\n\n")
  );
}
