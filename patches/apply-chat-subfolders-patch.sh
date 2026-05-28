#!/usr/bin/env bash
# apply-chat-subfolders-patch.sh
# Moves chat threads into per-agent subfolders:
#   OLD: AEGIS/Chats/<agent-id>.json + .md   (flat)
#   NEW: AEGIS/Chats/<agent-id>/thread.json + thread.md
# Migrates any existing flat files into the new subfolders so nothing is lost.
# Built/verified against the real repo.
set -e
if [ ! -f lib/chatstore.ts ]; then
  echo "❌ lib/chatstore.ts not found — apply chat persistence first."; exit 1
fi

echo "📦 Backing up to .pre-subfolder-backup/"
mkdir -p .pre-subfolder-backup/lib
cp lib/chatstore.ts .pre-subfolder-backup/lib/

echo "✏️  Rewriting lib/chatstore.ts for per-agent subfolders"
cat > lib/chatstore.ts <<'TSEOF'
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
function chatsRoot(root: string): string {
  return path.join(root, "AEGIS", "Chats");
}
function safeId(agentId: string): string {
  return agentId.replace(/[^a-zA-Z0-9_-]/g, "_");
}
function agentDir(root: string, agentId: string): string {
  return path.join(chatsRoot(root), safeId(agentId));
}

// Migrate a legacy flat file (Chats/<id>.json|md) into the agent subfolder, once.
async function migrateLegacy(root: string, agentId: string): Promise<void> {
  const sid = safeId(agentId);
  const dir = agentDir(root, agentId);
  for (const ext of ["json", "md"]) {
    const oldPath = path.join(chatsRoot(root), `${sid}.${ext}`);
    const newPath = path.join(dir, `thread.${ext}`);
    try {
      await fs.access(oldPath);
      // old file exists; only move if new one doesn't already exist
      try { await fs.access(newPath); } catch {
        await fs.mkdir(dir, { recursive: true });
        await fs.rename(oldPath, newPath);
      }
    } catch { /* no legacy file */ }
  }
}

export async function loadThread(agentId: string): Promise<StoredMsg[] | null> {
  const root = vaultRoot();
  if (!root) return null;
  await migrateLegacy(root, agentId);
  const file = path.join(agentDir(root, agentId), "thread.json");
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
  const dir = agentDir(root, agentId);
  await fs.mkdir(dir, { recursive: true });
  await fs.writeFile(path.join(dir, "thread.json"), JSON.stringify(messages, null, 2), "utf8");
  const lines: string[] = [`# Conversation — ${agentName}`, "", `_Rolling thread. Last updated ${new Date().toISOString()}._`, ""];
  for (const m of messages) {
    const who = m.role === "user" ? "You" : agentName;
    lines.push(`**${who}** · ${m.ts}`, "", m.text, "", "---", "");
  }
  await fs.writeFile(path.join(dir, "thread.md"), lines.join("\n"), "utf8");
  return true;
}

export async function clearThread(agentId: string): Promise<boolean> {
  const root = vaultRoot();
  if (!root) return false;
  const dir = agentDir(root, agentId);
  await fs.mkdir(dir, { recursive: true });
  try { await fs.writeFile(path.join(dir, "thread.json"), "[]", "utf8"); } catch {}
  try { await fs.writeFile(path.join(dir, "thread.md"), `# Conversation — ${agentId}\n\n_Cleared ${new Date().toISOString()}._\n`, "utf8"); } catch {}
  return true;
}
TSEOF
echo "   ✓ chatstore.ts now uses AEGIS/Chats/<agent-id>/thread.json + thread.md"
echo "   ✓ legacy flat files auto-migrate into subfolders on first load"

echo ""
echo "✅ Per-agent chat subfolders enabled."
echo "Restart:  aegis-control restart"
echo "Existing threads migrate automatically the first time each agent is opened."
echo "Backups in .pre-subfolder-backup/ — revert: cp -r .pre-subfolder-backup/* ."
