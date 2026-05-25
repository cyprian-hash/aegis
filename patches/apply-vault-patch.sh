#!/bin/bash
# apply-vault-patch.sh
#
# Wires AEGIS chats + missions to auto-save into your Obsidian vault.
# Uses direct filesystem writes (Option A) — no Obsidian plugins required.
#
# Run from the aegis project directory:
#   cd ~/projects/aegis && bash apply-vault-patch.sh

set -e

if [ ! -f package.json ] || [ ! -d components ]; then
  echo "❌ Run this from inside the aegis project directory."
  exit 1
fi

VAULT_PATH="/Users/cypmacmini/Library/Mobile Documents/iCloud~md~obsidian/Documents/cyp vault"
if [ ! -d "$VAULT_PATH" ]; then
  echo "⚠️  Could not find vault at: $VAULT_PATH"
  echo "    Patch will still install — adjust OBSIDIAN_VAULT in .env.local if path differs."
fi

echo "📦 Backing up files to .pre-vault-backup/"
mkdir -p .pre-vault-backup/components .pre-vault-backup/app/api
cp components/ChatView.tsx     .pre-vault-backup/components/
cp components/MissionsView.tsx .pre-vault-backup/components/
cp .env.local                  .pre-vault-backup/ 2>/dev/null || true
cp .env.local.example          .pre-vault-backup/ 2>/dev/null || true

echo "✏️  Creating app/api/vault/route.ts"
mkdir -p app/api/vault
cat > app/api/vault/route.ts <<'EOF'
import { promises as fs } from "fs";
import path from "path";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

interface VaultRequest {
  kind: "chat" | "mission";
  // For chats: append a user/assistant exchange to today's per-agent daily file
  agentId?: string;
  agentName?: string;
  userText?: string;
  agentText?: string;
  // For missions: write/overwrite a mission file
  missionId?: string;
  missionContent?: string;
}

function getVaultRoot(): string | null {
  const p = process.env.OBSIDIAN_VAULT;
  if (!p) return null;
  return p;
}

async function ensureDir(dir: string) {
  await fs.mkdir(dir, { recursive: true });
}

async function ensureReadme(aegisFolder: string) {
  const readme = path.join(aegisFolder, "README.md");
  try {
    await fs.access(readme);
  } catch {
    const body = `# AEGIS

This folder is auto-populated by [AEGIS Mission Control](http://localhost:3000).

## Layout

- \`Chats/\` — one Markdown file per agent per day. Conversations append to the day's file.
- \`Missions/\` — one Markdown file per mission, updated when the mission's status changes.

Files are plain Markdown — edit, link, or backlink freely. AEGIS will only ever *append* to chat files and *overwrite* mission files when they update.

_Generated: ${new Date().toISOString()}_
`;
    await fs.writeFile(readme, body, "utf8");
  }
}

function todayStamp(): string {
  // YYYY-MM-DD in local time
  const d = new Date();
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${y}-${m}-${day}`;
}

function timeStamp(): string {
  const d = new Date();
  return d.toLocaleTimeString("en-US", { hour12: false });
}

function safeSlug(s: string): string {
  return s
    .toLowerCase()
    .replace(/[^a-z0-9-]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 60) || "untitled";
}

export async function POST(req: Request) {
  const root = getVaultRoot();
  if (!root) {
    return new Response(
      JSON.stringify({ ok: false, error: "OBSIDIAN_VAULT not set in .env.local" }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }

  let body: VaultRequest;
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ ok: false, error: "Invalid JSON" }), { status: 400 });
  }

  const aegisFolder = path.join(root, "AEGIS");
  await ensureDir(aegisFolder);
  await ensureReadme(aegisFolder);

  try {
    if (body.kind === "chat") {
      if (!body.agentId || !body.agentName) {
        return new Response(JSON.stringify({ ok: false, error: "agentId and agentName required for chat" }), { status: 400 });
      }
      const chatsDir = path.join(aegisFolder, "Chats");
      await ensureDir(chatsDir);
      const file = path.join(chatsDir, `${todayStamp()}-${safeSlug(body.agentId)}.md`);

      // If file doesn't exist, write a header first
      let exists = true;
      try { await fs.access(file); } catch { exists = false; }
      if (!exists) {
        const header =
`---
date: ${todayStamp()}
agent: ${body.agentName}
agent_id: ${body.agentId}
type: aegis-chat
tags: [aegis, chat, ${safeSlug(body.agentId)}]
---

# ${body.agentName} — ${todayStamp()}

`;
        await fs.writeFile(file, header, "utf8");
      }

      const entry =
`## ${timeStamp()}

**Commander:** ${body.userText || ""}

**${body.agentName}:** ${body.agentText || ""}

---

`;
      await fs.appendFile(file, entry, "utf8");
      return new Response(JSON.stringify({ ok: true, file }), { headers: { "Content-Type": "application/json" } });
    }

    if (body.kind === "mission") {
      if (!body.missionId || !body.missionContent) {
        return new Response(JSON.stringify({ ok: false, error: "missionId and missionContent required" }), { status: 400 });
      }
      const missionsDir = path.join(aegisFolder, "Missions");
      await ensureDir(missionsDir);
      const file = path.join(missionsDir, `${safeSlug(body.missionId)}.md`);
      await fs.writeFile(file, body.missionContent, "utf8");
      return new Response(JSON.stringify({ ok: true, file }), { headers: { "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ ok: false, error: "Unknown kind" }), { status: 400 });
  } catch (err: any) {
    return new Response(
      JSON.stringify({ ok: false, error: err?.message || "Write failed" }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
}
EOF
echo "   ✓ vault API route created"

echo "✏️  Patching components/ChatView.tsx to save each exchange"
python3 - <<'PYEOF'
p = "components/ChatView.tsx"
src = open(p).read()

if "/api/vault" in src:
    print("   ⊙ already patched")
else:
    # 1. Introduce a local accumulator `streamedText` right after assistantId is created
    src = src.replace(
        "    const assistantId = idCounter.current++;\n    setMessages(prev => [...prev, { id: assistantId, role: \"assistant\", text: \"\", ts: new Date() }]);",
        "    const assistantId = idCounter.current++;\n    let streamedText = \"\";\n    setMessages(prev => [...prev, { id: assistantId, role: \"assistant\", text: \"\", ts: new Date() }]);",
        1
    )

    # 2. Append to streamedText whenever we get a delta
    src = src.replace(
        "            if (event === \"delta\" && parsed.text) {\n              setMessages(prev => prev.map(m =>\n                m.id === assistantId ? { ...m, text: m.text + parsed.text } : m\n              ));\n            }",
        "            if (event === \"delta\" && parsed.text) {\n              streamedText += parsed.text;\n              setMessages(prev => prev.map(m =>\n                m.id === assistantId ? { ...m, text: m.text + parsed.text } : m\n              ));\n            }",
        1
    )

    # 3. Inject vault save in the finally block
    old = """    } finally {
      setBusy(false);
    }
  };"""
    new = """    } finally {
      setBusy(false);
      // Auto-save the exchange to the Obsidian vault (fire-and-forget, only if we got a response)
      if (streamedText.trim()) {
        fetch("/api/vault", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            kind: "chat",
            agentId: agent.id,
            agentName: agent.name,
            userText: q,
            agentText: streamedText,
          }),
        }).catch(() => { /* vault save is best-effort */ });
      }
    }
  };"""
    src = src.replace(old, new, 1)

    open(p, "w").write(src)
    print("   ✓ ChatView saves each exchange to vault")
PYEOF

echo "✏️  Patching components/MissionsView.tsx to save mission notes"
python3 - <<'PYEOF'
p = "components/MissionsView.tsx"
src = open(p).read()

if "/api/vault" in src:
    print("   ⊙ already patched")
else:
    # Insert helper after imports
    helper = '''
function saveMissionToVault(m: Mission) {
  const agents = m.agentIds.map(id => AGENTS.find(a => a.id === id)?.name || id).join(", ");
  const stepLines = m.steps.map(s => `- [${s.done ? "x" : " "}] ${s.label}`).join("\\n");
  const content = `---
mission_id: ${m.id}
status: ${m.status}
priority: ${m.priority}
progress: ${m.progress}
agents: [${m.agentIds.join(", ")}]
type: aegis-mission
tags: [aegis, mission, ${m.status}, ${m.priority.toLowerCase()}]
---

# ${m.id} — ${m.title}

**Status:** ${m.status.toUpperCase()} · **Priority:** ${m.priority} · **Progress:** ${m.progress}%

**Assigned:** ${agents}

## Brief

${m.brief}

## Steps

${stepLines}

---
_Last updated by AEGIS at ${new Date().toLocaleString()}_
`;
  fetch("/api/vault", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ kind: "mission", missionId: m.id, missionContent: content }),
  }).catch(() => { /* vault save is best-effort */ });
}

'''
    src = src.replace(
        'const PRIORITY_COLOR: Record<Priority, keyof typeof COLOR_MAP> = {',
        helper + 'const PRIORITY_COLOR: Record<Priority, keyof typeof COLOR_MAP> = {',
        1
    )

    # Call saveMissionToVault inside advance() — after the setMissions(...) call
    old_advance = """  const advance = (id: string) => {
    setMissions(prev => prev.map(m => {
      if (m.id !== id) return m;
      const order: Status[] = ["queued", "active", "review", "complete"];
      const next = order[Math.min(order.length - 1, order.indexOf(m.status) + 1)];
      return { ...m, status: next, progress: next === "complete" ? 100 : Math.max(m.progress, 25) };
    }));
    if (selected?.id === id) {
      setSelected(s => s ? { ...s, status: s.status === "complete" ? s.status : "active" } : null);
    }
  };"""
    new_advance = """  const advance = (id: string) => {
    setMissions(prev => {
      const next = prev.map(m => {
        if (m.id !== id) return m;
        const order: Status[] = ["queued", "active", "review", "complete"];
        const nextStatus = order[Math.min(order.length - 1, order.indexOf(m.status) + 1)];
        return { ...m, status: nextStatus, progress: nextStatus === "complete" ? 100 : Math.max(m.progress, 25) };
      });
      const updated = next.find(m => m.id === id);
      if (updated) saveMissionToVault(updated);
      return next;
    });
    if (selected?.id === id) {
      setSelected(s => s ? { ...s, status: s.status === "complete" ? s.status : "active" } : null);
    }
  };"""
    src = src.replace(old_advance, new_advance, 1)

    # And inside NewMissionModal's onCreate callback, save right after creation
    old_create = """onCreate={(m) => { setMissions(prev => [m, ...prev]); setShowNew(false); }}"""
    new_create = """onCreate={(m) => { setMissions(prev => [m, ...prev]); saveMissionToVault(m); setShowNew(false); }}"""
    src = src.replace(old_create, new_create, 1)

    open(p, "w").write(src)
    print("   ✓ MissionsView writes new + advanced missions to vault")
PYEOF

echo "✏️  Adding OBSIDIAN_VAULT to .env.local.example and .env.local"
VAULT_LINE='OBSIDIAN_VAULT=/Users/cypmacmini/Library/Mobile Documents/iCloud~md~obsidian/Documents/cyp vault'
for FILE in .env.local.example .env.local; do
  if [ -f "$FILE" ] && ! grep -q "OBSIDIAN_VAULT" "$FILE"; then
    {
      echo ""
      echo "# Obsidian vault auto-save (path to vault folder, the one containing .obsidian/)"
      echo "$VAULT_LINE"
    } >> "$FILE"
    echo "   ✓ $FILE"
  elif grep -q "OBSIDIAN_VAULT" "$FILE" 2>/dev/null; then
    echo "   ⊙ $FILE already has OBSIDIAN_VAULT, skipped"
  fi
done

echo ""
echo "✅ Obsidian vault auto-save wired in."
echo ""
echo "Restart your dev server (Ctrl+C in the npm run dev tab, then npm run dev)."
echo ""
echo "What happens now:"
echo "   - Every chat exchange (Prime, Scout, Hermes, etc.) appends to:"
echo "     AEGIS/Chats/YYYY-MM-DD-<agent>.md"
echo "   - Every new mission and status advance writes:"
echo "     AEGIS/Missions/M-XXXX.md"
echo "   - An AEGIS/README.md is created on first write to document the layout."
echo ""
echo "Test it: open AEGIS, chat with any agent, then open your Obsidian vault."
echo "You should see a new AEGIS/ folder appear after the first message."
echo ""
echo "Backups in .pre-vault-backup/ — to revert: cp -r .pre-vault-backup/* ."
