#!/usr/bin/env bash
# apply-dropdown-zindex-fix-patch.sh
# Real fix for the mobile dropdown being covered by the page content (the LIVE
# COGNITION card painting over the lower projects). Root cause: the page's content
# cards are Framer Motion elements with transforms, which create stacking contexts
# that competed with the switcher dropdown's z-50 (trapped inside the StatusBar's
# local context). Fix: promote the StatusBar to a high-z, isolated stacking context
# so its dropdown always renders above the main content. Also lift the dropdown's
# own z for good measure. Built/verified against the real repo.
set -e
if [ ! -f components/StatusBar.tsx ] || [ ! -f components/ProjectSwitcher.tsx ]; then
  echo "❌ Run from inside the aegis project directory."; exit 1
fi

echo "📦 Backing up to .pre-zfix-backup/"
mkdir -p .pre-zfix-backup/components
cp components/StatusBar.tsx       .pre-zfix-backup/components/
cp components/ProjectSwitcher.tsx .pre-zfix-backup/components/

# ----------------------------------------------------------------------------
# 1. StatusBar root: make it a high-z, isolated, sticky stacking context so its
#    dropdown outranks the transformed content cards in <main>.
# ----------------------------------------------------------------------------
echo "✏️  Promoting StatusBar to a top stacking context (StatusBar.tsx)"
python3 - <<'PYEOF'
p = "components/StatusBar.tsx"; src = open(p).read()
old = 'className="flex items-center justify-between border-b border-white/[0.06] px-6 py-3 text-[10px] tracking-[0.22em] text-white/50 font-mono backdrop-blur-xl bg-black/20"'
new = 'className="sticky top-0 isolate z-[100] flex items-center justify-between border-b border-white/[0.06] px-6 py-3 text-[10px] tracking-[0.22em] text-white/50 font-mono backdrop-blur-xl bg-black/40"'
if old in src:
    src = src.replace(old, new, 1); open(p, "w").write(src)
    print("   ✓ StatusBar is now sticky + isolated + z-[100] (bg slightly more opaque)")
elif "isolate z-[100]" in src:
    print("   ⊙ already promoted")
else:
    print("   ⚠ StatusBar root class not in expected form")
PYEOF

# ----------------------------------------------------------------------------
# 2. Dropdown panel: lift z above any sibling just in case (z-50 -> z-[120]).
# ----------------------------------------------------------------------------
echo "✏️  Lifting dropdown panel z-index (ProjectSwitcher.tsx)"
python3 - <<'PYEOF'
p = "components/ProjectSwitcher.tsx"; src = open(p).read()
if "shadow-2xl z-50 overflow-hidden" in src:
    src = src.replace("shadow-2xl z-50 overflow-hidden", "shadow-2xl z-[120] overflow-hidden", 1)
    open(p, "w").write(src); print("   ✓ dropdown panel z-50 -> z-[120]")
elif "z-[120]" in src:
    print("   ⊙ already lifted")
else:
    print("   ⚠ dropdown panel z class not found")
PYEOF

echo ""
echo "✅ Dropdown stacking fix applied."
echo ""
echo "Restart:  aegis-control restart"
echo ""
echo "Root cause was z-index/stacking: the animated content cards (Framer Motion"
echo "transforms) created stacking contexts that painted over the dropdown's lower"
echo "rows. The StatusBar is now an isolated high-z sticky context, so its dropdown"
echo "always renders above the page content. The list still scrolls internally."
echo ""
echo "Backups in .pre-zfix-backup/ — revert: cp -r .pre-zfix-backup/* ."
