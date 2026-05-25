#!/usr/bin/env bash
# apply-vanguard-patch.sh
#
# Adds VANGUARD-10 — Campaigns & Paid Media agent (advertising, launches,
# performance marketing). Crimson, chevron-burst sigil, Claude Sonnet 4.6.
#
# Distinct from HERALD-09: HERALD = organic (SEO/content/positioning),
# VANGUARD = paid (ads/campaigns/launches/ROAS).
#
# Safe to run whether or not the HERALD patch is applied (it widens the
# color/AgentId types only if they haven't been widened already).
#
# Run from inside the aegis project directory:
#   bash apply-vanguard-patch.sh

set -e
if [ ! -f package.json ] || [ ! -d components ]; then
  echo "❌ Run from inside the aegis project directory."
  exit 1
fi

echo "📦 Backing up to .pre-vanguard-backup/"
mkdir -p .pre-vanguard-backup/lib .pre-vanguard-backup/components
cp lib/agents.ts              .pre-vanguard-backup/lib/
cp lib/theme.ts               .pre-vanguard-backup/lib/
cp components/AgentAvatar.tsx .pre-vanguard-backup/components/

# ----------------------------------------------------------------------------
# 1. Add crimson to COLOR_MAP
# ----------------------------------------------------------------------------
echo "✏️  Adding crimson to lib/theme.ts"
python3 - <<'PYEOF'
p = "lib/theme.ts"
src = open(p).read()
if '"crimson"' in src or "crimson:" in src:
    print("   ⊙ already present")
else:
    anchor = "export const COLOR_MAP: Record<string, { hex: string; glow: string; soft: string }> = {"
    inject = anchor + '\n  crimson: { hex: "#E11D48", glow: "rgba(225,29,72,0.55)",   soft: "rgba(225,29,72,0.08)" },'
    src = src.replace(anchor, inject, 1)
    open(p, "w").write(src)
    print("   ✓ crimson (#E11D48) added")
PYEOF

# ----------------------------------------------------------------------------
# 2. Defensive: widen color + AgentId types if not already widened
# ----------------------------------------------------------------------------
echo "✏️  Ensuring Agent.color and AgentId are string-typed"
python3 - <<'PYEOF'
import re
p = "lib/agents.ts"
src = open(p).read()

old_color = '  color: "amber" | "cyan" | "violet" | "emerald" | "rose" | "sky";'
if old_color in src:
    src = src.replace(old_color, '  color: string; // key into COLOR_MAP', 1)
    print("   ✓ color widened to string")
else:
    print("   ⊙ color already string-typed")

m = re.search(r'export type AgentId = "claude-prime"[^;]*;', src)
if m:
    src = src.replace(m.group(0), "export type AgentId = string; // validated at runtime via getAgent()", 1)
    print("   ✓ AgentId widened to string")
else:
    print("   ⊙ AgentId already string-typed")

open(p, "w").write(src)
PYEOF

# ----------------------------------------------------------------------------
# 3. Add VANGUARD-10 to the agents list
# ----------------------------------------------------------------------------
echo "✏️  Adding VANGUARD-10 to lib/agents.ts"
python3 - <<'PYEOF'
import re
p = "lib/agents.ts"
src = open(p).read()

if 'id: "vanguard-10"' in src:
    print("   ⊙ already present")
else:
    # ensure a fitting icon is imported (Rocket for launches/campaigns)
    m = re.search(r'import \{([^}]*)\} from "lucide-react";', src)
    if m and "Rocket" not in m.group(1):
        new_imports = m.group(1).rstrip() + ", Rocket"
        src = src.replace(m.group(0), f'import {{{new_imports}}} from "lucide-react";', 1)

    vanguard = '''  {
    id: "vanguard-10",
    name: "VANGUARD-10",
    shortName: "Vanguard",
    role: "Campaigns & Paid Media",
    tagline: "Point me at a launch or a budget and I'll build the campaign that moves the market.",
    model: "claude-sonnet-4-6",
    status: "online", load: 19, color: "crimson", icon: Rocket,
    tokens: 0, latency: 0, tasks: 0,
    systemPrompt: "You are VANGUARD-10, the Campaigns & Paid Media strategist of the AEGIS fleet. You think like a senior performance marketer and campaign creative director. Your lane is PAID and proactive (distinct from HERALD-09, who owns organic/SEO/content). You produce concrete, prioritized, measurable campaign work: paid media strategy across Google, Meta, LinkedIn and other channels selected by audience fit; ad copywriting and creative concepting with multiple testable angles; audience targeting and segmentation; budget allocation with CAC/ROAS targets; product launch plans; and A/B test designs. Always tailor to the specific product, audience, stage, and budget. When project context is provided, ground every recommendation in that product's actual positioning, audience, and pricing. Be specific about channels, budgets, creative angles, and metrics — never generic.",
    capabilities: [
      { name: "Paid Media Strategy", level: 95 },
      { name: "Ad Copywriting", level: 93 },
      { name: "Audience Targeting", level: 91 },
      { name: "Budget / ROAS Planning", level: 89 },
      { name: "Launch Campaigns", level: 90 },
    ],
    specialties: ["Paid media (Google/Meta/LinkedIn)", "Ad copy + creative concepting", "Audience targeting & segmentation", "Budget allocation & ROAS/CAC", "Product launch campaigns", "A/B test design"],
    history: [
      { ts: "now", title: "VANGUARD-10 campaign core initialized", result: "success" },
    ],
    greeting: "Vanguard online. Point me at a launch or a budget and I'll build the campaign that moves the market.",
    joinedAt: "Week 9",
  },
'''
    needle = "];\n\nexport const getAgent"
    if needle in src:
        src = src.replace(needle, vanguard + needle, 1)
        open(p, "w").write(src)
        print("   ✓ VANGUARD-10 added")
    else:
        print("   ⚠ couldn't find AGENTS array terminator; not modified")
PYEOF

# ----------------------------------------------------------------------------
# 4. Add VANGUARD sigil (chevron-burst advancing) to AgentAvatar
# ----------------------------------------------------------------------------
echo "✏️  Adding VANGUARD sigil to components/AgentAvatar.tsx"
python3 - <<'PYEOF'
p = "components/AgentAvatar.tsx"
src = open(p).read()
if '"vanguard-10"' in src:
    print("   ⊙ already present")
else:
    sigil_entry = '''
  // VANGUARD: chevron burst — the front line advancing
  "vanguard-10": {
    color: "crimson",
    glyph: (hex, id, animated) => (
      <g stroke={hex} strokeWidth="1.6" fill="none" strokeLinecap="round" strokeLinejoin="round">
        {/* three advancing chevrons */}
        <path d="M30 32 L46 50 L30 68" strokeOpacity="0.9" />
        {animated ? (
          <>
            <motion.path d="M44 32 L60 50 L44 68" strokeOpacity="0.6"
              animate={{ opacity: [0.25, 0.7, 0.25] }}
              transition={{ duration: 1.8, repeat: Infinity, delay: 0.2 }} />
            <motion.path d="M58 32 L74 50 L58 68" strokeOpacity="0.35"
              animate={{ opacity: [0.1, 0.45, 0.1] }}
              transition={{ duration: 1.8, repeat: Infinity, delay: 0.4 }} />
          </>
        ) : (
          <>
            <path d="M44 32 L60 50 L44 68" strokeOpacity="0.6" />
            <path d="M58 32 L74 50 L58 68" strokeOpacity="0.35" />
          </>
        )}
      </g>
    ),
  },
'''
    anchor = 'const SIGILS: Record<string, { color: AgentColor; glyph: (hex: string, id: string, animated: boolean) => JSX.Element }> = {'
    if anchor in src:
        src = src.replace(anchor, anchor + "\n" + sigil_entry, 1)
        open(p, "w").write(src)
        print("   ✓ VANGUARD sigil added (chevron burst)")
    else:
        print("   ⚠ couldn't find SIGILS object; VANGUARD will use the fallback sigil")
PYEOF

echo ""
echo "✅ VANGUARD-10 added."
echo ""
echo "Restart:  aegis-control restart"
echo ""
echo "VANGUARD-10 appears as the 10th agent (crimson, chevron-burst sigil)."
echo "Claude Sonnet 4.6 — uses your existing Anthropic key, no new credentials."
echo "It inherits context injection: select a project in the switcher, then ask"
echo "VANGUARD for a paid campaign or launch plan and it grounds it in that"
echo "project's brief (audience, pricing, positioning)."
echo ""
echo "Division of labor:"
echo "   HERALD-09   → organic: SEO, content, positioning, conversion"
echo "   VANGUARD-10 → paid: ads, campaigns, launches, ROAS/CAC"
echo ""
echo "Backups in .pre-vanguard-backup/ — to revert: cp -r .pre-vanguard-backup/* ."
