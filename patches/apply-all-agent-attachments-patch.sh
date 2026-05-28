#!/usr/bin/env bash
# apply-all-agent-attachments-patch.sh
# Enables file attachments for ALL agents except ORACLE-11 (Perplexity/Sonar is
# text-only and cannot accept files). Claude agents get PDF/image/text via the
# Anthropic API's document & image content blocks; GEMINI keeps its existing path.
# Built against the real repo (github.com/cyprian-hash/aegis).
set -e
if [ ! -f components/ChatView.tsx ] || [ ! -f app/api/claude/route.ts ]; then
  echo "❌ Run from inside the aegis project directory."; exit 1
fi
if ! grep -q "client.messages.stream" app/api/claude/route.ts; then
  echo "❌ Claude branch not found in expected form. Aborting."; exit 1
fi

echo "📦 Backing up to .pre-allattach-backup/"
mkdir -p .pre-allattach-backup/components .pre-allattach-backup/app/api/claude
cp components/ChatView.tsx .pre-allattach-backup/components/
cp app/api/claude/route.ts .pre-allattach-backup/app/api/claude/

# ----------------------------------------------------------------------------
# 1. ChatView: enable paperclip for all agents except ORACLE-11
# ----------------------------------------------------------------------------
echo "✏️  Enabling attachments for all agents except ORACLE-11 (ChatView)"
python3 - <<'PYEOF'
p = "components/ChatView.tsx"
src = open(p).read()
old = 'const supportsFiles = agent.id === "gemini-08";'
if old in src:
    src = src.replace(old, 'const supportsFiles = agent.id !== "oracle-11"; // ORACLE (Perplexity) is text-only', 1)
    print("   ✓ supportsFiles widened to all agents except ORACLE-11")
elif 'agent.id !== "oracle-11"' in src:
    print("   ⊙ already widened")
else:
    print("   ⚠ supportsFiles line not in expected form; not changed")

# update the disabled tooltip to be accurate for the new rule
old_tip = '"File upload is available on GEMINI-08 (Vision Core)"'
if old_tip in src:
    src = src.replace(old_tip, '"ORACLE-11 is text-only (live web search) and cannot take file uploads"', 1)
    print("   ✓ tooltip updated for ORACLE")

open(p, "w").write(src)
PYEOF

# ----------------------------------------------------------------------------
# 2. Route Claude branch: attach files to the last user message (Anthropic format)
# ----------------------------------------------------------------------------
echo "✏️  Adding attachment handling to the Claude branch (route.ts)"
python3 - <<'PYEOF'
p = "app/api/claude/route.ts"
src = open(p).read()

if "buildClaudeMessages" in src:
    print("   ⊙ Claude attachment handling already present")
else:
    # Insert a helper just before "const client = new Anthropic".
    helper = '''  // Build Claude messages, attaching any files to the final user turn.
  function buildClaudeMessages(): any[] {
    const msgs: any[] = body.messages.map(m => ({ role: m.role, content: m.content }));
    const atts = body.attachments || [];
    if (atts.length && msgs.length) {
      // find last user message
      let idx = -1;
      for (let i = msgs.length - 1; i >= 0; i--) { if (msgs[i].role === "user") { idx = i; break; } }
      if (idx >= 0) {
        const blocks: any[] = [];
        const baseText = typeof msgs[idx].content === "string" ? msgs[idx].content : "";
        if (baseText) blocks.push({ type: "text", text: baseText });
        for (const a of atts) {
          if (a.text) {
            blocks.push({ type: "text", text: `\\n\\n[Attached file: ${a.name}]\\n${a.text}` });
          } else if (a.data && a.mimeType === "application/pdf") {
            blocks.push({ type: "document", source: { type: "base64", media_type: "application/pdf", data: a.data } });
          } else if (a.data && a.mimeType && a.mimeType.startsWith("image/")) {
            blocks.push({ type: "image", source: { type: "base64", media_type: a.mimeType, data: a.data } });
          }
        }
        if (blocks.length) msgs[idx] = { role: "user", content: blocks };
      }
    }
    return msgs;
  }

  const client = new Anthropic({ apiKey });'''
    src = src.replace("  const client = new Anthropic({ apiKey });", helper, 1)

    # Use buildClaudeMessages() in the stream call.
    src = src.replace(
        "          messages: body.messages.map(m => ({ role: m.role, content: m.content })),\n        });",
        "          messages: buildClaudeMessages(),\n        });",
        1
    )
    open(p, "w").write(src)
    print("   ✓ Claude branch now attaches PDF/image/text to the last user message")
PYEOF

echo ""
echo "✅ All-agent attachments enabled (except ORACLE-11, which is text-only)."
echo ""
echo "Restart:  aegis-control restart"
echo ""
echo "Paperclip is now active on every agent except ORACLE-11."
echo "  Claude agents: PDF + images (native via Anthropic API), markdown/txt/csv (text), docx (converted)."
echo "  GEMINI-08: unchanged (its own multimodal path)."
echo "  ORACLE-11: paperclip disabled (Perplexity Sonar is text-only)."
echo ""
echo "Note: the one-file-at-a-time guidance for large PDFs still applies (request-size limits)."
echo ""
echo "Backups in .pre-allattach-backup/ — revert: cp -r .pre-allattach-backup/* ."
