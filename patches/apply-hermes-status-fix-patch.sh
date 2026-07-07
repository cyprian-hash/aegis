#!/usr/bin/env bash
# apply-hermes-status-fix-patch.sh
# Fixes the misleading "Hermes is not installed on this machine" prompt.
# Root cause: the status route used `which hermes`, but the AEGIS server runs
# under a LaunchAgent with a minimal PATH, so `which` fails even though Hermes
# is installed and its gateway is running on 8642. Fix:
#   1) A running gateway now counts as installed (it's the truest signal).
#   2) Version lookup falls back to common install paths (PATH-independent).
# Built/verified against the real repo.
set -e
if [ ! -f app/api/hermes/status/route.ts ]; then
  echo "❌ Run from inside the aegis project directory."; exit 1
fi

echo "📦 Backing up to .pre-hermesfix-backup/"
mkdir -p .pre-hermesfix-backup/app/api/hermes/status
cp app/api/hermes/status/route.ts .pre-hermesfix-backup/app/api/hermes/status/

echo "✏️  Fixing installed-detection in hermes status route"
python3 - <<'PYEOF'
p = "app/api/hermes/status/route.ts"; src = open(p).read()
changed = []

# 1. Version lookup: try common absolute paths when `which` fails (LaunchAgent PATH).
old_fn = '''async function getInstalledVersion(): Promise<{ version: string | null; path: string | null }> {
  try {
    const { stdout: pathOut } = await execAsync("which hermes", { timeout: 3000 });
    const hermesPath = pathOut.trim() || null;
    if (!hermesPath) return { version: null, path: null };'''
new_fn = '''async function getInstalledVersion(): Promise<{ version: string | null; path: string | null }> {
  try {
    // `which` can fail under LaunchAgent (minimal PATH), so also try common paths.
    let hermesPath: string | null = null;
    try {
      const { stdout: pathOut } = await execAsync("which hermes", { timeout: 3000 });
      hermesPath = pathOut.trim() || null;
    } catch {}
    if (!hermesPath) {
      const home = process.env.HOME || "";
      const candidates = [
        `${home}/.local/bin/hermes`,
        "/opt/homebrew/bin/hermes",
        "/usr/local/bin/hermes",
        `${home}/.hermes/bin/hermes`,
      ];
      for (const c of candidates) {
        try { await execAsync(`test -x "${c}"`, { timeout: 1500 }); hermesPath = c; break; } catch {}
      }
    }
    if (!hermesPath) return { version: null, path: null };'''
if old_fn in src:
    src = src.replace(old_fn, new_fn, 1); changed.append("version lookup falls back to common install paths")

# The version command must use the resolved path, not bare `hermes`.
old_ver = 'const { stdout } = await execAsync("hermes --version 2>&1 | head -3", { timeout: 5000 });'
new_ver = 'const { stdout } = await execAsync(`"${hermesPath}" --version 2>&1 | head -3`, { timeout: 5000 });'
if old_ver in src:
    src = src.replace(old_ver, new_ver, 1); changed.append("version command uses resolved path")

# 2. installed = binary found OR gateway running (gateway is the truest signal).
old_inst = "    installed: !!installedVersion,"
new_inst = "    installed: !!installedVersion || gatewayRunning,"
if old_inst in src:
    src = src.replace(old_inst, new_inst, 1); changed.append("running gateway now counts as installed")

open(p, "w").write(src)
for c in changed: print(f"   ✓ {c}")
if not changed: print("   ⊙ already applied or anchors not found")
PYEOF

echo ""
echo "✅ Hermes status detection fixed."
echo ""
echo "Restart:  aegis-control restart"
echo ""
echo "The panel will no longer claim Hermes is missing while the gateway is"
echo "running. If the binary is outside the server PATH, version may show as"
echo "unknown but the running state is correctly detected via the gateway."
echo ""
echo "Backups in .pre-hermesfix-backup/ — revert: cp -r .pre-hermesfix-backup/* ."
