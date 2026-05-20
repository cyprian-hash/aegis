#!/usr/bin/env bash
# Auto-start launcher for AEGIS (called by LaunchAgent)
set -e
cd "/Users/cypmacmini/projects/aegis"
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
# Listen on all interfaces so MacBook / iPhone can reach it on Wi-Fi
exec "/opt/homebrew/bin/npm" run dev -- -H 0.0.0.0 -p 3000
