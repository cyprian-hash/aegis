#!/usr/bin/env bash
# apply-context-patch.sh
#
# Agent Context Injection — every agent reads context about you + Privé Systems
# from your Obsidian vault before responding, so they "never start from zero."
#
#  - Seeds AEGIS/Context/{about-me,business,voice-and-style}.md in your vault
#  - API route prepends global context to every agent's system prompt
#  - When a project is active, that project's context is appended too (option b)
#  - Reads server-side from the vault; nothing sensitive added to the client
#
# Run from inside the aegis project directory:
#   bash apply-context-patch.sh

set -e
if [ ! -f package.json ] || [ ! -d components ]; then
  echo "❌ Run from inside the aegis project directory."
  exit 1
fi
if [ ! -f app/api/claude/route.ts ]; then
  echo "❌ app/api/claude/route.ts missing."
  exit 1
fi

VAULT="${OBSIDIAN_VAULT:-$(grep ^OBSIDIAN_VAULT .env.local 2>/dev/null | cut -d= -f2-)}"

echo "📦 Backing up to .pre-context-backup/"
mkdir -p .pre-context-backup/app/api/claude .pre-context-backup/components .pre-context-backup/lib
cp app/api/claude/route.ts   .pre-context-backup/app/api/claude/
cp components/ChatView.tsx   .pre-context-backup/components/

# ----------------------------------------------------------------------------
# 1. Seed the context files in the vault
# ----------------------------------------------------------------------------
if [ -n "$VAULT" ] && [ -d "$VAULT" ]; then
  CTX_DIR="$VAULT/AEGIS/Context"
  mkdir -p "$CTX_DIR"

  if [ ! -f "$CTX_DIR/about-me.md" ]; then
    cat > "$CTX_DIR/about-me.md" <<'EOF'
# About Me

_This file is read by every AEGIS agent before it responds. Keep it tight and
useful — a few hundred words. Edit freely in Obsidian; changes take effect on
the next message._

## Who I am

I'm Cyprian, founder of Privé Systems Group — a privately held multi-product
technology group. I build AI-driven platforms across aviation, luxury
transport, domains, audio, and more.

## How I work

- I prefer a careful, methodical pace — "slow and steady wins the race."
- I value honest pushback over yes-manning. Tell me when something is a bad
  idea or won't work.
- I run my command center (AEGIS) on a Mac mini as the always-on server, and
  use a MacBook + iPhone as clients via Tailscale.

## What I care about

- Security and doing things the right way, not the fast way.
- Clean architecture over hype.
- Keeping my projects organized and well-documented.
EOF
    echo "   ✓ seeded about-me.md"
  else
    echo "   ⊙ about-me.md already exists, leaving it"
  fi

  if [ ! -f "$CTX_DIR/business.md" ]; then
    cat > "$CTX_DIR/business.md" <<'EOF'
# Privé Systems — Business Context

_Read by every agent. The portfolio overview. Keep it current._

## The umbrella

Privé Systems Group — privately held multi-product technology group building
scalable AI-driven platforms.

## Portfolio (12 projects)

- **My Central Domains** — domain portfolio infrastructure (Web2 + Web3). Live, iOS.
- **Aura** — AI automation + intelligent concierge. Live.
- **Vault Legacy** — secure digital asset + legacy management. Live.
- **Jet Van VIP** — luxury ground transport + logistics. Live.
- **API Monitor** — real-time AI/cloud API cost analysis. Live.
- **Netty Banks** — AI task-delegation assistant (the app). Live.
- **Jetpedia** — private aviation intelligence + fleet forecasting. Live, iOS.
- **Yachtpedia** — superyacht market transparency. In development.
- **Autopedia** — hypercar provenance + asset integrity. Concept.
- **Memory SoundX** — cognitive audio + personalized soundscapes. Live, iOS.
- **Netty** — my personal GravityClaw agent on Telegram (separate from the app).

## Infrastructure notes

- Most project email is on Hostinger; Jet Van VIP is the one Google Workspace.
- Netty (agent) runs on a Hostinger VPS, edited in Antigravity, auto-deploys from GitHub.
EOF
    echo "   ✓ seeded business.md"
  else
    echo "   ⊙ business.md already exists, leaving it"
  fi

  if [ ! -f "$CTX_DIR/voice-and-style.md" ]; then
    cat > "$CTX_DIR/voice-and-style.md" <<'EOF'
# Voice & Style

_How agents should communicate with me and on my behalf._

- Be direct and concise. Lead with the answer.
- Push back honestly when I'm about to do something suboptimal.
- No hype, no filler, no over-formatting.
- When drafting content for Privé Systems, keep a refined, understated, premium tone.
EOF
    echo "   ✓ seeded voice-and-style.md"
  else
    echo "   ⊙ voice-and-style.md already exists, leaving it"
  fi

  # A README so it's clear these are special
  cat > "$CTX_DIR/README.md" <<'EOF'
# AEGIS Context

These files are injected into every agent's system prompt:
- about-me.md, business.md, voice-and-style.md → global, always loaded
- When a project is active in the switcher, that project's own notes are added too.

Keep them lean — every word here is sent on every message.
EOF
else
  echo "   ⊙ Vault path not found — context files NOT seeded."
  echo "     Set OBSIDIAN_VAULT in .env.local and create AEGIS/Context/*.md manually,"
  echo "     or re-run this patch once the vault path is available."
fi

# ----------------------------------------------------------------------------
# 2. Create a server helper that reads context from the vault
# ----------------------------------------------------------------------------
echo "✏️  Creating lib/context.ts (server-side context loader)"
cat > lib/context.ts <<'EOF'
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
EOF
echo "   ✓ lib/context.ts created"

# ----------------------------------------------------------------------------
# 3. Wire context into the chat API route
# ----------------------------------------------------------------------------
echo "✏️  Injecting context into app/api/claude/route.ts"
python3 - <<'PYEOF'
p = "app/api/claude/route.ts"
src = open(p).read()

if "buildContextBlock" in src:
    print("   ⊙ already wired")
else:
    # import
    src = src.replace(
        'import { AGENTS, getAgent } from "@/lib/agents";',
        'import { AGENTS, getAgent } from "@/lib/agents";\nimport { buildContextBlock } from "@/lib/context";',
        1
    )
    # add activeProjectId to the request body interface
    src = src.replace(
        "interface RequestBody {\n  agentId?: string;\n  messages: ChatMessage[];\n  model?: string;\n}",
        "interface RequestBody {\n  agentId?: string;\n  messages: ChatMessage[];\n  model?: string;\n  activeProjectId?: string | null;\n}",
        1
    )

    # Build the context block once, right after we resolve the agent.
    src = src.replace(
        '  const agent = body.agentId ? getAgent(body.agentId) : AGENTS[0];\n  if (!agent) return new Response(JSON.stringify({ error: "Unknown agent" }), { status: 404 });',
        '  const agent = body.agentId ? getAgent(body.agentId) : AGENTS[0];\n  if (!agent) return new Response(JSON.stringify({ error: "Unknown agent" }), { status: 404 });\n\n  // Persistent operator/business/project context from the Obsidian vault.\n  const contextBlock = await buildContextBlock(body.activeProjectId);\n  const composedSystem = contextBlock\n    ? `${contextBlock}\\n\\n---\\n\\n${agent.systemPrompt}`\n    : agent.systemPrompt;',
        1
    )

    # Use composedSystem in the Anthropic call
    src = src.replace(
        "          system: agent.systemPrompt,",
        "          system: composedSystem,",
        1
    )

    # Use composedSystem in the Gemini branch systemInstruction (if present)
    src = src.replace(
        "              systemInstruction: { parts: [{ text: agent.systemPrompt }] },",
        "              systemInstruction: { parts: [{ text: composedSystem }] },",
        1
    )

    open(p, "w").write(src)
    print("   ✓ context injected into system prompt (Claude + Gemini branches)")
PYEOF

# ----------------------------------------------------------------------------
# 4. Make ChatView send the active project id
# ----------------------------------------------------------------------------
echo "✏️  Patching components/ChatView.tsx to send activeProjectId"
python3 - <<'PYEOF'
import re
p = "components/ChatView.tsx"
src = open(p).read()

if "activeProjectId" in src:
    print("   ⊙ already patched")
else:
    # Detect the real localStorage key the switcher uses (from useProjects.ts),
    # so per-project context actually loads. Fall back to a sensible default.
    key = "aegis_active_project"
    try:
        up = open("lib/useProjects.ts").read()
        m = re.search(r'ACTIVE_KEY\s*=\s*"([^"]+)"', up)
        if m:
            key = m.group(1)
        else:
            m2 = re.search(r'localStorage\.getItem\("([^"]*project[^"]*)"\)', up, re.I)
            if m2:
                key = m2.group(1)
    except FileNotFoundError:
        pass
    print(f"   • using active-project key: {key}")

    src = src.replace(
        '''      const res = await fetch("/api/claude", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ agentId: agent.id, messages: apiMessages }),
        signal: ctrl.signal,
      });''',
        '''      let activeProjectId: string | null = null;
      try { activeProjectId = localStorage.getItem("__ACTIVE_KEY__"); } catch {}
      const res = await fetch("/api/claude", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ agentId: agent.id, messages: apiMessages, activeProjectId }),
        signal: ctrl.signal,
      });'''.replace("__ACTIVE_KEY__", key),
        1
    )
    open(p, "w").write(src)
    print("   ✓ ChatView now sends activeProjectId from localStorage")
PYEOF

# ----------------------------------------------------------------------------
# 5. Done
# ----------------------------------------------------------------------------
echo ""
echo "✅ Agent context injection installed."
echo ""
echo "Restart: aegis-control restart"
echo ""
echo "What changed:"
echo "   - AEGIS/Context/{about-me,business,voice-and-style}.md seeded in your vault"
echo "   - Every agent now reads that global context before responding"
echo "   - With a project active in the switcher, that project's context is added too"
echo ""
echo "Edit the context files in Obsidian anytime — changes apply on the next message."
echo "Keep them lean: every word is sent on every message (8000-char cap enforced)."
echo ""
echo "Backups in .pre-context-backup/ — to revert: cp -r .pre-context-backup/* ."
