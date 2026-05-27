#!/usr/bin/env bash
# fix-chat-persistence-save.sh
# The chat-persistence SAVE never fired (persistThread defined, never called).
# This inserts a thread-save POST to /api/chats right next to the existing
# /api/vault archive save, reusing the same q + streamedText that block uses.
# It appends the new exchange to the saved thread so reload-on-open works.
set -e
if [ ! -f components/ChatView.tsx ]; then
  echo "❌ Run from inside the aegis project directory."; exit 1
fi
if [ ! -f app/api/chats/*/route.ts ] 2>/dev/null && [ ! -d "app/api/chats" ]; then
  echo "❌ chats API not found — apply apply-chat-persistence-patch.sh first."; exit 1
fi

echo "📦 Backing up to .pre-fixpersist-backup/"
mkdir -p .pre-fixpersist-backup/components .pre-fixpersist-backup/app/api/chats
cp components/ChatView.tsx .pre-fixpersist-backup/components/

python3 - <<'PYEOF'
p = "components/ChatView.tsx"
src = open(p).read()

# If a POST to /api/chats already exists in ChatView, we're done.
if '/api/chats/${agent.id}`, {' in src and 'method: "POST"' in src.split('/api/chats/${agent.id}`, {',1)[1][:200]:
    pass  # may already be wired; we still check the vault anchor below

anchor = "        }).catch(() => { /* vault save is best-effort */ });"
if anchor not in src:
    print("   ⚠ /api/vault anchor not found. This machine's ChatView differs.")
    print("     Aborting to avoid a bad edit — paste 'sed -n 250,290p components/ChatView.tsx' output.")
    raise SystemExit(1)

if "append: { userText: q, agentText: streamedText }" in src:
    print("   ⊙ thread-save POST already present — no change")
else:
    inject = anchor + '''
        // Persist resumable thread (append this exchange) for reload-on-open.
        fetch(`/api/chats/${agent.id}`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ append: { userText: q, agentText: streamedText } }),
        }).catch(() => { /* thread save best-effort */ });'''
    src = src.replace(anchor, inject, 1)
    open(p, "w").write(src)
    print("   ✓ thread-save POST inserted next to /api/vault save")
PYEOF

# Upgrade the chats API route to support {append:{userText,agentText}} by
# loading the existing thread, pushing the two messages, and saving.
echo "✏️  Upgrading chats API route to support append mode"
ROUTE=$(ls app/api/chats/*/route.ts 2>/dev/null | head -1)
python3 - "$ROUTE" <<'PYEOF'
import sys
p = sys.argv[1]
src = open(p).read()
if "append" in src:
    print("   ⊙ append mode already present")
else:
    # Replace the POST handler body to support append OR full-messages save.
    old = '''export async function POST(req: Request, { params }: { params: { agentId: string } }) {
  let body: { messages?: StoredMsg[] };
  try { body = await req.json(); } catch { return new Response(JSON.stringify({ error: "bad json" }), { status: 400 }); }
  const agent = getAgent(params.agentId);
  const name = agent?.name || params.agentId;
  const ok = await saveThread(params.agentId, name, body.messages || []);
  return new Response(JSON.stringify({ ok }), { headers: { "Content-Type": "application/json" } });
}'''
    new = '''export async function POST(req: Request, { params }: { params: { agentId: string } }) {
  let body: { messages?: StoredMsg[]; append?: { userText: string; agentText: string } };
  try { body = await req.json(); } catch { return new Response(JSON.stringify({ error: "bad json" }), { status: 400 }); }
  const agent = getAgent(params.agentId);
  const name = agent?.name || params.agentId;
  if (body.append) {
    const existing = (await loadThread(params.agentId)) || [];
    const now = new Date().toISOString();
    if (body.append.userText && body.append.userText.trim())
      existing.push({ role: "user", text: body.append.userText, ts: now });
    if (body.append.agentText && body.append.agentText.trim())
      existing.push({ role: "assistant", text: body.append.agentText, ts: now });
    const ok = await saveThread(params.agentId, name, existing);
    return new Response(JSON.stringify({ ok, count: existing.length }), { headers: { "Content-Type": "application/json" } });
  }
  const ok = await saveThread(params.agentId, name, body.messages || []);
  return new Response(JSON.stringify({ ok }), { headers: { "Content-Type": "application/json" } });
}'''
    if old in src:
        src = src.replace(old, new, 1)
        open(p, "w").write(src)
        print("   ✓ append mode added to chats API route")
    else:
        print("   ⚠ POST handler not in expected form; route not modified")
PYEOF

echo ""
echo "✅ Fix applied. Restart: aegis-control restart"
echo "   Test: message an agent, WAIT for the full reply, then refresh — it should persist."
echo "   Revert: cp -r .pre-fixpersist-backup/* ."
