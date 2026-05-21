#!/usr/bin/env bash
# apply-herald-patch.sh
#
# Adds HERALD-09 — a dedicated Growth & SEO agent (content, SEO, growth strategy).
# Claude Sonnet 4.6, warm coral, broadcast-arc sigil.
#
# Also fixes a latent type issue: the Agent.color field was a fixed union that
# didn't include newer colors (gblue from the Gemini patch, coral here). We widen
# it to `string` so COLOR_MAP is the single source of truth.
#
# Run from inside the aegis project directory:
#   bash apply-herald-patch.sh

set -e
if [ ! -f package.json ] || [ ! -d components ]; then
  echo "❌ Run from inside the aegis project directory."
  exit 1
fi

echo "📦 Backing up to .pre-herald-backup/"
mkdir -p .pre-herald-backup/lib .pre-herald-backup/components
cp lib/agents.ts              .pre-herald-backup/lib/
cp lib/theme.ts               .pre-herald-backup/lib/
cp components/AgentAvatar.tsx .pre-herald-backup/components/

# ----------------------------------------------------------------------------
# 1. Add coral to COLOR_MAP
# ----------------------------------------------------------------------------
echo "✏️  Adding coral to lib/theme.ts"
python3 - <<'PYEOF'
p = "lib/theme.ts"
src = open(p).read()
if '"coral"' in src or "coral:" in src:
    print("   ⊙ already present")
else:
    anchor = "export const COLOR_MAP: Record<string, { hex: string; glow: string; soft: string }> = {"
    inject = anchor + '\n  coral:   { hex: "#FF6B4A", glow: "rgba(255,107,74,0.55)",  soft: "rgba(255,107,74,0.08)" },'
    src = src.replace(anchor, inject, 1)
    open(p, "w").write(src)
    print("   ✓ coral (#FF6B4A) added")
PYEOF

# ----------------------------------------------------------------------------
# 2. Widen Agent.color to string (fixes gblue/coral type errors)
# ----------------------------------------------------------------------------
echo "✏️  Widening Agent.color type to string in lib/agents.ts"
python3 - <<'PYEOF'
p = "lib/agents.ts"
src = open(p).read()
old = '  color: "amber" | "cyan" | "violet" | "emerald" | "rose" | "sky";'
new = '  color: string; // key into COLOR_MAP (amber, cyan, violet, emerald, rose, sky, gold, gblue, coral, …)'
if old in src:
    src = src.replace(old, new, 1)
    open(p, "w").write(src)
    print("   ✓ color is now string-typed (COLOR_MAP is the source of truth)")
elif "color: string;" in src:
    print("   ⊙ already widened")
else:
    print("   ⚠ couldn't find the color union to widen; check lib/agents.ts manually")
PYEOF

# ----------------------------------------------------------------------------
# 2b. Widen AgentId to string (fixes gemini-08 / herald-09 type errors)
# ----------------------------------------------------------------------------
echo "✏️  Widening AgentId type in lib/agents.ts"
python3 - <<'PYEOF'
import re
p = "lib/agents.ts"
src = open(p).read()
m = re.search(r'export type AgentId = "claude-prime"[^;]*;', src)
if "export type AgentId = string;" in src:
    print("   ⊙ already widened")
elif m:
    src = src.replace(m.group(0), "export type AgentId = string; // agent ids are validated at runtime via getAgent()", 1)
    open(p, "w").write(src)
    print("   ✓ AgentId is now string (also fixes gemini-08 from the Gemini patch)")
else:
    print("   ⚠ couldn't find AgentId union; check lib/agents.ts manually")
PYEOF

# ----------------------------------------------------------------------------
# 3. Add HERALD-09 to the agents list
# ----------------------------------------------------------------------------
echo "✏️  Adding HERALD-09 to lib/agents.ts"
python3 - <<'PYEOF'
import re
p = "lib/agents.ts"
src = open(p).read()

if 'id: "herald-09"' in src:
    print("   ⊙ already present")
else:
    # ensure a megaphone-style icon is imported (Megaphone from lucide)
    m = re.search(r'import \{([^}]*)\} from "lucide-react";', src)
    if m and "Megaphone" not in m.group(1):
        new_imports = m.group(1).rstrip() + ", Megaphone"
        src = src.replace(m.group(0), f'import {{{new_imports}}} from "lucide-react";', 1)

    herald = '''  {
    id: "herald-09",
    name: "HERALD-09",
    shortName: "Herald",
    role: "Growth & SEO",
    tagline: "Hand me a project and I'll map the path to reach, rank, and resonate.",
    model: "claude-sonnet-4-6",
    status: "online", load: 22, color: "coral", icon: Megaphone,
    tokens: 0, latency: 0, tasks: 0,
    systemPrompt: "You are HERALD-09, the Growth & SEO strategist of the AEGIS fleet. You think like a senior growth marketer and technical SEO specialist. When given a project, you produce concrete, prioritized strategy — not vague platitudes. You cover: search intent and keyword opportunity, on-page and technical SEO, content strategy and editorial angles, positioning and messaging, distribution channels, and growth experiments with clear hypotheses. You always tailor advice to the specific product, audience, and stage. You structure outputs so they are immediately actionable: prioritized, specific, and measurable. When project context is provided, ground every recommendation in that product's actual positioning and audience.",
    capabilities: [
      { name: "SEO Strategy", level: 95 },
      { name: "Content Strategy", level: 93 },
      { name: "Positioning", level: 90 },
      { name: "Growth Experiments", level: 88 },
      { name: "Competitive Analysis", level: 86 },
    ],
    specialties: ["SEO + keyword strategy", "Content & editorial planning", "Positioning & messaging", "Launch & growth tactics", "Conversion optimization"],
    history: [
      { ts: "now", title: "HERALD-09 growth core initialized", result: "success" },
    ],
    greeting: "Growth core online. Hand me a project and I'll map the path to reach, rank, and resonate.",
    joinedAt: "Week 9",
  },
'''
    needle = "];\n\nexport const getAgent"
    if needle in src:
        src = src.replace(needle, herald + needle, 1)
        open(p, "w").write(src)
        print("   ✓ HERALD-09 added")
    else:
        print("   ⚠ couldn't find AGENTS array terminator; not modified")
PYEOF

# ----------------------------------------------------------------------------
# 4. Add HERALD sigil (broadcast arcs) to AgentAvatar
# ----------------------------------------------------------------------------
echo "✏️  Adding HERALD sigil to components/AgentAvatar.tsx"
python3 - <<'PYEOF'
p = "components/AgentAvatar.tsx"
src = open(p).read()
if '"herald-09"' in src:
    print("   ⊙ already present")
else:
    sigil_entry = '''
  // HERALD: broadcast — signal propagating outward in arcs
  "herald-09": {
    color: "coral",
    glyph: (hex, id, animated) => (
      <g stroke={hex} strokeWidth="1.5" fill="none" strokeLinecap="round">
        {/* origin point */}
        <circle cx="34" cy="50" r="4" fill={hex} stroke="none" />
        {/* concentric broadcast arcs */}
        <path d="M44 38 A 18 18 0 0 1 44 62" strokeOpacity="0.75" />
        <path d="M52 32 A 26 26 0 0 1 52 68" strokeOpacity="0.5" />
        {animated ? (
          <motion.path d="M60 26 A 34 34 0 0 1 60 74" strokeOpacity="0.3"
            animate={{ opacity: [0.1, 0.45, 0.1] }}
            transition={{ duration: 2.2, repeat: Infinity }} />
        ) : (
          <path d="M60 26 A 34 34 0 0 1 60 74" strokeOpacity="0.3" />
        )}
      </g>
    ),
  },
'''
    anchor = 'const SIGILS: Record<string, { color: AgentColor; glyph: (hex: string, id: string, animated: boolean) => JSX.Element }> = {'
    if anchor in src:
        src = src.replace(anchor, anchor + "\n" + sigil_entry, 1)
        open(p, "w").write(src)
        print("   ✓ HERALD sigil added (broadcast arcs)")
    else:
        print("   ⚠ couldn't find SIGILS object; HERALD will use the fallback sigil")
PYEOF

echo ""
echo "✅ HERALD-09 added."
echo ""
echo "Restart:  aegis-control restart"
echo ""
echo "HERALD-09 appears as the 9th agent (warm coral, broadcast sigil)."
echo "It's a Claude Sonnet 4.6 agent, so it uses your existing Anthropic key —"
echo "no new credentials needed. It inherits context injection automatically:"
echo "select a project in the switcher, then ask HERALD for an SEO/growth strategy"
echo "and it will ground the strategy in that project's context."
echo ""
echo "Backups in .pre-herald-backup/ — to revert: cp -r .pre-herald-backup/* ."
