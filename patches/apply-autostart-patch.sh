#!/usr/bin/env bash
# apply-autostart-patch.sh
#
# Installs LaunchAgents so AEGIS + Hermes auto-start on login and stay running.
# Designed for the Mac mini (the primary, always-on host).
# Also configures AEGIS to bind to 0.0.0.0 so other devices on your LAN can reach it.
#
# Run from inside the aegis project directory:
#   bash apply-autostart-patch.sh

set -e

if [ ! -f package.json ] || [ ! -d components ]; then
  echo "❌ Run from inside the aegis project directory."
  exit 1
fi

if [ -t 1 ]; then
  BOLD=$(tput bold); DIM=$(tput dim); RESET=$(tput sgr0)
  AMBER=$(tput setaf 3); CYAN=$(tput setaf 6); GREEN=$(tput setaf 2); RED=$(tput setaf 1)
else
  BOLD=""; DIM=""; RESET=""; AMBER=""; CYAN=""; GREEN=""; RED=""
fi
say() { echo "${1}${2}${RESET}"; }
die() { say "$RED" "❌ $1"; exit 1; }

AEGIS_DIR="$(pwd)"
USER_HOME="$HOME"
LOGS_DIR="$USER_HOME/Library/Logs/aegis"
LAUNCH_AGENTS_DIR="$USER_HOME/Library/LaunchAgents"
SCRIPTS_DIR="$AEGIS_DIR/scripts"

# Check prerequisites
command -v npm >/dev/null 2>&1 || die "npm not found — install Node first"
command -v node >/dev/null 2>&1 || die "node not found"
NODE_BIN="$(command -v node)"
NPM_BIN="$(command -v npm)"
HERMES_BIN="$(command -v hermes || true)"

say "$DIM" "Detected:"
say "$DIM" "  node:   $NODE_BIN"
say "$DIM" "  npm:    $NPM_BIN"
say "$DIM" "  hermes: ${HERMES_BIN:-not installed (skipping Hermes auto-start)}"
echo ""

mkdir -p "$LOGS_DIR" "$LAUNCH_AGENTS_DIR" "$SCRIPTS_DIR"

# -----------------------------------------------------------------------------
# 1. Wrapper script: starts AEGIS with proper env
# -----------------------------------------------------------------------------
say "$CYAN$BOLD" "[1/5] Writing AEGIS launcher script"
cat > "$SCRIPTS_DIR/aegis-start.sh" <<EOF
#!/usr/bin/env bash
# Auto-start launcher for AEGIS (called by LaunchAgent)
set -e
cd "$AEGIS_DIR"
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:\$PATH"
# Listen on all interfaces so MacBook / iPhone can reach it on Wi-Fi
exec "$NPM_BIN" run dev -- -H 0.0.0.0 -p 3000
EOF
chmod +x "$SCRIPTS_DIR/aegis-start.sh"
say "$GREEN" "   ✓ scripts/aegis-start.sh"

# -----------------------------------------------------------------------------
# 2. Wrapper script: Hermes gateway (localhost only, security)
# -----------------------------------------------------------------------------
if [ -n "$HERMES_BIN" ]; then
  say "$CYAN$BOLD" "[2/5] Writing Hermes gateway launcher"
  cat > "$SCRIPTS_DIR/hermes-start.sh" <<EOF
#!/usr/bin/env bash
# Auto-start launcher for Hermes gateway (called by LaunchAgent)
# Binds to localhost only — AEGIS reaches Hermes via localhost since they're on the same Mac.
set -e
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:\$PATH"
exec "$HERMES_BIN" gateway
EOF
  chmod +x "$SCRIPTS_DIR/hermes-start.sh"
  say "$GREEN" "   ✓ scripts/hermes-start.sh"
else
  say "$DIM" "[2/5] Skipping Hermes launcher — not installed"
fi

# -----------------------------------------------------------------------------
# 3. LaunchAgent plist for AEGIS
# -----------------------------------------------------------------------------
say "$CYAN$BOLD" "[3/5] Writing LaunchAgent plists"
AEGIS_PLIST="$LAUNCH_AGENTS_DIR/com.aegis.dev.plist"
cat > "$AEGIS_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.aegis.dev</string>

    <key>ProgramArguments</key>
    <array>
        <string>$SCRIPTS_DIR/aegis-start.sh</string>
    </array>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
        <key>Crashed</key>
        <true/>
    </dict>

    <key>ThrottleInterval</key>
    <integer>30</integer>

    <key>StandardOutPath</key>
    <string>$LOGS_DIR/aegis.log</string>

    <key>StandardErrorPath</key>
    <string>$LOGS_DIR/aegis.err.log</string>

    <key>WorkingDirectory</key>
    <string>$AEGIS_DIR</string>

    <key>EnvironmentVariables</key>
    <dict>
        <key>NODE_ENV</key>
        <string>development</string>
        <key>HOME</key>
        <string>$USER_HOME</string>
    </dict>

    <key>ProcessType</key>
    <string>Interactive</string>
</dict>
</plist>
EOF
say "$GREEN" "   ✓ ~/Library/LaunchAgents/com.aegis.dev.plist"

if [ -n "$HERMES_BIN" ]; then
  HERMES_PLIST="$LAUNCH_AGENTS_DIR/com.hermes.gateway.plist"
  cat > "$HERMES_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.hermes.gateway</string>

    <key>ProgramArguments</key>
    <array>
        <string>$SCRIPTS_DIR/hermes-start.sh</string>
    </array>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
        <key>Crashed</key>
        <true/>
    </dict>

    <key>ThrottleInterval</key>
    <integer>30</integer>

    <key>StandardOutPath</key>
    <string>$LOGS_DIR/hermes.log</string>

    <key>StandardErrorPath</key>
    <string>$LOGS_DIR/hermes.err.log</string>

    <key>EnvironmentVariables</key>
    <dict>
        <key>HOME</key>
        <string>$USER_HOME</string>
    </dict>

    <key>ProcessType</key>
    <string>Interactive</string>
</dict>
</plist>
EOF
  say "$GREEN" "   ✓ ~/Library/LaunchAgents/com.hermes.gateway.plist"
fi

# -----------------------------------------------------------------------------
# 4. Control script
# -----------------------------------------------------------------------------
say "$CYAN$BOLD" "[4/5] Writing aegis-control script"
cat > "$SCRIPTS_DIR/aegis-control.sh" <<'EOF'
#!/usr/bin/env bash
# aegis-control — start/stop/restart/status/logs for AEGIS + Hermes LaunchAgents
set -e

if [ -t 1 ]; then
  BOLD=$(tput bold); DIM=$(tput dim); RESET=$(tput sgr0)
  GREEN=$(tput setaf 2); RED=$(tput setaf 1); AMBER=$(tput setaf 3)
else BOLD=""; DIM=""; RESET=""; GREEN=""; RED=""; AMBER=""; fi

LOGS_DIR="$HOME/Library/Logs/aegis"
AEGIS_LABEL="com.aegis.dev"
HERMES_LABEL="com.hermes.gateway"
AEGIS_PLIST="$HOME/Library/LaunchAgents/$AEGIS_LABEL.plist"
HERMES_PLIST="$HOME/Library/LaunchAgents/$HERMES_LABEL.plist"

status_one() {
  local label="$1"
  local plist="$2"
  if [ ! -f "$plist" ]; then
    echo "  ${DIM}$label: not installed${RESET}"
    return
  fi
  local info=$(launchctl list | awk -v l="$label" '$3==l {print $1, $2}')
  if [ -z "$info" ]; then
    echo "  ${AMBER}$label: not loaded${RESET}"
  else
    local pid=$(echo "$info" | awk '{print $1}')
    local last_exit=$(echo "$info" | awk '{print $2}')
    if [ "$pid" = "-" ]; then
      echo "  ${RED}$label: stopped (last exit: $last_exit)${RESET}"
    else
      echo "  ${GREEN}$label: running (pid $pid)${RESET}"
    fi
  fi
}

cmd_status() {
  echo "${BOLD}AEGIS Control Center Status${RESET}"
  status_one "$AEGIS_LABEL" "$AEGIS_PLIST"
  status_one "$HERMES_LABEL" "$HERMES_PLIST"
  echo ""
  echo "${DIM}URL:    http://localhost:3000${RESET}"
  echo "${DIM}Logs:   $LOGS_DIR${RESET}"
}

cmd_start() {
  [ -f "$AEGIS_PLIST" ]  && launchctl load -w "$AEGIS_PLIST"  2>/dev/null && echo "${GREEN}✓ AEGIS started${RESET}"  || echo "${DIM}⊙ AEGIS already loaded or not installed${RESET}"
  [ -f "$HERMES_PLIST" ] && launchctl load -w "$HERMES_PLIST" 2>/dev/null && echo "${GREEN}✓ Hermes started${RESET}" || echo "${DIM}⊙ Hermes already loaded or not installed${RESET}"
}

cmd_stop() {
  [ -f "$AEGIS_PLIST" ]  && launchctl unload "$AEGIS_PLIST"  2>/dev/null && echo "${AMBER}■ AEGIS stopped${RESET}"  || true
  [ -f "$HERMES_PLIST" ] && launchctl unload "$HERMES_PLIST" 2>/dev/null && echo "${AMBER}■ Hermes stopped${RESET}" || true
}

cmd_restart() {
  cmd_stop
  sleep 1
  cmd_start
}

cmd_logs() {
  local which="${1:-aegis}"
  case "$which" in
    aegis)  tail -F "$LOGS_DIR/aegis.log"  "$LOGS_DIR/aegis.err.log"  ;;
    hermes) tail -F "$LOGS_DIR/hermes.log" "$LOGS_DIR/hermes.err.log" ;;
    all)    tail -F "$LOGS_DIR"/*.log ;;
    *) echo "Usage: aegis-control logs [aegis|hermes|all]"; exit 1 ;;
  esac
}

cmd_help() {
  cat <<HELP
${BOLD}aegis-control${RESET} — control AEGIS + Hermes background services

Usage:
  aegis-control start             Start both services
  aegis-control stop              Stop both services
  aegis-control restart           Stop, then start
  aegis-control status            Show running state
  aegis-control logs [target]     Tail logs (target: aegis | hermes | all)
  aegis-control help              Show this help

Plists:
  $AEGIS_PLIST
  $HERMES_PLIST

Logs:
  $LOGS_DIR
HELP
}

case "${1:-help}" in
  start)   cmd_start ;;
  stop)    cmd_stop ;;
  restart) cmd_restart ;;
  status)  cmd_status ;;
  logs)    cmd_logs "${2:-aegis}" ;;
  help|*)  cmd_help ;;
esac
EOF
chmod +x "$SCRIPTS_DIR/aegis-control.sh"
say "$GREEN" "   ✓ scripts/aegis-control.sh"

# Create a symlink in /usr/local/bin if possible, so `aegis-control` works anywhere
if [ -w "/usr/local/bin" ]; then
  ln -sf "$SCRIPTS_DIR/aegis-control.sh" /usr/local/bin/aegis-control 2>/dev/null || true
  say "$DIM" "   linked → /usr/local/bin/aegis-control"
else
  say "$DIM" "   (no write access to /usr/local/bin — call it as $SCRIPTS_DIR/aegis-control.sh)"
fi

# -----------------------------------------------------------------------------
# 5. Uninstaller
# -----------------------------------------------------------------------------
say "$CYAN$BOLD" "[5/5] Writing uninstaller"
cat > "$SCRIPTS_DIR/uninstall-autostart.sh" <<'EOF'
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
EOF
chmod +x "$SCRIPTS_DIR/uninstall-autostart.sh"
say "$GREEN" "   ✓ scripts/uninstall-autostart.sh"

# -----------------------------------------------------------------------------
# Load the agents
# -----------------------------------------------------------------------------
echo ""
say "$CYAN$BOLD" "Loading LaunchAgents…"
launchctl unload "$AEGIS_PLIST" 2>/dev/null || true
launchctl load -w "$AEGIS_PLIST"
say "$GREEN" "   ✓ AEGIS LaunchAgent loaded"

if [ -n "$HERMES_BIN" ]; then
  launchctl unload "$HERMES_PLIST" 2>/dev/null || true
  launchctl load -w "$HERMES_PLIST"
  say "$GREEN" "   ✓ Hermes LaunchAgent loaded"
fi

echo ""
say "$GREEN$BOLD" "✅ Auto-start installed."
echo ""
say "$BOLD" "What happens now:"
echo "   • AEGIS auto-starts on login at http://localhost:3000"
echo "   • Hermes gateway auto-starts at http://localhost:8642 (localhost only — secure)"
echo "   • Both auto-restart if they crash"
echo "   • Logs land in ~/Library/Logs/aegis/"
echo ""
say "$BOLD" "Control commands:"
echo "   aegis-control status     # see what's running"
echo "   aegis-control restart    # bounce both services"
echo "   aegis-control logs       # tail AEGIS logs"
echo "   aegis-control logs hermes"
echo "   aegis-control stop       # stop everything"
echo "   aegis-control start      # start everything"
echo ""
say "$BOLD" "Find your Mac mini's IP for reaching from MacBook on Wi-Fi:"
echo "   ipconfig getifaddr en0   # Wi-Fi"
echo "   ipconfig getifaddr en1   # Ethernet (Mac mini wired)"
echo ""
say "$DIM" "Give it ~10 seconds for the first startup to complete, then:"
say "$DIM" "   curl http://localhost:3000  # should return HTML"
echo ""
say "$DIM" "To uninstall: bash scripts/uninstall-autostart.sh"
