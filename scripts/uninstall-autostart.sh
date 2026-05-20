#!/usr/bin/env bash
# Removes AEGIS + Hermes LaunchAgents and stops the services.
set -e
AEGIS_PLIST="$HOME/Library/LaunchAgents/com.aegis.dev.plist"
HERMES_PLIST="$HOME/Library/LaunchAgents/com.hermes.gateway.plist"

echo "Stopping services…"
[ -f "$AEGIS_PLIST" ]  && launchctl unload "$AEGIS_PLIST"  2>/dev/null || true
[ -f "$HERMES_PLIST" ] && launchctl unload "$HERMES_PLIST" 2>/dev/null || true

echo "Removing LaunchAgents…"
rm -f "$AEGIS_PLIST" "$HERMES_PLIST"

echo "Removing aegis-control symlink (if present)…"
rm -f /usr/local/bin/aegis-control 2>/dev/null || true

echo "✓ Uninstalled. Logs in ~/Library/Logs/aegis/ are preserved."
echo "  Delete them manually if you want: rm -rf ~/Library/Logs/aegis"
