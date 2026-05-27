#!/usr/bin/env bash
# apply-oracle-patch.sh
# Adds ORACLE-11 — Live Research & Web Intelligence (Perplexity Sonar, with citations).
# Distinct from SCOUT-01 (training knowledge); ORACLE searches the live web and cites sources.
# Teal (#14B8A6), eye sigil, model "sonar" (configurable via PERPLEXITY_MODEL).
# Requires PERPLEXITY_API_KEY in .env.local. Safe regardless of HERALD/VANGUARD.
set -e
if [ ! -f package.json ] || [ ! -d components ]; then
  echo "❌ Run from inside the aegis project directory."; exit 1
fi
if ! grep -q "composedSystem" app/api/claude/route.ts 2>/dev/null; then
  echo "❌ Context patch not detected (composedSystem missing in route)."
  echo "   Apply apply-context-patch.sh first, then re-run this."
  exit 1
fi
echo "📦 Backing up to .pre-oracle-backup/"
mkdir -p .pre-oracle-backup/lib .pre-oracle-backup/components .pre-oracle-backup/app/api/claude
cp lib/agents.ts .pre-oracle-backup/lib/
cp lib/theme.ts .pre-oracle-backup/lib/
cp components/AgentAvatar.tsx .pre-oracle-backup/components/
cp app/api/claude/route.ts .pre-oracle-backup/app/api/claude/

echo "✏️  Adding teal to lib/theme.ts"
python3 - <<'PYEOF'
p="lib/theme.ts"; src=open(p).read()
if '"teal"' in src or "teal:" in src: print("   ⊙ already present")
else:
    a="export const COLOR_MAP: Record<string, { hex: string; glow: string; soft: string }> = {"
    src=src.replace(a, a+'\n  teal: { hex: "#14B8A6", glow: "rgba(20,184,166,0.55)", soft: "rgba(20,184,166,0.08)" },',1)
    open(p,"w").write(src); print("   ✓ teal (#14B8A6) added")
PYEOF

echo "✏️  Ensuring Agent.color and AgentId are string-typed"
python3 - <<'PYEOF'
import re; p="lib/agents.ts"; src=open(p).read()
oc='  color: "amber" | "cyan" | "violet" | "emerald" | "rose" | "sky";'
if oc in src: src=src.replace(oc,'  color: string; // key into COLOR_MAP',1); print("   ✓ color widened")
else: print("   ⊙ color already string")
m=re.search(r'export type AgentId = "claude-prime"[^;]*;',src)
if m: src=src.replace(m.group(0),"export type AgentId = string; // validated at runtime via getAgent()",1); print("   ✓ AgentId widened")
else: print("   ⊙ AgentId already string")
open(p,"w").write(src)
PYEOF

echo "✏️  Adding ORACLE-11 to lib/agents.ts"
python3 - <<'PYEOF'
import re; p="lib/agents.ts"; src=open(p).read()
if 'id: "oracle-11"' in src: print("   ⊙ already present")
else:
    m=re.search(r'import \{([^}]*)\} from "lucide-react";',src)
    if m and "Eye" not in m.group(1):
        src=src.replace(m.group(0),f'import {{{m.group(1).rstrip()}, Eye}} from "lucide-react";',1)
    oracle='''  {
    id: "oracle-11",
    name: "ORACLE-11",
    shortName: "Oracle",
    role: "Live Research & Web Intelligence",
    tagline: "Ask me what's true right now — I'll search the live web and show my sources.",
    model: "sonar",
    status: "online", load: 16, color: "teal", icon: Eye,
    tokens: 0, latency: 0, tasks: 0,
    systemPrompt: "You are ORACLE-11, the Live Research & Web Intelligence agent of the AEGIS fleet, powered by real-time web search. Unlike SCOUT-01 (who reasons from prior knowledge), you search the live web and ground every answer in current, verifiable sources. Be accurate, current, and concise. Cite specifics. When a question depends on recent or changeable facts (prices, news, releases, current status), rely on what the search returns rather than assumptions. When project context is provided, focus your research on what is relevant to that project. Present findings clearly and flag uncertainty or conflicting sources honestly.",
    capabilities: [
      { name: "Live Web Search", level: 96 },
      { name: "Source Citation", level: 95 },
      { name: "Current Events", level: 93 },
      { name: "Fact Verification", level: 92 },
      { name: "Competitive Research", level: 90 },
    ],
    specialties: ["Real-time web search", "Cited research", "Current events & news", "Fact verification", "Competitive / market scans"],
    history: [ { ts: "now", title: "ORACLE-11 research core initialized", result: "success" } ],
    greeting: "Oracle online. Ask me what's true right now — I'll search the live web and show my sources.",
    joinedAt: "Week 9",
  },
'''
    needle="];\n\nexport const getAgent"
    if needle in src:
        src=src.replace(needle,oracle+needle,1); open(p,"w").write(src); print("   ✓ ORACLE-11 added")
    else: print("   ⚠ couldn't find AGENTS terminator")
PYEOF

echo "✏️  Adding ORACLE sigil to components/AgentAvatar.tsx"
python3 - <<'PYEOF'
p="components/AgentAvatar.tsx"; src=open(p).read()
if '"oracle-11"' in src: print("   ⊙ already present")
else:
    sigil='''
  "oracle-11": {
    color: "teal",
    glyph: (hex, id, animated) => (
      <g stroke={hex} fill="none" strokeLinecap="round">
        <circle cx="50" cy="50" r="30" strokeWidth="1.4" strokeOpacity="0.4" />
        <path d="M28 50 Q50 32 72 50 Q50 68 28 50 Z" strokeWidth="1.6" strokeOpacity="0.85" />
        {animated ? (
          <motion.circle cx="50" cy="50" r="8" strokeWidth="1.6" fill={hex} fillOpacity="0.18"
            animate={{ r: [7, 9, 7], fillOpacity: [0.12, 0.28, 0.12] }}
            transition={{ duration: 2.4, repeat: Infinity }} />
        ) : (
          <circle cx="50" cy="50" r="8" strokeWidth="1.6" fill={hex} fillOpacity="0.18" />
        )}
        <circle cx="50" cy="50" r="2.4" fill={hex} stroke="none" />
      </g>
    ),
  },
'''
    a='const SIGILS: Record<string, { color: AgentColor; glyph: (hex: string, id: string, animated: boolean) => JSX.Element }> = {'
    if a in src: src=src.replace(a,a+"\n"+sigil,1); open(p,"w").write(src); print("   ✓ ORACLE sigil added (eye)")
    else: print("   ⚠ couldn't find SIGILS object")
PYEOF

echo "✏️  Ensuring RequestBody has attachments field (repairs latent upload-patch gap)"
python3 - <<'PYEOF'
p="app/api/claude/route.ts"; src=open(p).read()
if "body.attachments" in src and "attachments?:" not in src:
    src=src.replace(
        "  activeProjectId?: string | null;\n}",
        "  activeProjectId?: string | null;\n  attachments?: any[];\n}",
        1)
    open(p,"w").write(src); print("   ✓ attachments field added to RequestBody")
else:
    print("   ⊙ attachments field already present or unused")
PYEOF

echo "✏️  Adding Perplexity (Sonar) branch to app/api/claude/route.ts"
python3 - <<'PYEOF'
p="app/api/claude/route.ts"; src=open(p).read()
if "api.perplexity.ai" in src: print("   ⊙ Perplexity branch already present")
else:
    anchor="  // ---- Gemini branch -------------------------------------------------------"
    branch='''  // ---- Perplexity (ORACLE) branch -----------------------------------------
  const _model = body.model || agent.model;
  if (_model.startsWith("sonar")) {
    const pplxKey = process.env.PERPLEXITY_API_KEY;
    if (!pplxKey) {
      return new Response(
        JSON.stringify({ error: "PERPLEXITY_API_KEY not set in .env.local" }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }
    const model = process.env.PERPLEXITY_MODEL || _model;
    const encoder = new TextEncoder();
    const stream = new ReadableStream({
      async start(controller) {
        const send = (event: string, data: any) => {
          controller.enqueue(encoder.encode(`event: ${event}\\ndata: ${JSON.stringify(data)}\\n\\n`));
        };
        try {
          send("meta", { agent: agent.id, name: agent.name, model });
          const messages = [
            { role: "system", content: composedSystem },
            ...body.messages.map(m => ({ role: m.role, content: m.content })),
          ];
          const resp = await fetch("https://api.perplexity.ai/chat/completions", {
            method: "POST",
            headers: { "Authorization": `Bearer ${pplxKey}`, "Content-Type": "application/json" },
            body: JSON.stringify({ model, messages, stream: true }),
          });
          if (!resp.ok || !resp.body) {
            const errText = await resp.text().catch(() => "");
            send("error", { message: `Perplexity API ${resp.status}: ${errText.slice(0, 300)}` });
            controller.close(); return;
          }
          const reader = resp.body.getReader();
          const decoder = new TextDecoder();
          let buffer = "";
          let citations: string[] = [];
          while (true) {
            const { value, done } = await reader.read();
            if (done) break;
            buffer += decoder.decode(value, { stream: true });
            const lines = buffer.split("\\n");
            buffer = lines.pop() || "";
            for (const line of lines) {
              const trimmed = line.trim();
              if (!trimmed.startsWith("data:")) continue;
              const payload = trimmed.slice(5).trim();
              if (payload === "[DONE]") continue;
              try {
                const json = JSON.parse(payload);
                if (Array.isArray(json.citations) && json.citations.length) citations = json.citations;
                const delta = json.choices?.[0]?.delta?.content;
                if (delta) send("delta", { text: delta });
              } catch { /* partial chunk */ }
            }
          }
          if (citations.length) {
            const list = citations.map((c, i) => `${i + 1}. ${c}`).join("\\n");
            send("delta", { text: `\\n\\n**Sources:**\\n${list}` });
          }
          send("done", { ok: true });
          controller.close();
        } catch (err: any) {
          send("error", { message: err?.message || "Perplexity request failed" });
          controller.close();
        }
      },
    });
    return new Response(stream, {
      headers: { "Content-Type": "text/event-stream", "Cache-Control": "no-cache, no-transform", "Connection": "keep-alive" },
    });
  }

'''
    src=src.replace(anchor,branch+anchor,1); open(p,"w").write(src); print("   ✓ Perplexity branch added (streams answer + Sources)")
PYEOF

echo ""
echo "✅ ORACLE-11 added."
echo ""
echo "⚠️  REQUIRED: add your Perplexity API key to .env.local (NOT in chat):"
echo "      echo 'PERPLEXITY_API_KEY=your-key-here' >> .env.local"
echo "   (optional) model — default 'sonar':"
echo "      echo 'PERPLEXITY_MODEL=sonar-pro' >> .env.local"
echo ""
echo "Then: aegis-control restart"
echo ""
echo "SCOUT-01 = training knowledge | ORACLE-11 = live web search with sources"
echo "Backups in .pre-oracle-backup/ — revert: cp -r .pre-oracle-backup/* ."
