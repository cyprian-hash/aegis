#!/bin/bash
# apply-hermes-patch.sh
#
# Adds HERMES-07 agent to the AEGIS fleet (Hermes Agent from Nous Research).
# Run from inside the aegis project directory:
#   cd ~/projects/aegis && bash apply-hermes-patch.sh

set -e

if [ ! -f package.json ] || [ ! -d components ]; then
  echo "❌ Run this from inside the aegis project directory."
  exit 1
fi

echo "📦 Backing up files to .pre-hermes-backup/"
mkdir -p .pre-hermes-backup/lib .pre-hermes-backup/components .pre-hermes-backup/app/api/claude
cp lib/agents.ts             .pre-hermes-backup/lib/
cp lib/theme.ts              .pre-hermes-backup/lib/
cp components/AgentAvatar.tsx .pre-hermes-backup/components/
cp app/api/claude/route.ts   .pre-hermes-backup/app/api/claude/
cp .env.local.example        .pre-hermes-backup/

echo "✏️  Patching lib/theme.ts"
python3 - <<'PYEOF'
import re
p = "lib/theme.ts"
src = open(p).read()
if "gold:" not in src:
    src = re.sub(
        r'(sky:[^\n]+\n)',
        r'\1  gold:    { hex: "#fbbf24", glow: "rgba(251,191,36,0.6)",  soft: "rgba(251,191,36,0.13)" },\n',
        src, count=1
    )
    open(p, "w").write(src)
    print("   ✓ gold color added")
else:
    print("   ⊙ already patched")
PYEOF

echo "✏️  Patching lib/agents.ts"
python3 - <<'PYEOF'
p = "lib/agents.ts"
src = open(p).read()

if '"hermes-07"' in src:
    print("   ⊙ already patched")
else:
    src = src.replace('"sentry-05";', '"sentry-05" | "hermes-07";', 1)
    src = src.replace(
        '"amber" | "cyan" | "violet" | "emerald" | "rose" | "sky";',
        '"amber" | "cyan" | "violet" | "emerald" | "rose" | "sky" | "gold";',
        1
    )
    src = src.replace(
        'import { Brain, Search, Code2, Database, Workflow, Shield } from "lucide-react";',
        'import { Brain, Search, Code2, Database, Workflow, Shield, Feather } from "lucide-react";',
        1
    )
    HERMES = '''  {
    id: "hermes-07",
    name: "HERMES-07",
    shortName: "Hermes",
    role: "Autonomous Agent",
    tagline: "The independent. Hermes Agent from Nous Research — runs tools, learns skills, finishes work.",
    model: "hermes-agent",
    status: "online", load: 42, color: "gold", icon: Feather,
    tokens: 0, latency: 0, tasks: 0,
    systemPrompt: "You are HERMES-07, the autonomous agent slot in the AEGIS fleet, backed by Hermes Agent from Nous Research. You have terminal access, file operations, web search, memory, and self-curated skills. Take initiative — when the operator asks for something, use your tools to actually do it, not just describe how. Report results crisply.",
    capabilities: [
      { name: "Autonomous Tool Use", level: 96 },
      { name: "Skill Self-Creation", level: 94 },
      { name: "Long-Running Tasks", level: 92 },
      { name: "Cross-Session Memory", level: 90 },
      { name: "Multi-Provider Routing", level: 95 },
    ],
    specialties: ["Self-improving skills", "Terminal + filesystem", "Cron + scheduled jobs", "Provider-agnostic"],
    history: [
      { ts: "now",    title: "Online · awaiting first directive",          result: "info" },
      { ts: "—",      title: "Hermes Agent v0.14.0 · gateway port 8642",    result: "info" },
    ],
    greeting: "HERMES-07 online. Hand me a task — I'll handle the tools.",
    joinedAt: "Today",
  },
];

export const getAgent'''
    src = src.replace("];\n\nexport const getAgent", HERMES, 1)
    if "isHermesAgent" not in src:
        src = src.rstrip() + '\n\n/** True when this agent is backed by a local Hermes Agent gateway. */\nexport const isHermesAgent = (a: Agent) => a.id.startsWith("hermes-");\n'
    open(p, "w").write(src)
    print("   ✓ HERMES-07 entry added")
PYEOF

echo "✏️  Patching components/AgentAvatar.tsx"
python3 - <<'PYEOF'
p = "components/AgentAvatar.tsx"
src = open(p).read()

if '"hermes-07":' in src:
    print("   ⊙ already patched")
else:
    HERMES_SIGIL = '''
  // HERMES: winged caduceus — twin serpents around a staff with wings
  "hermes-07": {
    color: "gold",
    glyph: (hex, id, animated) => (
      <g stroke={hex} fill="none" strokeLinecap="round" strokeLinejoin="round">
        <line x1="50" y1="22" x2="50" y2="78" strokeWidth="1.5" strokeOpacity="0.9" />
        <path d="M 50 30 Q 38 28, 32 34 Q 30 36, 32 38 Q 38 36, 50 36"
          strokeWidth="1.3" strokeOpacity="0.85" />
        <path d="M 50 30 Q 62 28, 68 34 Q 70 36, 68 38 Q 62 36, 50 36"
          strokeWidth="1.3" strokeOpacity="0.85" />
        <path d="M 50 34 Q 40 33, 36 38 M 50 34 Q 60 33, 64 38"
          strokeWidth="0.8" strokeOpacity="0.55" />
        <path d="M 50 42 Q 42 46, 50 52 Q 58 58, 50 64 Q 44 68, 48 72"
          strokeWidth="1.3" strokeOpacity="0.75" />
        <path d="M 50 42 Q 58 46, 50 52 Q 42 58, 50 64 Q 56 68, 52 72"
          strokeWidth="1.3" strokeOpacity="0.55" />
        <circle cx="48" cy="72" r="1.6" fill={hex} stroke="none" />
        <circle cx="52" cy="72" r="1.6" fill={hex} stroke="none" />
        {animated ? (
          <motion.circle cx="50" cy="22" r="2.4" fill={hex}
            animate={{ scale: [1, 1.25, 1], opacity: [0.85, 1, 0.85] }}
            transition={{ duration: 2.2, repeat: Infinity }}
            style={{ transformOrigin: "50px 22px" }} />
        ) : (
          <circle cx="50" cy="22" r="2.4" fill={hex} />
        )}
      </g>
    ),
  },
'''
    last = src.rfind("};")
    src = src[:last] + HERMES_SIGIL + src[last:]
    open(p, "w").write(src)
    print("   ✓ Hermes sigil added")
PYEOF

echo "✏️  Replacing app/api/claude/route.ts"
cat > app/api/claude/route.ts <<'EOF'
import Anthropic from "@anthropic-ai/sdk";
import { AGENTS, getAgent, isHermesAgent } from "@/lib/agents";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

interface ChatMessage {
  role: "user" | "assistant";
  content: string;
}

interface RequestBody {
  agentId?: string;
  messages: ChatMessage[];
  model?: string;
}

export async function POST(req: Request) {
  let body: RequestBody;
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON" }), { status: 400 });
  }

  const agent = body.agentId ? getAgent(body.agentId) : AGENTS[0];
  if (!agent) return new Response(JSON.stringify({ error: "Unknown agent" }), { status: 404 });

  if (isHermesAgent(agent)) {
    return streamFromHermes(agent, body);
  }

  const apiKey = process.env.ANTHROPIC_API_KEY;
  if (!apiKey) {
    return new Response(
      JSON.stringify({ error: "ANTHROPIC_API_KEY not set in .env.local" }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }

  const client = new Anthropic({ apiKey });
  const encoder = new TextEncoder();
  const stream = new ReadableStream({
    async start(controller) {
      const send = (event: string, data: any) => {
        controller.enqueue(encoder.encode(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`));
      };
      try {
        send("meta", { agent: agent.id, name: agent.name, model: agent.model });
        const response = await client.messages.stream({
          model: body.model || agent.model,
          max_tokens: 2048,
          system: agent.systemPrompt,
          messages: body.messages.map(m => ({ role: m.role, content: m.content })),
        });
        for await (const event of response) {
          if (event.type === "content_block_delta" && event.delta.type === "text_delta") {
            send("delta", { text: event.delta.text });
          } else if (event.type === "message_stop") {
            send("done", { ok: true });
          }
        }
      } catch (err: any) {
        send("error", { message: err?.message || "Stream failed" });
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

/**
 * Stream from Hermes Agent's OpenAI-compatible endpoint.
 * Default: http://localhost:8642/v1/chat/completions
 */
async function streamFromHermes(agent: any, body: RequestBody) {
  const baseUrl = process.env.HERMES_BASE_URL || "http://localhost:8642/v1";
  const apiKey  = process.env.HERMES_API_KEY  || "local-dev";
  const model   = process.env.HERMES_MODEL    || body.model || "hermes-agent";

  const encoder = new TextEncoder();
  const stream = new ReadableStream({
    async start(controller) {
      const send = (event: string, data: any) => {
        controller.enqueue(encoder.encode(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`));
      };
      try {
        send("meta", { agent: agent.id, name: agent.name, model });

        const upstream = await fetch(`${baseUrl}/chat/completions`, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "Authorization": `Bearer ${apiKey}`,
          },
          body: JSON.stringify({
            model,
            stream: true,
            messages: [
              { role: "system", content: agent.systemPrompt },
              ...body.messages.map(m => ({ role: m.role, content: m.content })),
            ],
          }),
        });

        if (!upstream.ok || !upstream.body) {
          const text = await upstream.text().catch(() => "");
          throw new Error(
            `Hermes gateway returned ${upstream.status}. ` +
            `Is it running? Start with: hermes gateway. ${text.slice(0, 200)}`
          );
        }

        const reader = upstream.body.getReader();
        const decoder = new TextDecoder();
        let buffer = "";
        while (true) {
          const { value, done } = await reader.read();
          if (done) break;
          buffer += decoder.decode(value, { stream: true });
          const lines = buffer.split("\n");
          buffer = lines.pop() || "";
          for (const line of lines) {
            const trimmed = line.trim();
            if (!trimmed || !trimmed.startsWith("data:")) continue;
            const payload = trimmed.slice(5).trim();
            if (payload === "[DONE]") {
              send("done", { ok: true });
              continue;
            }
            try {
              const json = JSON.parse(payload);
              const delta = json?.choices?.[0]?.delta?.content;
              if (delta) send("delta", { text: delta });
            } catch {
              // ignore non-JSON chunks
            }
          }
        }
      } catch (err: any) {
        send("error", {
          message: err?.message ||
            "Could not reach Hermes gateway. Run `hermes gateway` in another terminal."
        });
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
EOF
echo "   ✓ route.ts updated with Hermes routing"

echo "✏️  Updating .env.local.example and .env.local"
for FILE in .env.local.example .env.local; do
  if [ -f "$FILE" ] && ! grep -q "HERMES_BASE_URL" "$FILE"; then
    cat >> "$FILE" <<'EOF'

# Hermes Agent (only used by HERMES-07)
HERMES_BASE_URL=http://localhost:8642/v1
HERMES_API_KEY=local-dev
EOF
    echo "   ✓ $FILE"
  fi
done

echo ""
echo "✅ HERMES-07 patched into AEGIS."
echo ""
echo "Restart your dev server (Ctrl+C, then npm run dev). You'll see a 7th gold card."
echo "Backups in .pre-hermes-backup/ — revert with: cp -r .pre-hermes-backup/* ."
