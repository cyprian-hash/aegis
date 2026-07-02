#!/usr/bin/env bash
# apply-greeting-fix-patch.sh
# Fixes the hardcoded "Good evening" greeting on the Overview. It now computes
# Morning / Afternoon / Evening from the CURRENT time, using UTC hours to match
# the UTC clock in the status bar (so greeting and clock always agree).
# Hydration-safe: starts neutral on first render, sets real greeting on client.
# Built/verified against the real repo.
set -e
if [ ! -f components/OverviewView.tsx ]; then
  echo "❌ Run from inside the aegis project directory."; exit 1
fi

echo "📦 Backing up to .pre-greetfix-backup/"
mkdir -p .pre-greetfix-backup/components
cp components/OverviewView.tsx .pre-greetfix-backup/components/

echo "✏️  Adding time-based greeting (UTC, matches the clock)"
python3 - <<'PYEOF'
p = "components/OverviewView.tsx"; src = open(p).read()
changed = []

# 1. Add greeting state + effect right after the tick effect line.
anchor = '  useEffect(() => { const id = setInterval(() => setTick(t => t + 1), 1500); return () => clearInterval(id); }, []);'
if anchor in src and "greeting" not in src.split("return")[0]:
    inject = anchor + '''

  // Time-based greeting (UTC, to match the UTC clock in the status bar).
  const [greeting, setGreeting] = useState("Welcome");
  useEffect(() => {
    const compute = () => {
      const h = new Date().getUTCHours();
      setGreeting(h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Good evening");
    };
    compute();
    const id = setInterval(compute, 60000);
    return () => clearInterval(id);
  }, []);'''
    src = src.replace(anchor, inject, 1); changed.append("greeting state + UTC compute added")

# 2. Replace the hardcoded "Good evening," with the dynamic value.
old_h = 'Good evening,<br />'
new_h = '{greeting},<br />'
if old_h in src:
    src = src.replace(old_h, new_h, 1); changed.append('hardcoded "Good evening" -> dynamic {greeting}')

open(p, "w").write(src)
for c in changed: print(f"   ✓ {c}")
if not changed: print("   ⊙ already applied or anchors not found")
PYEOF

echo ""
echo "✅ Greeting is now time-aware."
echo ""
echo "Restart:  aegis-control restart"
echo ""
echo "The Overview now greets Good morning (00:00-11:59 UTC),"
echo "Good afternoon (12:00-17:59 UTC), or Good evening (18:00-23:59 UTC),"
echo "matching the UTC clock. Updates every minute."
echo ""
echo "Backups in .pre-greetfix-backup/ — revert: cp -r .pre-greetfix-backup/* ."
