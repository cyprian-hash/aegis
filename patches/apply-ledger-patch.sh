#!/usr/bin/env bash
# apply-ledger-patch.sh
# Adds LEDGER-12 — Finance & Operations agent (unit economics, pricing, MRR/ARR,
# runway, cost analysis, financial modeling). Analysis/modeling only — not wired
# to live financial data. Deep green (#15803D), scales sigil, Claude Sonnet 4.6.
# Built and verified against the real repo (github.com/cyprian-hash/aegis).
set -e
if [ ! -f package.json ] || [ ! -d components ]; then
  echo "❌ Run from inside the aegis project directory."; exit 1
fi

echo "📦 Backing up to .pre-ledger-backup/"
mkdir -p .pre-ledger-backup/lib .pre-ledger-backup/components
cp lib/agents.ts              .pre-ledger-backup/lib/
cp lib/theme.ts               .pre-ledger-backup/lib/
cp components/AgentAvatar.tsx .pre-ledger-backup/components/

# ----------------------------------------------------------------------------
# 1. Add ledgergreen to COLOR_MAP
# ----------------------------------------------------------------------------
echo "✏️  Adding ledger green to lib/theme.ts"
python3 - <<'PYEOF'
p = "lib/theme.ts"; src = open(p).read()
if '"ledgergreen"' in src or "ledgergreen:" in src:
    print("   ⊙ already present")
else:
    a = "export const COLOR_MAP: Record<string, { hex: string; glow: string; soft: string }> = {"
    src = src.replace(a, a + '\n  ledgergreen: { hex: "#15803D", glow: "rgba(21,128,61,0.55)", soft: "rgba(21,128,61,0.08)" },', 1)
    open(p, "w").write(src); print("   ✓ ledgergreen (#15803D) added")
PYEOF

# ----------------------------------------------------------------------------
# 2. Properly widen Agent.color to string (it was never actually widened;
#    the real union on the interface line excludes gblue/coral/crimson/teal).
# ----------------------------------------------------------------------------
echo "✏️  Widening Agent.color to string (fixes latent narrow-union type)"
python3 - <<'PYEOF'
import re
p = "lib/agents.ts"; src = open(p).read()
# match the actual color union line regardless of exact members
m = re.search(r'  color: "amber"[^;]*;', src)
if m:
    src = src.replace(m.group(0), "  color: string; // key into COLOR_MAP", 1)
    open(p, "w").write(src); print("   ✓ color widened to string")
else:
    print("   ⊙ color already string")
PYEOF

# ----------------------------------------------------------------------------
# 3. Add LEDGER-12 to the agents list
# ----------------------------------------------------------------------------
echo "✏️  Adding LEDGER-12 to lib/agents.ts"
python3 - <<'PYEOF'
import re
p = "lib/agents.ts"; src = open(p).read()
if 'id: "ledger-12"' in src:
    print("   ⊙ already present")
else:
    m = re.search(r'import \{([^}]*)\} from "lucide-react";', src)
    if m and "Scale" not in m.group(1):
        src = src.replace(m.group(0), f'import {{{m.group(1).rstrip()}, Scale}} from "lucide-react";', 1)
    ledger = '''  {
    id: "ledger-12",
    name: "LEDGER-12",
    shortName: "Ledger",
    role: "Finance & Operations",
    tagline: "Give me the numbers, or the goal, and I'll model the path.",
    model: "claude-sonnet-4-6",
    status: "online", load: 14, color: "ledgergreen", icon: Scale,
    tokens: 0, latency: 0, tasks: 0,
    systemPrompt: "You are LEDGER-12, the Finance & Operations agent of the AEGIS fleet. You think like a sharp, pragmatic CFO and financial analyst. Your lane is the numbers behind the business: unit economics, pricing strategy and analysis, subscription metrics (MRR, ARR, churn, LTV, CAC), runway and burn, cost analysis (including software/API spend), financial projections, and scenario modeling. Be quantitative and precise. When you model something, state your assumptions explicitly and show the math so it can be checked. Ask for the specific numbers you need rather than inventing them — never fabricate financial figures. Offer scenarios (conservative / base / optimistic) where useful. When project context is provided, ground your analysis in that project's real pricing, audience, and goals. You analyze and model; you are not connected to live financial accounts, so when current actuals are needed, ask the user to provide them.",
    capabilities: [
      { name: "Unit Economics", level: 95 },
      { name: "Pricing Analysis", level: 93 },
      { name: "Subscription Metrics", level: 93 },
      { name: "Financial Modeling", level: 92 },
      { name: "Cost & Runway", level: 90 },
    ],
    specialties: ["Unit economics & LTV/CAC", "Pricing strategy", "MRR / ARR / churn modeling", "Runway & burn analysis", "Cost analysis (incl. API spend)", "Scenario projections"],
    history: [
      { ts: "now", title: "LEDGER-12 finance core initialized", result: "success" },
    ],
    greeting: "Ledger online. Give me the numbers, or the goal, and I'll model the path.",
    joinedAt: "Week 10",
  },
'''
    # insert before the array terminator. Find the AGENTS array close.
    m2 = re.search(r'\n\];\n', src)
    # ensure we insert before the FIRST top-level "];" that closes AGENTS
    idx = src.find("\n];\n")
    if idx != -1:
        src = src[:idx] + "\n" + ledger + src[idx+1:]
        open(p, "w").write(src); print("   ✓ LEDGER-12 added")
    else:
        print("   ⚠ couldn't find AGENTS terminator")
PYEOF

# ----------------------------------------------------------------------------
# 4. Add LEDGER sigil (balanced scales) to AgentAvatar
# ----------------------------------------------------------------------------
echo "✏️  Adding LEDGER sigil to components/AgentAvatar.tsx"
python3 - <<'PYEOF'
p = "components/AgentAvatar.tsx"; src = open(p).read()
if '"ledger-12"' in src:
    print("   ⊙ already present")
else:
    sigil = '''
  // LEDGER: balanced scales — finance & operations
  "ledger-12": {
    color: "ledgergreen",
    glyph: (hex, id, animated) => (
      <g stroke={hex} fill="none" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
        {/* central beam + post */}
        <line x1="50" y1="28" x2="50" y2="68" />
        <line x1="30" y1="36" x2="70" y2="36" />
        <circle cx="50" cy="28" r="2.5" fill={hex} stroke="none" />
        <line x1="38" y1="70" x2="62" y2="70" />
        {/* left pan */}
        {animated ? (
          <motion.g animate={{ rotate: [0, 3, 0, -3, 0] }} transition={{ duration: 4, repeat: Infinity }} style={{ transformOrigin: "50px 36px" }}>
            <line x1="30" y1="36" x2="24" y2="52" />
            <line x1="30" y1="36" x2="36" y2="52" />
            <path d="M24 52 Q30 60 36 52" strokeOpacity="0.85" />
            <line x1="70" y1="36" x2="64" y2="52" />
            <line x1="70" y1="36" x2="76" y2="52" />
            <path d="M64 52 Q70 60 76 52" strokeOpacity="0.85" />
          </motion.g>
        ) : (
          <g>
            <line x1="30" y1="36" x2="24" y2="52" />
            <line x1="30" y1="36" x2="36" y2="52" />
            <path d="M24 52 Q30 60 36 52" strokeOpacity="0.85" />
            <line x1="70" y1="36" x2="64" y2="52" />
            <line x1="70" y1="36" x2="76" y2="52" />
            <path d="M64 52 Q70 60 76 52" strokeOpacity="0.85" />
          </g>
        )}
      </g>
    ),
  },
'''
    anchor = 'const SIGILS: Record<string, { color: AgentColor; glyph: (hex: string, id: string, animated: boolean) => JSX.Element }> = {'
    if anchor in src:
        src = src.replace(anchor, anchor + "\n" + sigil, 1)
        open(p, "w").write(src); print("   ✓ LEDGER sigil added (scales)")
    else:
        print("   ⚠ SIGILS anchor not found; LEDGER uses fallback sigil")
PYEOF

echo ""
echo "✅ LEDGER-12 added."
echo ""
echo "Restart:  aegis-control restart"
echo ""
echo "LEDGER-12 appears as the 12th agent (deep green, scales sigil)."
echo "Claude Sonnet 4.6 — existing Anthropic key, no new credentials."
echo "Finance & Operations: unit economics, pricing, MRR/ARR, runway, cost analysis, modeling."
echo "It inherits context — select a project, ask LEDGER to model its economics."
echo ""
echo "Note: LEDGER analyzes and models; it is NOT connected to live financial data."
echo "Give it the actuals when current numbers are needed."
echo ""
echo "Backups in .pre-ledger-backup/ — revert: cp -r .pre-ledger-backup/* ."
