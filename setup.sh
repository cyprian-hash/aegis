#!/usr/bin/env bash
# setup.sh — Interactive setup wizard for AEGIS.
# Run from inside the aegis project directory: ./setup.sh

set -e

if [ -t 1 ]; then
  BOLD=$(tput bold) DIM=$(tput dim) RESET=$(tput sgr0)
  AMBER=$(tput setaf 3) CYAN=$(tput setaf 6) GREEN=$(tput setaf 2) GRAY=$(tput setaf 8)
else
  BOLD="" DIM="" RESET="" AMBER="" CYAN="" GREEN="" GRAY=""
fi
say() { echo "${1}${2}${RESET}"; }
ask() { printf "${BOLD}${AMBER}%s${RESET} " "$1"; read -r REPLY; }

if [ ! -f package.json ] || [ ! -d components ]; then
  say "$AMBER" "❌ Run this from inside the aegis project directory."
  exit 1
fi

clear 2>/dev/null || true
cat <<'BANNER'
   ╔══════════════════════════════════════════╗
   ║                                          ║
   ║      AEGIS // Mission Control Setup      ║
   ║                                          ║
   ╚══════════════════════════════════════════╝
BANNER
echo ""
say "$DIM" "Detects installed agents, locates your Obsidian vault, sets API keys."
echo ""

ENV_FILE=".env.local"
TMP_ENV="$(mktemp)"
trap 'rm -f "$TMP_ENV"' EXIT

existing() {
  if [ -f "$ENV_FILE" ]; then
    grep -E "^${1}=" "$ENV_FILE" 2>/dev/null | head -1 | cut -d= -f2- || true
  fi
}

# 1. Anthropic
say "$CYAN$BOLD" "[1/3] Anthropic API key"
EXISTING_ANTHROPIC="$(existing ANTHROPIC_API_KEY)"
if [ -n "$EXISTING_ANTHROPIC" ]; then
  PREFIX="${EXISTING_ANTHROPIC:0:14}"
  say "$GREEN" "   ✓ Found existing key: ${PREFIX}…"
  ask "   Keep it? [Y/n]"
  if [[ "$REPLY" =~ ^[Nn]$ ]]; then
    EXISTING_ANTHROPIC=""
  fi
fi
if [ -z "$EXISTING_ANTHROPIC" ]; then
  say "$DIM" "   Get a key at https://console.anthropic.com → API Keys"
  ask "   Paste your Anthropic API key (or Enter to skip):"
  EXISTING_ANTHROPIC="$REPLY"
fi
echo "ANTHROPIC_API_KEY=$EXISTING_ANTHROPIC" >> "$TMP_ENV"
echo ""

# 2. Hermes
say "$CYAN$BOLD" "[2/3] Hermes Agent (optional, powers HERMES-07)"
if command -v hermes >/dev/null 2>&1; then
  HERMES_VERSION="$(hermes --version 2>/dev/null | head -1 || echo unknown)"
  say "$GREEN" "   ✓ Hermes installed: $HERMES_VERSION"
  ask "   Hermes API server key (default: local-dev):"
  HERMES_KEY="${REPLY:-local-dev}"
  echo "HERMES_BASE_URL=http://localhost:8642/v1" >> "$TMP_ENV"
  echo "HERMES_API_KEY=$HERMES_KEY" >> "$TMP_ENV"
  if ! lsof -i :8642 >/dev/null 2>&1; then
    say "$DIM" "   ℹ To start the Hermes gateway later: hermes gateway"
  fi
else
  say "$DIM" "   ⊙ Hermes not detected. HERMES-07 will show an error if used."
  say "$DIM" "     Install later: curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash"
  echo "# HERMES_BASE_URL=http://localhost:8642/v1" >> "$TMP_ENV"
  echo "# HERMES_API_KEY=local-dev" >> "$TMP_ENV"
fi
echo ""

# 3. Obsidian
say "$CYAN$BOLD" "[3/3] Obsidian vault (optional, auto-saves chats + missions)"
say "$DIM" "   Looking for vaults in common locations…"

CANDIDATES=()
ICLOUD_BASE="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents"
if [ -d "$ICLOUD_BASE" ]; then
  while IFS= read -r d; do
    CANDIDATES+=("$d")
  done < <(find "$ICLOUD_BASE" -maxdepth 2 -name ".obsidian" -type d 2>/dev/null | xargs -I{} dirname {} 2>/dev/null)
fi
if [ -d "$HOME/Documents" ]; then
  while IFS= read -r d; do
    CANDIDATES+=("$d")
  done < <(find "$HOME/Documents" -maxdepth 3 -name ".obsidian" -type d 2>/dev/null | xargs -I{} dirname {} 2>/dev/null)
fi
while IFS= read -r d; do
  CANDIDATES+=("$d")
done < <(find "$HOME" -maxdepth 2 -name ".obsidian" -type d 2>/dev/null | xargs -I{} dirname {} 2>/dev/null)

if [ ${#CANDIDATES[@]} -gt 0 ]; then
  IFS=$'\n' CANDIDATES=($(printf "%s\n" "${CANDIDATES[@]}" | awk '!seen[$0]++'))
  unset IFS
fi

VAULT_PATH=""
EXISTING_VAULT="$(existing OBSIDIAN_VAULT)"

if [ -n "$EXISTING_VAULT" ] && [ -d "$EXISTING_VAULT" ]; then
  say "$GREEN" "   ✓ Found existing vault: $EXISTING_VAULT"
  ask "   Keep it? [Y/n]"
  if [[ ! "$REPLY" =~ ^[Nn]$ ]]; then
    VAULT_PATH="$EXISTING_VAULT"
  fi
fi

if [ -z "$VAULT_PATH" ] && [ ${#CANDIDATES[@]} -gt 0 ]; then
  say "$GREEN" "   ✓ Detected ${#CANDIDATES[@]} Obsidian vault(s):"
  i=1
  for c in "${CANDIDATES[@]}"; do
    name="$(basename "$c")"
    location=""
    case "$c" in
      *iCloud*) location=" ${GRAY}(iCloud, syncs to iPhone)${RESET}" ;;
    esac
    echo "      ${BOLD}$i${RESET}) $name$location"
    echo "         ${DIM}$c${RESET}"
    i=$((i+1))
  done
  echo "      ${BOLD}0${RESET}) Skip / enter manually"
  ask "   Select [1-${#CANDIDATES[@]} or 0]:"
  if [[ "$REPLY" =~ ^[0-9]+$ ]] && [ "$REPLY" -ge 1 ] && [ "$REPLY" -le ${#CANDIDATES[@]} ]; then
    VAULT_PATH="${CANDIDATES[$((REPLY-1))]}"
  fi
fi

if [ -z "$VAULT_PATH" ]; then
  ask "   Enter full path to your Obsidian vault (or Enter to skip):"
  VAULT_PATH="$REPLY"
fi

if [ -n "$VAULT_PATH" ]; then
  if [ -d "$VAULT_PATH" ]; then
    say "$GREEN" "   ✓ Vault path: $VAULT_PATH"
  else
    say "$AMBER" "   ⚠ Path doesn't exist, saving anyway."
  fi
  echo "OBSIDIAN_VAULT=$VAULT_PATH" >> "$TMP_ENV"
else
  say "$DIM" "   ⊙ No vault configured. Chat auto-save disabled."
  echo "# OBSIDIAN_VAULT=" >> "$TMP_ENV"
fi
echo ""

# Write .env.local
if [ -f "$ENV_FILE" ]; then
  cp "$ENV_FILE" "${ENV_FILE}.backup.$(date +%s)"
  say "$DIM" "   (Previous .env.local backed up)"
fi
{
  echo "# AEGIS // Mission Control configuration"
  echo "# Generated by setup.sh on $(date)"
  echo "# Re-run ./setup.sh anytime to update."
  echo ""
  cat "$TMP_ENV"
} > "$ENV_FILE"

say "$GREEN$BOLD" "✅ Setup complete. Configuration saved to .env.local"
echo ""
say "$BOLD" "Next steps:"
say "$RESET" "   1. Start the dev server:   ${BOLD}npm run dev${RESET}"
say "$RESET" "   2. Open                    ${BOLD}http://localhost:3000${RESET}"
if command -v hermes >/dev/null 2>&1; then
  say "$RESET" "   3. (Optional) Hermes gateway in another terminal: ${BOLD}hermes gateway${RESET}"
fi
echo ""
