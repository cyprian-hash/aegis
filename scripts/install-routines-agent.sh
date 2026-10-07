#!/usr/bin/env bash
# One-time: installs the com.aegis.routines LaunchAgent (fires every 5 min).
set -e
REPO="$HOME/projects/aegis"
NODE_BIN="$(command -v node)"
if [ -z "$NODE_BIN" ]; then echo "node not found in PATH"; exit 1; fi
PLIST="$HOME/Library/LaunchAgents/com.aegis.routines.plist"
mkdir -p "$HOME/Library/Logs/aegis"
cat > "$PLIST" << PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.aegis.routines</string>
  <key>ProgramArguments</key>
  <array>
    <string>${NODE_BIN}</string>
    <string>${REPO}/scripts/routines-runner.mjs</string>
  </array>
  <key>WorkingDirectory</key><string>${REPO}</string>
  <key>StartInterval</key><integer>300</integer>
  <key>RunAtLoad</key><true/>
  <key>StandardOutPath</key><string>${HOME}/Library/Logs/aegis/routines.log</string>
  <key>StandardErrorPath</key><string>${HOME}/Library/Logs/aegis/routines.err.log</string>
</dict>
</plist>
PLISTEOF
launchctl unload "$PLIST" 2>/dev/null || true
launchctl load -w "$PLIST"
echo "✓ com.aegis.routines installed (every 5 min, node: ${NODE_BIN})"
echo "  Logs: ~/Library/Logs/aegis/routines.log"
echo "  Test one now:  node scripts/routines-runner.mjs --force ledger-daily-digest"
