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
