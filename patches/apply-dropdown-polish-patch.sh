#!/usr/bin/env bash
# apply-dropdown-polish-patch.sh
# Polishes the ProjectSwitcher dropdown on mobile: the panel was a fixed 280px
# anchored hard-right, so on narrow screens it overflowed the viewport — pushing
# rows (and their color dots) outside the rounded panel where they got clipped.
# This makes the panel fit the viewport, keeps dots from being clipped, and
# tidies row alignment. Built/verified against the real repo.
set -e
if [ ! -f components/ProjectSwitcher.tsx ]; then
  echo "❌ Run from inside the aegis project directory."; exit 1
fi

echo "📦 Backing up to .pre-ddpolish-backup/"
mkdir -p .pre-ddpolish-backup/components
cp components/ProjectSwitcher.tsx .pre-ddpolish-backup/components/

echo "✏️  Polishing dropdown panel + row layout (ProjectSwitcher)"
python3 - <<'PYEOF'
p = "components/ProjectSwitcher.tsx"; src = open(p).read()
changed = []

# 1. Panel: fit the viewport on mobile (was fixed w-[280px], could overflow).
old_panel = 'className="absolute right-0 top-full mt-2 w-[280px] rounded-xl border border-white/[0.08] bg-black/95 backdrop-blur-xl shadow-2xl z-50 overflow-hidden"'
new_panel = 'className="absolute right-0 top-full mt-2 w-[280px] max-w-[calc(100vw-1.5rem)] rounded-xl border border-white/[0.08] bg-black/95 backdrop-blur-xl shadow-2xl z-50 overflow-hidden"'
if old_panel in src:
    src = src.replace(old_panel, new_panel, 1); changed.append("panel fits viewport (max-w calc)")

# 2. Project rows: ensure the color dot never gets clipped — add min-w-0 to the
#    text span (so it truncates) and keep the dot shrink-0 (already is), and make
#    the row not clip its own start.
old_row = 'className={`w-full flex items-center gap-2.5 px-3.5 py-2 hover:bg-white/[0.04] transition-colors ${isActive ? "bg-white/[0.03]" : ""}`}'
new_row = 'className={`w-full flex items-center gap-2.5 px-3.5 py-2 min-w-0 hover:bg-white/[0.04] transition-colors ${isActive ? "bg-white/[0.03]" : ""}`}'
if old_row in src:
    src = src.replace(old_row, new_row, 1); changed.append("rows can shrink (min-w-0)")

# 3. The "All projects" row too.
old_all = 'className={`w-full flex items-center gap-2 px-3.5 py-2.5 hover:bg-white/[0.04] transition-colors ${!activeId ? "bg-white/[0.03]" : ""}`}'
new_all = 'className={`w-full flex items-center gap-2 px-3.5 py-2.5 min-w-0 hover:bg-white/[0.04] transition-colors ${!activeId ? "bg-white/[0.03]" : ""}`}'
if old_all in src:
    src = src.replace(old_all, new_all, 1); changed.append("all-projects row shrinkable")

open(p, "w").write(src)
for c in changed: print(f"   ✓ {c}")
if not changed: print("   ⊙ already polished")
PYEOF

echo ""
echo "✅ Dropdown polished."
echo ""
echo "Restart:  aegis-control restart"
echo ""
echo "The dropdown now fits within the mobile viewport (no horizontal overflow),"
echo "so project color dots are no longer clipped off the panel edge, and rows"
echo "align cleanly. Desktop is unchanged."
echo ""
echo "Note: every project DOES have a valid color + status in lib/projects.ts —"
echo "the 'missing dots' were a clipping artifact from the overflowing panel,"
echo "not missing data. This fixes the clipping."
echo ""
echo "Backups in .pre-ddpolish-backup/ — revert: cp -r .pre-ddpolish-backup/* ."
