#!/usr/bin/env bash
# apply-chat-persistence-patch.sh
# Persists each agent's chat as a rolling thread in the Obsidian vault:
#   AEGIS/Chats/<agent-id>.json  (source of truth, perfect reload)
#   AEGIS/Chats/<agent-id>.md    (readable transcript for Obsidian)
# Auto-loads on agent open; saves user msg on send + agent reply on completion.
set -e
if [ ! -f package.json ] || [ ! -d components ]; then
  echo "❌ Run from inside the aegis project directory."; exit 1
fi
echo "📦 Backing up to .pre-chatpersist-backup/"
mkdir -p .pre-chatpersist-backup/lib .pre-chatpersist-backup/components .pre-chatpersist-backup/app/api/claude
cp components/ChatView.tsx .pre-chatpersist-backup/components/
cp lib/agents.ts .pre-chatpersist-backup/lib/
cp app/api/claude/route.ts .pre-chatpersist-backup/app/api/claude/ 2>/dev/null || true

echo "✏️  Defensive: ensure AgentId is string-typed and attachments field exists"
python3 - <<'PYEOF'
import re
# widen AgentId so agent.id comparisons (e.g. gemini-08) typecheck
p = "lib/agents.ts"; src = open(p).read()
m = re.search(r'export type AgentId = "claude-prime"[^;]*;', src)
if m:
    src = src.replace(m.group(0), "export type AgentId = string; // validated at runtime", 1)
    print("   ✓ AgentId widened")
else:
    print("   ⊙ AgentId already string")
# widen color field too (so gblue/coral/etc are valid)
oc = '  color: "amber" | "cyan" | "violet" | "emerald" | "rose" | "sky";'
if oc in src:
    src = src.replace(oc, '  color: string; // key into COLOR_MAP', 1)
    print("   ✓ color widened")
else:
    print("   ⊙ color already string")
open(p, "w").write(src)
# ensure RequestBody has attachments (repairs latent upload-patch gap)
r = "app/api/claude/route.ts"
try:
    rsrc = open(r).read()
    if "body.attachments" in rsrc and "attachments?:" not in rsrc:
        rsrc = rsrc.replace("  activeProjectId?: string | null;\n}", "  activeProjectId?: string | null;\n  attachments?: any[];\n}", 1)
        open(r, "w").write(rsrc); print("   ✓ attachments field added to RequestBody")
    else:
        print("   ⊙ attachments field present or unused")
except FileNotFoundError:
    print("   ⊙ route.ts not found (skipped)")
PYEOF

echo "✏️  Creating lib/chatstore.ts"
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
TSEOF
echo "   ✓ lib/chatstore.ts created"

echo "✏️  Creating app/api/chats/[agentId]/route.ts"
mkdir -p "app/api/chats/[agentId]"
cat > "app/api/chats/[agentId]/route.ts" <<'TSEOF'
import { loadThread, saveThread, clearThread, StoredMsg } from "@/lib/chatstore";
import { getAgent } from "@/lib/agents";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET(_req: Request, { params }: { params: { agentId: string } }) {
  const messages = await loadThread(params.agentId);
  return new Response(JSON.stringify({ messages: messages || [] }), {
    headers: { "Content-Type": "application/json" },
  });
}

export async function POST(req: Request, { params }: { params: { agentId: string } }) {
  let body: { messages?: StoredMsg[] };
  try { body = await req.json(); } catch { return new Response(JSON.stringify({ error: "bad json" }), { status: 400 }); }
  const agent = getAgent(params.agentId);
  const name = agent?.name || params.agentId;
  const ok = await saveThread(params.agentId, name, body.messages || []);
  return new Response(JSON.stringify({ ok }), { headers: { "Content-Type": "application/json" } });
}

export async function DELETE(_req: Request, { params }: { params: { agentId: string } }) {
  const ok = await clearThread(params.agentId);
  return new Response(JSON.stringify({ ok }), { headers: { "Content-Type": "application/json" } });
}
TSEOF
echo "   ✓ chats API route created"

echo "✏️  Wiring persistence into components/ChatView.tsx"
python3 - <<'PYEOF'
p = "components/ChatView.tsx"
src = open(p).read()
if "persistThread" in src:
    print("   ⊙ already wired")
else:
    load_effect = '''
  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const res = await fetch(`/api/chats/${agent.id}`);
        const data = await res.json();
        if (cancelled) return;
        if (Array.isArray(data.messages) && data.messages.length > 0) {
          let n = 1;
          setMessages(data.messages.map((m: any) => ({
            id: n++, role: m.role, text: m.text, ts: new Date(m.ts || Date.now()),
          })));
          idCounter.current = n;
        } else {
          setMessages([{ id: 1, role: "assistant", text: agent.greeting, ts: new Date() }]);
          idCounter.current = 2;
        }
      } catch { /* offline or no vault */ }
    })();
    return () => { cancelled = true; };
  }, [agent.id]);

  const persistThread = async (msgs: Msg[]) => {
    try {
      await fetch(`/api/chats/${agent.id}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          messages: msgs
            .filter(m => m.text && m.text.trim().length > 0)
            .map(m => ({ role: m.role, text: m.text, ts: (m.ts instanceof Date ? m.ts.toISOString() : new Date().toISOString()) })),
        }),
      });
    } catch { /* best-effort */ }
  };

  const clearConversation = async () => {
    try { await fetch(`/api/chats/${agent.id}`, { method: "DELETE" }); } catch {}
    setMessages([{ id: 1, role: "assistant", text: agent.greeting, ts: new Date() }]);
    idCounter.current = 2;
  };
'''
    anchor = '''  useEffect(() => {
    inputRef.current?.focus();
  }, [agent.id]);'''
    src = src.replace(anchor, anchor + "\n" + load_effect, 1)

    old_finally = '''    } finally {
      setBusy(false);
    }
  };'''
    new_finally = '''    } finally {
      setBusy(false);
      setMessages(prev => { persistThread(prev); return prev; });
    }
  };'''
    src = src.replace(old_finally, new_finally, 1)
    open(p, "w").write(src)
    print("   ✓ ChatView: load-on-open, save-on-complete, clearConversation added")
PYEOF

echo "✏️  Adding clear-conversation button to chat header"
python3 - <<'PYEOF'
import re
p = "components/ChatView.tsx"
src = open(p).read()
if 'title="Clear conversation"' in src:
    print("   ⊙ button already present")
else:
    m = re.search(r'import \{([^}]*)\} from "lucide-react";', src)
    if m and "Trash2" not in m.group(1):
        src = src.replace(m.group(0), f'import {{{m.group(1).rstrip()}, Trash2}} from "lucide-react";', 1)
    anchor = '<span className="truncate">{agent.role}</span>'
    if anchor in src:
        btn = anchor + '''
            <button onClick={clearConversation} title="Clear conversation"
              className="ml-auto h-7 w-7 grid place-items-center rounded-full hover:bg-white/5 text-white/30 hover:text-white/70 transition-colors">
              <Trash2 className="h-3.5 w-3.5" strokeWidth={1.5} />
            </button>'''
        src = src.replace(anchor, btn, 1)
        open(p, "w").write(src)
        print("   ✓ clear button added to header")
    else:
        print("   ⊙ header anchor not found — clear still works via function, button skipped")
PYEOF

echo ""
echo "✅ Chat persistence installed."
echo "Restart:  aegis-control restart"
echo "Threads saved to AEGIS/Chats/<agent-id>.json (+ .md readable mirror), synced via iCloud."
echo "Trash icon in chat header clears that agent's thread."
echo "Backups in .pre-chatpersist-backup/ — revert: cp -r .pre-chatpersist-backup/* . && rm -f lib/chatstore.ts && rm -rf 'app/api/chats'"
