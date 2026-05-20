#!/usr/bin/env bash
# apply-gemini-patch.sh
#
# Adds GEMINI-08 — a multimodal/vision specialist agent powered by Google's
# Gemini 3.1 Pro. Routes its chats to the Gemini API (not Anthropic).
#
# Requires GEMINI_API_KEY in .env.local (add it yourself; never commit it).
# Model string is configurable via GEMINI_MODEL in .env.local.
#
# Run from inside the aegis project directory:
#   bash apply-gemini-patch.sh

set -e
if [ ! -f package.json ] || [ ! -d components ]; then
  echo "❌ Run from inside the aegis project directory."
  exit 1
fi

echo "📦 Backing up to .pre-gemini-backup/"
mkdir -p .pre-gemini-backup/lib .pre-gemini-backup/components .pre-gemini-backup/app/api/claude
cp lib/agents.ts                  .pre-gemini-backup/lib/
cp lib/theme.ts                   .pre-gemini-backup/lib/
cp components/AgentAvatar.tsx     .pre-gemini-backup/components/
cp app/api/claude/route.ts        .pre-gemini-backup/app/api/claude/
cp .env.local.example             .pre-gemini-backup/ 2>/dev/null || true

# -----------------------------------------------------------------------------
# 1. Add google-blue to the color map
# -----------------------------------------------------------------------------
echo "✏️  Adding google-blue to lib/theme.ts"
python3 - <<'PYEOF'
p = "lib/theme.ts"
src = open(p).read()
if '"gblue"' in src or "gblue:" in src:
    print("   ⊙ already present")
else:
    # Insert a new color key into COLOR_MAP. Find the first "{" after COLOR_MAP and inject.
    anchor = "export const COLOR_MAP: Record<string, { hex: string; glow: string; soft: string }> = {"
    inject = anchor + '\n  gblue:   { hex: "#4285F4", glow: "rgba(66,133,244,0.55)",  soft: "rgba(66,133,244,0.08)" },'
    src = src.replace(anchor, inject, 1)
    open(p, "w").write(src)
    print("   ✓ google-blue (gblue) added")
PYEOF

# -----------------------------------------------------------------------------
# 2. Add GEMINI-08 to the agents list
# -----------------------------------------------------------------------------
echo "✏️  Adding GEMINI-08 to lib/agents.ts"
python3 - <<'PYEOF'
p = "lib/agents.ts"
src = open(p).read()

if 'id: "gemini-08"' in src:
    print("   ⊙ already present")
else:
    # Make sure there's an icon import we can use. Use "Eye" from lucide for vision.
    # Agents import line typically: import { ... } from "lucide-react";
    import re
    m = re.search(r'import \{([^}]*)\} from "lucide-react";', src)
    if m and "Eye" not in m.group(1):
        new_imports = m.group(1).rstrip() + ", Eye"
        src = src.replace(m.group(0), f'import {{{new_imports}}} from "lucide-react";', 1)

    gemini = '''  {
    id: "gemini-08",
    name: "GEMINI-08",
    shortName: "Gemini",
    role: "Vision Core",
    tagline: "I see what others read. Images, PDFs, video, a million tokens of context — I find what matters.",
    model: "gemini-3.1-pro-preview",
    status: "online", load: 14, color: "gblue", icon: Eye,
    tokens: 0, latency: 0, tasks: 0,
    systemPrompt: "You are GEMINI-08, the multimodal vision specialist of the AEGIS fleet, powered by Google Gemini. You excel at analyzing images, PDFs, video, audio, and very large context. When given visual or document input, describe precisely what you observe and extract what matters. You are perceptive, concise, and grounded — you report what is actually there, not what might be there.",
    capabilities: [
      { name: "Image Analysis", level: 97 },
      { name: "Document Vision", level: 96 },
      { name: "Long Context", level: 98 },
      { name: "Multimodal Reasoning", level: 94 },
      { name: "Chart / Diagram Reading", level: 90 },
    ],
    specialties: ["Image understanding", "PDF + document extraction", "1M-token context", "Video / audio analysis", "Visual QA"],
    history: [
      { ts: "now", title: "GEMINI-08 vision core initialized", result: "success" },
    ],
    greeting: "Vision core online. Show me anything — images, documents, video — and I'll tell you what's there.",
    joinedAt: "Week 9",
  },
'''
    # Insert before the closing "];" of the AGENTS array
    needle = "];\n\nexport const getAgent"
    if needle in src:
        src = src.replace(needle, gemini + needle, 1)
        open(p, "w").write(src)
        print("   ✓ GEMINI-08 added")
    else:
        print("   ⚠ couldn't find AGENTS array terminator; not modified")
PYEOF

# -----------------------------------------------------------------------------
# 3. Add a Gemini sigil to AgentAvatar
# -----------------------------------------------------------------------------
echo "✏️  Adding Gemini sigil to components/AgentAvatar.tsx"
python3 - <<'PYEOF'
p = "components/AgentAvatar.tsx"
src = open(p).read()

if '"gemini-08"' in src:
    print("   ⊙ already present")
else:
    # SIGILS is an object: { "<id>": { color, glyph: (hex, id, animated) => <g>...</g> }, ... }
    # Insert a new entry for gemini-08: twin interlocking circles (Gemini) + central
    # vision aperture, in the 100x100 viewBox the other sigils use.
    sigil_entry = '''
  // GEMINI: twin orbits + vision aperture
  "gemini-08": {
    color: "gblue",
    glyph: (hex, id, animated) => (
      <g stroke={hex} strokeWidth="1.4" fill="none" strokeLinecap="round">
        {/* twin interlocking orbits */}
        <circle cx="42" cy="50" r="20" strokeOpacity="0.5" />
        <circle cx="58" cy="50" r="20" strokeOpacity="0.5" />
        {/* aperture / iris */}
        <circle cx="50" cy="50" r="10" fill={hex} fillOpacity="0.12" />
        {animated ? (
          <motion.circle cx="50" cy="50" r="4.5" fill={hex} stroke="none"
            animate={{ scale: [1, 1.25, 1], opacity: [1, 0.6, 1] }}
            transition={{ duration: 2.4, repeat: Infinity }}
            style={{ transformOrigin: "50px 50px" }} />
        ) : (
          <circle cx="50" cy="50" r="4.5" fill={hex} stroke="none" />
        )}
        {/* cardinal sight ticks */}
        <line x1="50" y1="22" x2="50" y2="28" strokeOpacity="0.45" />
        <line x1="50" y1="72" x2="50" y2="78" strokeOpacity="0.45" />
        <line x1="18" y1="50" x2="24" y2="50" strokeOpacity="0.45" />
        <line x1="76" y1="50" x2="82" y2="50" strokeOpacity="0.45" />
      </g>
    ),
  },
'''
    # Insert as the first entry inside the SIGILS object.
    anchor = 'const SIGILS: Record<string, { color: AgentColor; glyph: (hex: string, id: string, animated: boolean) => JSX.Element }> = {'
    if anchor in src:
        src = src.replace(anchor, anchor + "\n" + sigil_entry, 1)
        open(p, "w").write(src)
        print("   ✓ Gemini sigil added (twin orbits + vision aperture)")
    else:
        print("   ⚠ couldn't find SIGILS object; GEMINI-08 will use the claude-prime fallback sigil")
PYEOF

# -----------------------------------------------------------------------------
# 4. Add the Gemini streaming branch to the chat API route
# -----------------------------------------------------------------------------
echo "✏️  Adding Gemini API branch to app/api/claude/route.ts"
python3 - <<'PYEOF'
p = "app/api/claude/route.ts"
src = open(p).read()

if "generativelanguage.googleapis.com" in src:
    print("   ⊙ already present")
else:
    # Insert a Gemini branch right after the agent is resolved and before the Anthropic client.
    # We detect Gemini by model name prefix.
    anchor = "  const client = new Anthropic({ apiKey });"
    gemini_branch = '''  // ---- Gemini branch -------------------------------------------------------
  const effectiveModel = body.model || agent.model;
  if (effectiveModel.startsWith("gemini")) {
    const geminiKey = process.env.GEMINI_API_KEY;
    if (!geminiKey) {
      return new Response(
        JSON.stringify({ error: "GEMINI_API_KEY not set in .env.local" }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }
    const model = process.env.GEMINI_MODEL || effectiveModel;
    const encoder = new TextEncoder();
    const stream = new ReadableStream({
      async start(controller) {
        const send = (event: string, data: any) => {
          controller.enqueue(encoder.encode(`event: ${event}\\ndata: ${JSON.stringify(data)}\\n\\n`));
        };
        try {
          send("meta", { agent: agent.id, name: agent.name, model });

          // Build Gemini "contents" from the message history.
          const contents = body.messages.map(m => ({
            role: m.role === "assistant" ? "model" : "user",
            parts: [{ text: m.content }],
          }));

          const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:streamGenerateContent?alt=sse`;
          const res = await fetch(url, {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              "x-goog-api-key": geminiKey,
            },
            body: JSON.stringify({
              systemInstruction: { parts: [{ text: agent.systemPrompt }] },
              contents,
              generationConfig: { maxOutputTokens: 2048 },
            }),
          });

          if (!res.ok || !res.body) {
            const errText = await res.text().catch(() => "");
            send("error", { message: `Gemini API ${res.status}: ${errText.slice(0, 300)}` });
            controller.close();
            return;
          }

          const reader = res.body.getReader();
          const decoder = new TextDecoder();
          let buf = "";
          while (true) {
            const { value, done } = await reader.read();
            if (done) break;
            buf += decoder.decode(value, { stream: true });
            const lines = buf.split("\\n");
            buf = lines.pop() || "";
            for (const line of lines) {
              const trimmed = line.trim();
              if (!trimmed.startsWith("data:")) continue;
              const payload = trimmed.slice(5).trim();
              if (!payload || payload === "[DONE]") continue;
              try {
                const json = JSON.parse(payload);
                const parts = json?.candidates?.[0]?.content?.parts;
                if (Array.isArray(parts)) {
                  for (const part of parts) {
                    if (part?.text) send("delta", { text: part.text });
                  }
                }
              } catch { /* skip non-JSON keepalive lines */ }
            }
          }
          send("done", { ok: true });
        } catch (err: any) {
          send("error", { message: err?.message || "Gemini stream failed" });
        } finally {
          controller.close();
        }
      },
    });
    return new Response(stream, {
      headers: {
        "Content-Type": "text/event-stream",
        "Cache-Control": "no-cache, no-transform",
        "Connection": "keep-alive",
      },
    });
  }
  // ---- end Gemini branch ---------------------------------------------------

'''
    # Note: the Anthropic key check at the top of POST runs before this branch.
    # Gemini users still need ANTHROPIC_API_KEY set OR we relax that check.
    # To avoid forcing an Anthropic key for Gemini-only use, move the key check
    # to only apply to non-gemini models.
    src = src.replace(anchor, gemini_branch + anchor, 1)

    # Relax the top-level ANTHROPIC_API_KEY guard so Gemini works without it.
    old_guard = '''  const apiKey = process.env.ANTHROPIC_API_KEY;
  if (!apiKey) {
    return new Response(
      JSON.stringify({ error: "ANTHROPIC_API_KEY not set in .env.local" }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }

  let body: RequestBody;'''
    new_guard = '''  const apiKey = process.env.ANTHROPIC_API_KEY;

  let body: RequestBody;'''
    src = src.replace(old_guard, new_guard, 1)

    # Add an Anthropic-key guard right before the Anthropic client is constructed
    src = src.replace(
        "  const client = new Anthropic({ apiKey });",
        '''  if (!apiKey) {
    return new Response(
      JSON.stringify({ error: "ANTHROPIC_API_KEY not set in .env.local" }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
  const client = new Anthropic({ apiKey });''',
        1
    )

    open(p, "w").write(src)
    print("   ✓ Gemini streaming branch added; Anthropic key now only required for Claude agents")
PYEOF

# -----------------------------------------------------------------------------
# 5. Add GEMINI_API_KEY + GEMINI_MODEL to env example
# -----------------------------------------------------------------------------
echo "✏️  Documenting env vars"
for FILE in .env.local.example .env.local; do
  if [ -f "$FILE" ] && ! grep -q "GEMINI_API_KEY" "$FILE"; then
    {
      echo ""
      echo "# Gemini (GEMINI-08 vision agent) — get a key at https://aistudio.google.com/apikey"
      echo "GEMINI_API_KEY="
      echo "# Optional: override the model string when Google renames it"
      echo "GEMINI_MODEL=gemini-3.1-pro-preview"
    } >> "$FILE"
    echo "   ✓ added GEMINI_API_KEY placeholder to $FILE"
  fi
done

echo ""
echo "✅ GEMINI-08 added."
echo ""
echo "⚠️  IMPORTANT — add your (rotated) Gemini key to .env.local:"
echo "      GEMINI_API_KEY=your-new-key-here"
echo ""
echo "Then restart the server:"
echo "      aegis-control restart      (if running via LaunchAgent)"
echo "   or Ctrl+C + npm run dev       (if running manually)"
echo ""
echo "GEMINI-08 will appear as the 8th agent (google-blue, Eye sigil)."
echo "Chat with it — its messages route to Gemini, not Anthropic."
echo "Model is gemini-3.1-pro-preview; change GEMINI_MODEL in .env.local to swap."
echo ""
echo "Backups in .pre-gemini-backup/ — to revert: cp -r .pre-gemini-backup/* ."
