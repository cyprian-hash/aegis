#!/usr/bin/env bash
# fix-hydration-patch.sh
#
# Fixes the "Text content does not match server-rendered HTML" error in
# the Sidebar after the multi-project patch.
#
# The bug: useProjects reads localStorage on first render, which is undefined
# on the server but populated on the client, causing the project switcher
# to render different content between SSR and hydration.
#
# Fix: lazily read localStorage in a useEffect after first paint, so the
# server and initial client render produce identical HTML.
#
# Run from inside the aegis project directory:
#   bash fix-hydration-patch.sh

set -e

if [ ! -f package.json ] || [ ! -d components ]; then
  echo "❌ Run from inside the aegis project directory."
  exit 1
fi

echo "📦 Backing up to .pre-hydrationfix-backup/"
mkdir -p .pre-hydrationfix-backup/lib .pre-hydrationfix-backup/components
cp lib/useProjects.ts .pre-hydrationfix-backup/lib/ 2>/dev/null || true
cp components/Sidebar.tsx .pre-hydrationfix-backup/components/ 2>/dev/null || true

# -----------------------------------------------------------------------------
# 1. Rewrite useProjects.ts so initial state matches between server and client
# -----------------------------------------------------------------------------
echo "✏️  Rewriting lib/useProjects.ts to be SSR-safe"
cat > lib/useProjects.ts <<'EOF'
"use client";
import { useState, useEffect, useCallback } from "react";
import { Project } from "./projects";

const ACTIVE_KEY = "aegis_active_project";

export function useProjects() {
  const [projects, setProjects] = useState<Project[]>([]);
  // CRITICAL: never read localStorage during render — that creates a server/client mismatch.
  // Start with null on both server AND first client render, then sync from localStorage in useEffect.
  const [activeId, setActiveIdState] = useState<string | null>(null);
  const [hydrated, setHydrated] = useState(false);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    try {
      const res = await fetch("/api/projects", { cache: "no-store" });
      const data = await res.json();
      if (!data.ok) {
        setError(data.error || "Failed to load projects");
        setProjects([]);
      } else {
        setProjects(data.projects || []);
        setError(null);
      }
    } catch (err: any) {
      setError(err?.message || "Network error");
    } finally {
      setLoading(false);
    }
  }, []);

  // Sync localStorage AFTER first paint (client only)
  useEffect(() => {
    try {
      const saved = window.localStorage.getItem(ACTIVE_KEY);
      if (saved) setActiveIdState(saved);
    } catch { /* ignore */ }
    setHydrated(true);
    refresh();
  }, [refresh]);

  const setActiveId = useCallback((id: string | null) => {
    setActiveIdState(id);
    try {
      if (id) window.localStorage.setItem(ACTIVE_KEY, id);
      else window.localStorage.removeItem(ACTIVE_KEY);
    } catch { /* ignore */ }
  }, []);

  // While not hydrated, pretend activeId is null so server and first client
  // render produce identical HTML. After hydration the real value flows in.
  const safeActiveId = hydrated ? activeId : null;
  const activeProject = safeActiveId ? projects.find(p => p.id === safeActiveId) || null : null;

  return {
    projects,
    activeId: safeActiveId,
    activeProject,
    setActiveId,
    loading,
    error,
    hydrated,
    refresh,
  };
}
EOF
echo "   ✓ useProjects is now SSR-safe"

# -----------------------------------------------------------------------------
# 2. Belt-and-suspenders: ensure Sidebar renders identically on server and client
#    by checking for the bad shape and rewriting cleanly.
# -----------------------------------------------------------------------------
echo "✏️  Verifying Sidebar.tsx has clean NAV order"
python3 - <<'PYEOF'
p = "components/Sidebar.tsx"
src = open(p).read()

# The good shape: Projects under WORKSPACE, then OPERATIONS group starts with Missions
good_chunk = '''  { id: "projects", label: "Projects",  icon: Briefcase, group: "WORKSPACE" },
  { id: "missions",  label: "Missions",   icon: Compass,   group: "OPERATIONS" },'''

if good_chunk in src:
    print("   ✓ Sidebar NAV is already in the right shape")
else:
    print("   ⚠ Sidebar NAV looks off — will normalize")
    # Try several known-bad shapes
    candidates = [
        # Case 1: Projects missing entirely
        '  { id: "missions",  label: "Missions",   icon: Compass,   group: "OPERATIONS" },',
        # Case 2: Projects present but malformed
    ]
    fixed = False
    for cand in candidates:
        if cand in src:
            src = src.replace(cand, good_chunk, 1)
            fixed = True
            print("   ✓ NAV normalized")
            break
    if fixed:
        open(p, "w").write(src)
    else:
        print("   ⚠ couldn't auto-fix; file may need manual review")
PYEOF

echo ""
echo "✅ Hydration fix applied."
echo ""
echo "Restart your dev server (Ctrl+C in npm run dev, then npm run dev again)."
echo ""
echo "What changed:"
echo "   - useProjects now reads localStorage AFTER first paint, not during render"
echo "   - Server and initial client render produce identical HTML"
echo "   - Your project selection still persists across reloads"
echo ""
echo "Backups in .pre-hydrationfix-backup/ — to revert: cp -r .pre-hydrationfix-backup/* ."
