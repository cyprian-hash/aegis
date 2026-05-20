#!/usr/bin/env bash
# Auto-start launcher for Hermes gateway (called by LaunchAgent)
# Binds to localhost only — AEGIS reaches Hermes via localhost since they're on the same Mac.
set -e
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
exec "/Users/cypmacmini/.local/bin/hermes" gateway
