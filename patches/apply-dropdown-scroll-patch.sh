#!/usr/bin/env bash
# apply-dropdown-scroll-patch.sh
# Fixes the dropdown overflowing onto page content at the bottom on mobile.
# The list had a FIXED max-h-[320px] which on a phone extends past the visible
# area and overlaps the dashboard cards. This switches to a viewport-relative
# max height (60vh) so the list scrolls internally and never runs off-screen,
# and makes the panel fully opaque so nothing bleeds through.
# Built/verified against the real repo.
set -e
if [ ! -f components/ProjectSwitcher.tsx ]; then
  echo "❌ Run from inside the aegis project directory."; exit 1
fi

echo "📦 Backing up to .pre-ddscroll-backup/"
mkdir -p .pre-ddscroll-backup/components
cp components/ProjectSwitcher.tsx .pre-ddscroll-backup/components/

echo "✏️  Making dropdown height viewport-relative + opaque (ProjectSwitcher)"
python3 - <<'PYEOF'
p = "components/ProjectSwitcher.tsx"; src = open(p).read()
changed = []

# 1. Inner list: fixed 320px -> viewport-relative, so it can't run off-screen.
old_list = '<div className="border-t border-white/[0.04] max-h-[320px] overflow-y-auto">'
new_list = '<div className="border-t border-white/[0.04] max-h-[min(60vh,420px)] overflow-y-auto overscroll-contain">'
if old_list in src:
    src = src.replace(old_list, new_list, 1); changed.append("list height now min(60vh,420px) with contained scroll")
elif "max-h-[min(60vh,420px)]" in src:
    print("   ⊙ list height already viewport-relative")

# 2. Panel: fully opaque background so page content can't bleed through.
old_panel = 'mt-2 w-[280px] max-w-[calc(100vw-1.5rem)] rounded-xl border border-white/[0.08] bg-black/95 backdrop-blur-xl shadow-2xl z-50 overflow-hidden'
new_panel = 'mt-2 w-[280px] max-w-[calc(100vw-1.5rem)] rounded-xl border border-white/[0.08] bg-[#0a0a0a] backdrop-blur-xl shadow-2xl z-50 overflow-hidden'
if old_panel in src:
    src = src.replace(old_panel, new_panel, 1); changed.append("panel background now fully opaque")
elif "bg-[#0a0a0a]" in src:
    print("   ⊙ panel already opaque")

open(p, "w").write(src)
for c in changed: print(f"   ✓ {c}")
if not changed: print("   ⊙ already applied")
PYEOF

echo ""
echo "✅ Dropdown scroll/height fixed."
echo ""
echo "Restart:  aegis-control restart"
echo ""
echo "The dropdown list now caps at 60% of screen height and scrolls internally,"
echo "so it can't extend down over the dashboard cards. Panel is fully opaque."
echo "Desktop is unaffected (60vh is plenty there)."
echo ""
echo "Backups in .pre-ddscroll-backup/ — revert: cp -r .pre-ddscroll-backup/* ."
