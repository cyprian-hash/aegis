#!/usr/bin/env bash
# apply-bootstrap-patch.sh
# Adds install.sh, setup.sh, and a public README to your aegis project,
# then sanity-checks .gitignore so secrets stay out of the repo.
#
# Run from inside the aegis project directory:
#   bash apply-bootstrap-patch.sh

set -e

if [ ! -f package.json ] || [ ! -d components ]; then
  echo "❌ Run from inside the aegis project directory."
  exit 1
fi

echo "📦 Backing up README.md to .pre-bootstrap-backup/"
mkdir -p .pre-bootstrap-backup
cp README.md .pre-bootstrap-backup/ 2>/dev/null || true
cp .gitignore .pre-bootstrap-backup/ 2>/dev/null || true

# -----------------------------------------------------------------------------
# install.sh
# -----------------------------------------------------------------------------
echo "✏️  Writing install.sh"
cat > install.sh <<'INSTALL_EOF'
#!/usr/bin/env bash
# AEGIS // Mission Control — One-Command Installer
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/cyprian-hash/aegis/main/install.sh | bash
# Or, if you already cloned:
#   ./install.sh

set -e

REPO_URL="${AEGIS_REPO:-https://github.com/cyprian-hash/aegis.git}"
INSTALL_DIR="${AEGIS_DIR:-$HOME/projects/aegis}"

if [ -t 1 ]; then
  BOLD=$(tput bold) DIM=$(tput dim) RESET=$(tput sgr0)
  AMBER=$(tput setaf 3) CYAN=$(tput setaf 6) GREEN=$(tput setaf 2) RED=$(tput setaf 1)
else
  BOLD="" DIM="" RESET="" AMBER="" CYAN="" GREEN="" RED=""
fi
say() { echo "${1}${2}${RESET}"; }
die() { say "$RED" "❌ $1" >&2; exit 1; }

clear 2>/dev/null || true
cat <<'BANNER'
   ╔══════════════════════════════════════════╗
   ║                                          ║
   ║         AEGIS // Mission Control         ║
   ║              One-Command Install         ║
   ║                                          ║
   ╚══════════════════════════════════════════╝
BANNER
echo ""

OS="$(uname -s)"
case "$OS" in
  Darwin) say "$DIM" "Detected macOS." ;;
  Linux)  say "$DIM" "Detected Linux — should work but tested on macOS." ;;
  *)      die "Unsupported OS: $OS. AEGIS targets macOS." ;;
esac
echo ""

# [1/5] Homebrew (macOS only)
if [ "$OS" = "Darwin" ]; then
  say "$CYAN$BOLD" "[1/5] Homebrew"
  if command -v brew >/dev/null 2>&1; then
    say "$GREEN" "   ✓ Already installed: $(brew --version | head -1)"
  else
    say "$AMBER" "   Installing Homebrew (you'll be asked for your Mac password)…"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if [ -f /opt/homebrew/bin/brew ]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -f /usr/local/bin/brew ]; then
      eval "$(/usr/local/bin/brew shellenv)"
    fi
    say "$GREEN" "   ✓ Homebrew installed"
  fi
  echo ""
fi

# [2/5] Node.js
say "$CYAN$BOLD" "[2/5] Node.js"
NEED_NODE=true
if command -v node >/dev/null 2>&1; then
  NODE_MAJOR=$(node -v | sed 's/v//' | cut -d. -f1)
  if [ "$NODE_MAJOR" -ge 18 ]; then
    say "$GREEN" "   ✓ Already installed: $(node -v)"
    NEED_NODE=false
  else
    say "$AMBER" "   Node $(node -v) is too old (need v18+). Upgrading…"
  fi
fi
if $NEED_NODE; then
  if [ "$OS" = "Darwin" ] && command -v brew >/dev/null 2>&1; then
    brew install node@24 >/dev/null 2>&1 || brew install node@24
    brew link --overwrite --force node@24 >/dev/null 2>&1 || true
    say "$GREEN" "   ✓ Node installed: $(node -v)"
  else
    die "Could not install Node automatically. Install Node 18+ manually from https://nodejs.org and re-run."
  fi
fi
echo ""

# [3/5] Git
say "$CYAN$BOLD" "[3/5] Git"
if command -v git >/dev/null 2>&1; then
  say "$GREEN" "   ✓ Already installed: $(git --version)"
else
  if [ "$OS" = "Darwin" ]; then
    brew install git
    say "$GREEN" "   ✓ Git installed"
  else
    die "Install git and re-run."
  fi
fi
echo ""

# [4/5] Clone repo
say "$CYAN$BOLD" "[4/5] AEGIS source"
if [ -f "$(pwd)/package.json" ] && [ -d "$(pwd)/components" ] && grep -q "aegis-mission-control" package.json 2>/dev/null; then
  say "$GREEN" "   ✓ Already inside the aegis directory"
  INSTALL_DIR="$(pwd)"
elif [ -d "$INSTALL_DIR/.git" ]; then
  say "$DIM" "   Found existing repo at $INSTALL_DIR — updating…"
  cd "$INSTALL_DIR"
  git pull --ff-only 2>/dev/null || say "$AMBER" "   ⚠ Couldn't fast-forward, leaving local copy as-is"
  say "$GREEN" "   ✓ Repo up to date"
else
  say "$DIM" "   Cloning $REPO_URL → $INSTALL_DIR"
  mkdir -p "$(dirname "$INSTALL_DIR")"
  git clone "$REPO_URL" "$INSTALL_DIR"
  cd "$INSTALL_DIR"
  say "$GREEN" "   ✓ Cloned"
fi
echo ""

# [5/5] npm install
say "$CYAN$BOLD" "[5/5] Dependencies"
cd "$INSTALL_DIR"
say "$DIM" "   Running npm install (30-90 seconds)…"
npm install --silent 2>&1 | tail -3 || npm install
say "$GREEN" "   ✓ Dependencies installed"
echo ""

# Run setup wizard
if [ -f setup.sh ]; then
  say "$CYAN$BOLD" "Configuration"
  echo ""
  bash setup.sh
fi

echo ""
say "$GREEN$BOLD" "🎉 AEGIS is ready."
echo ""
say "$BOLD" "Start it:"
say "$RESET" "   ${BOLD}cd $INSTALL_DIR${RESET}"
say "$RESET" "   ${BOLD}npm run dev${RESET}"
echo ""
say "$BOLD" "Then open:"
say "$RESET" "   ${BOLD}http://localhost:3000${RESET}"
echo ""
say "$DIM" "Re-run ./setup.sh anytime to update config."
echo ""
INSTALL_EOF
chmod +x install.sh
echo "   ✓ install.sh created"

# -----------------------------------------------------------------------------
# setup.sh
# -----------------------------------------------------------------------------
echo "✏️  Writing setup.sh"
cat > setup.sh <<'SETUP_EOF'
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
SETUP_EOF
chmod +x setup.sh
echo "   ✓ setup.sh created"

# -----------------------------------------------------------------------------
# README.md
# -----------------------------------------------------------------------------
echo "✏️  Writing README.md"
cat > README.md <<'README_EOF'
# AEGIS // Mission Control

A terminal-meets-luxury operating system for piloting Claude and a fleet of AI agents from your local machine. Built with Next.js 14, TypeScript, Tailwind, Framer Motion, and the official Anthropic SDK.

```
phosphor amber + electric cyan on obsidian black
seven agents · real chat-app feel · custom SVG sigils
optional Hermes Agent backend · Obsidian vault auto-save
```

## One-command install

```bash
curl -fsSL https://raw.githubusercontent.com/cyprian-hash/aegis/main/install.sh | bash
```

Installs Homebrew → Node → clones the repo → installs dependencies → runs the interactive setup wizard.

The wizard auto-detects whether Hermes Agent is installed, scans for your Obsidian vault in common iCloud locations, and asks for your Anthropic API key. Re-run `./setup.sh` later to reconfigure.

## What's inside

**Seven agents:** CLAUDE.PRIME (reasoning), SCOUT-01 (research), FORGE-02 (code), ARCHIVE-03 (memory), WEAVER-04 (orchestration), SENTRY-05 (safety eval), HERMES-07 (autonomous agent via Hermes).

**Nine views:** Overview, Agents, Chat (with voice input), Missions (kanban), Logs, MCP, Telemetry, Network, Memory.

**Features:** real Anthropic streaming over SSE · optional Hermes Agent backend with terminal/filesystem/web tools · browser-native voice input · Obsidian vault auto-save for chats and missions · animated SVG agent sigils.

## Configuration

All settings live in `.env.local` (gitignored, never committed):

```env
ANTHROPIC_API_KEY=sk-ant-api03-...
HERMES_BASE_URL=http://localhost:8642/v1     # optional
HERMES_API_KEY=local-dev                      # optional
OBSIDIAN_VAULT=/path/to/vault                 # optional
```

## Hermes Agent (optional)

```bash
# Install
curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash

# Enable the gateway
echo "API_SERVER_ENABLED=true" >> ~/.hermes/.env
echo "API_SERVER_KEY=local-dev" >> ~/.hermes/.env

# Run in a separate terminal
hermes gateway
```

Then HERMES-07 in AEGIS becomes fully functional. Docs: https://hermes-agent.nousresearch.com/docs

## Start / stop

```bash
cd ~/projects/aegis
npm run dev                  # AEGIS UI on :3000
hermes gateway               # Hermes (in another terminal tab), optional
```

Ctrl+C to stop.

## License

MIT.
README_EOF
echo "   ✓ README.md updated"

# -----------------------------------------------------------------------------
# .gitignore safety
# -----------------------------------------------------------------------------
echo "✏️  Hardening .gitignore"
touch .gitignore
for entry in "node_modules" ".next" "out" ".env" ".env.local" ".env*.local" ".DS_Store" "*.log" ".vercel" ".pre-*-backup" ".pre-hermes-backup" ".pre-voice-backup" ".pre-vault-backup" ".pre-bootstrap-backup"; do
  if ! grep -qxF "$entry" .gitignore; then
    echo "$entry" >> .gitignore
  fi
done
echo "   ✓ .gitignore hardened (secrets and backups will never be committed)"

echo ""
echo "✅ Bootstrap files installed."
echo ""
echo "📋 Next: push to GitHub. I'll walk you through the three commands."
echo ""
echo "Backups in .pre-bootstrap-backup/ — to revert: cp -r .pre-bootstrap-backup/* ."
