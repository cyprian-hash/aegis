import { promises as fs } from "fs";
import path from "path";

export interface StoredMsg {
  role: "user" | "assistant";
  text: string;
  ts: string;
}

function vaultRoot(): string | null {
  return process.env.OBSIDIAN_VAULT || null;
}
function chatsDir(root: string): string {
  return path.join(root, "AEGIS", "Chats");
}
function safeId(agentId: string): string {
  return agentId.replace(/[^a-zA-Z0-9_-]/g, "_");
}

export async function loadThread(agentId: string): Promise<StoredMsg[] | null> {
  const root = vaultRoot();
  if (!root) return null;
  const file = path.join(chatsDir(root), `${safeId(agentId)}.json`);
  try {
    const raw = await fs.readFile(file, "utf8");
    const parsed = JSON.parse(raw);
    if (Array.isArray(parsed)) return parsed as StoredMsg[];
    return null;
  } catch {
    return null;
  }
}

export async function saveThread(agentId: string, agentName: string, messages: StoredMsg[]): Promise<boolean> {
  const root = vaultRoot();
  if (!root) return false;
  const dir = chatsDir(root);
  await fs.mkdir(dir, { recursive: true });
  const sid = safeId(agentId);
  await fs.writeFile(path.join(dir, `${sid}.json`), JSON.stringify(messages, null, 2), "utf8");
  const lines: string[] = [`# Conversation — ${agentName}`, "", `_Rolling thread. Last updated ${new Date().toISOString()}._`, ""];
  for (const m of messages) {
    const who = m.role === "user" ? "You" : agentName;
    lines.push(`**${who}** · ${m.ts}`, "", m.text, "", "---", "");
  }
  await fs.writeFile(path.join(dir, `${sid}.md`), lines.join("\n"), "utf8");
  return true;
}

export async function clearThread(agentId: string): Promise<boolean> {
  const root = vaultRoot();
  if (!root) return false;
  const dir = chatsDir(root);
  const sid = safeId(agentId);
  try { await fs.writeFile(path.join(dir, `${sid}.json`), "[]", "utf8"); } catch {}
  try { await fs.writeFile(path.join(dir, `${sid}.md`), `# Conversation — ${agentId}\n\n_Cleared ${new Date().toISOString()}._\n`, "utf8"); } catch {}
  return true;
}
