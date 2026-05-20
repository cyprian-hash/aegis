#!/usr/bin/env bash
# apply-netty-banks-patch.sh
#
# Adds Netty Banks as a 12th project in your Privé Systems portfolio.
# Netty is your personal Telegram agent built on GravityClaw, edited in Antigravity,
# auto-deployed from GitHub to your Hostinger VPS.
#
# This patch is purely additive — it appends a new project markdown file to your
# Obsidian vault and updates the seed list for future installs.
#
# Run from inside the aegis project directory:
#   bash apply-netty-banks-patch.sh

set -e

if [ ! -f package.json ] || [ ! -d components ]; then
  echo "❌ Run from inside the aegis project directory."
  exit 1
fi

if [ ! -f lib/projects.ts ]; then
  echo "❌ lib/projects.ts not found — run apply-multiproject-patch.sh first."
  exit 1
fi

VAULT="${OBSIDIAN_VAULT:-$(grep ^OBSIDIAN_VAULT .env.local 2>/dev/null | cut -d= -f2-)}"
if [ -z "$VAULT" ]; then
  echo "⚠️  Couldn't determine OBSIDIAN_VAULT path. Patch will still update the seed list."
  echo "    Vault file write will be skipped — re-seed manually via the Projects view."
fi

echo "📦 Backing up files to .pre-netty-backup/"
mkdir -p .pre-netty-backup/lib
cp lib/projects.ts .pre-netty-backup/lib/

# ----------------------------------------------------------------------------
# 1. Add Netty Banks to SEED_PROJECTS for future installs
# ----------------------------------------------------------------------------
echo "✏️  Adding Netty Banks to seed projects in lib/projects.ts"
python3 - <<'PYEOF'
p = "lib/projects.ts"
src = open(p).read()
if '"netty-banks-agent"' in src or 'id: "netty-banks-agent"' in src:
    print("   ⊙ Netty Banks agent project already present in seeds")
else:
    new_entry = """  {
    id: "netty-banks-agent",
    name: "Netty",
    description: "AI personal assistant — GravityClaw agent on Telegram, edited in Antigravity, auto-deployed to Hostinger VPS.",
    website: "https://t.me/nettybanks",
    repos: ["cyprian-hash/gravityclaw"],
    hosting: ["other"],
    status: "live",
    color: "#C084FC", // lighter purple than Netty Banks (the app, #A855F7) to differentiate
    tags: ["agent", "telegram", "personal", "gravityclaw"],
    notes: "Telegram: @nettybanks (chat id 8035083053). Runs on Hostinger VPS with auto-deploy from main branch of cyprian-hash/gravityclaw. Edit via Antigravity, push to GitHub, VPS pulls automatically.\\n\\nNetty observes the AEGIS Obsidian vault and can act on what other agents wrote. Chat happens in Telegram, not AEGIS.",
  },
"""
    # Insert before the closing bracket of SEED_PROJECTS
    needle = "];\n\nexport function slugify"
    if needle in src:
        src = src.replace(needle, new_entry + needle, 1)
        open(p, "w").write(src)
        print("   ✓ Netty added to SEED_PROJECTS")
    else:
        print("   ⚠ Couldn't find SEED_PROJECTS close marker; file unchanged")
PYEOF

# ----------------------------------------------------------------------------
# 2. Write the Netty markdown file into the Obsidian vault (so it appears now,
#    not just on next install)
# ----------------------------------------------------------------------------
if [ -n "$VAULT" ] && [ -d "$VAULT" ]; then
  PROJECT_DIR="$VAULT/AEGIS/Projects"
  mkdir -p "$PROJECT_DIR"
  TARGET="$PROJECT_DIR/netty-banks-agent.md"

  if [ -f "$TARGET" ]; then
    echo "   ⊙ $TARGET already exists, not overwriting"
  else
    echo "✏️  Writing $TARGET"
    cat > "$TARGET" <<EOF
---
id: netty-banks-agent
name: Netty
description: AI personal assistant — GravityClaw agent on Telegram, edited in Antigravity, auto-deployed to Hostinger VPS.
website: https://t.me/nettybanks
repos:
  - cyprian-hash/gravityclaw
hosting:
  - other
status: live
color: "#C084FC"
tags:
  - agent
  - telegram
  - personal
  - gravityclaw
createdAt: $(date -u +%Y-%m-%dT%H:%M:%SZ)
updatedAt: $(date -u +%Y-%m-%dT%H:%M:%SZ)
---

# Netty

AI personal assistant — GravityClaw agent on Telegram, edited in Antigravity, auto-deployed to Hostinger VPS.

## Notes

Telegram: @nettybanks (chat id 8035083053).

Runs on Hostinger VPS with auto-deploy from main branch of cyprian-hash/gravityclaw. Edit via Antigravity, push to GitHub, VPS pulls automatically.

Netty observes the AEGIS Obsidian vault and can act on what other agents wrote. Chat happens in Telegram, not AEGIS.

## How Netty fits the system

- **Editor:** Antigravity (gravityclaw repo)
- **Source of truth:** GitHub — cyprian-hash/gravityclaw
- **Runtime:** Hostinger VPS (auto-deploys from main)
- **User interface:** Telegram bot @nettybanks
- **Inter-agent coordination:** Reads Obsidian vault via filesystem/sync, writes its own observations to AEGIS/Netty/

## Things Netty can do today

_(Fill this in as Netty's skills evolve. AEGIS will display this section as the capabilities panel.)_

- _placeholder — replace with Netty's actual capabilities_
EOF
    echo "   ✓ Netty project file added to vault"
  fi
else
  echo "   ⊙ Vault path not available; skipped writing Obsidian file"
  echo "     AEGIS will pick up Netty from the seed on next install/re-seed"
fi

echo ""
echo "✅ Netty Banks added as a project."
echo ""
echo "Next:"
echo "   1. Refresh AEGIS (Cmd+R on http://localhost:3000) — no restart needed"
echo "   2. Click Projects in the sidebar"
echo "   3. You should see 12 projects now, including 'Netty' with purple accent"
echo "   4. Click the Netty card → detail modal shows GitHub + Telegram links"
echo ""
echo "Things you can do next:"
echo "   - Edit the 'Things Netty can do today' section in netty-banks-agent.md"
echo "     in your Obsidian vault — write real capabilities"
echo "   - Push gravityclaw changes via Antigravity as usual — AEGIS will see"
echo "     the GitHub link, and a later patch will surface commit activity"
echo ""
echo "Backups in .pre-netty-backup/ — to revert: cp -r .pre-netty-backup/* ."
