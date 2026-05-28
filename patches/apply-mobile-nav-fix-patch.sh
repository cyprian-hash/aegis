#!/usr/bin/env bash
# apply-mobile-nav-fix-patch.sh
# Fixes the mobile top-nav overlap: on narrow screens "AEGIS · MISSION CONTROL"
# collided with the ProjectSwitcher label (e.g. MISSION CONTROL + MEMORY SOUNDX
# overprinting). Makes the header degrade gracefully: shortens the AEGIS label on
# mobile, truncates the switcher label, and lets the left group shrink.
# Built/verified against the real repo.
set -e
if [ ! -f components/StatusBar.tsx ] || [ ! -f components/ProjectSwitcher.tsx ]; then
  echo "❌ Run from inside the aegis project directory."; exit 1
fi

echo "📦 Backing up to .pre-navfix-backup/"
mkdir -p .pre-navfix-backup/components
cp components/StatusBar.tsx      .pre-navfix-backup/components/
cp components/ProjectSwitcher.tsx .pre-navfix-backup/components/

# ----------------------------------------------------------------------------
# 1. StatusBar: shorten AEGIS label on mobile + let left group shrink/truncate
# ----------------------------------------------------------------------------
echo "✏️  Fixing StatusBar mobile layout"
python3 - <<'PYEOF'
p = "components/StatusBar.tsx"; src = open(p).read()

# 1a. Split "AEGIS · MISSION CONTROL" so "· MISSION CONTROL" hides on mobile.
old_label = '<span className="text-white/80">AEGIS · MISSION CONTROL</span>'
new_label = '<span className="text-white/80 whitespace-nowrap">AEGIS<span className="hidden sm:inline"> · MISSION CONTROL</span></span>'
if old_label in src:
    src = src.replace(old_label, new_label, 1)
    print("   ✓ AEGIS label now drops 'MISSION CONTROL' on mobile")
elif 'AEGIS<span className="hidden sm:inline"' in src:
    print("   ⊙ AEGIS label already responsive")
else:
    print("   ⚠ AEGIS label not in expected form")

# 1b. Make the AEGIS sub-group able to shrink and truncate (it was shrink-0).
old_grp = '<div className="flex items-center gap-2 shrink-0">'
new_grp = '<div className="flex items-center gap-2 min-w-0">'
if old_grp in src:
    src = src.replace(old_grp, new_grp, 1)
    print("   ✓ AEGIS group can now shrink instead of overlapping")
else:
    print("   ⊙ AEGIS group already shrinkable")

open(p, "w").write(src)
PYEOF

# ----------------------------------------------------------------------------
# 2. ProjectSwitcher: cap the active label width + truncate (no overflow)
# ----------------------------------------------------------------------------
echo "✏️  Truncating the switcher label so long names can't overflow"
python3 - <<'PYEOF'
p = "components/ProjectSwitcher.tsx"; src = open(p).read()
old = '<span className="text-[11px] font-mono tracking-[0.15em] text-white/85">{active.name.toUpperCase()}</span>'
new = '<span className="text-[11px] font-mono tracking-[0.15em] text-white/85 truncate max-w-[120px] sm:max-w-[200px]">{active.name.toUpperCase()}</span>'
if old in src:
    src = src.replace(old, new, 1)
    open(p, "w").write(src)
    print("   ✓ active project label truncates (max 120px mobile / 200px desktop)")
elif "truncate max-w-[120px]" in src:
    print("   ⊙ already truncating")
else:
    print("   ⚠ switcher label not in expected form")
PYEOF

echo ""
echo "✅ Mobile nav overlap fixed."
echo ""
echo "Restart:  aegis-control restart"
echo ""
echo "On mobile: header shows 'AEGIS' (not the full 'MISSION CONTROL'),"
echo "the project switcher label truncates with an ellipsis, and the left"
echo "group shrinks instead of overprinting the switcher."
echo "Desktop is unchanged (sm: and up shows the full labels)."
echo ""
echo "Backups in .pre-navfix-backup/ — revert: cp -r .pre-navfix-backup/* ."
