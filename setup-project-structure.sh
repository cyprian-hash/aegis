#!/usr/bin/env bash
# setup-project-structure.sh
# One-time: ensure every project has a consistent vault folder structure:
#   AEGIS/Projects/<id>.md            (the lean brief — agents read this; created if missing)
#   AEGIS/Projects/<id>/source-docs/  (raw reference docs — NOT auto-loaded)
#   AEGIS/Projects/<id>/strategies/   (saved strategies/reports — reference)
# Safe to re-run; never overwrites existing files.
set -e
VAULT=$(grep ^OBSIDIAN_VAULT .env.local 2>/dev/null | cut -d= -f2-)
if [ -z "$VAULT" ]; then
  echo "❌ OBSIDIAN_VAULT not found in .env.local"; exit 1
fi
echo "Vault: $VAULT"

PROJECTS="prive-systems my-central-domains aura vault-legacy jetvan-vip api-monitor netty-banks jetpedia yachtpedia autopedia memory-soundx netty-banks-agent"

for p in $PROJECTS; do
  mkdir -p "$VAULT/AEGIS/Projects/$p/source-docs"
  mkdir -p "$VAULT/AEGIS/Projects/$p/strategies"
  # create a stub brief only if none exists (never overwrite real briefs)
  brief="$VAULT/AEGIS/Projects/$p.md"
  if [ ! -f "$brief" ]; then
    cat > "$brief" <<EOF
# ${p}

## Notes

_No brief yet. Use the GEMINI -> brief -> Notes workflow to populate this._
EOF
    echo "  + created stub brief: Projects/$p.md"
  else
    echo "  = brief exists, left intact: Projects/$p.md"
  fi
done

echo ""
echo "✅ Project structure standardized for all 12 projects."
echo "   Each has: <id>.md (brief) + <id>/source-docs/ + <id>/strategies/"
echo "   Existing briefs were left untouched; only missing ones got a stub."
