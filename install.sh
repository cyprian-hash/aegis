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
