#!/usr/bin/env bash
# apply-memory-view-patch.sh
# Replaces the fake, hardcoded MemoryView with a REAL knowledge browser that reads
# your Obsidian vault (AEGIS/Projects, AEGIS/Chats, AEGIS/Context). Adds:
#   - /api/memory  : GET stats+recent (reads vault), GET ?q=... (keyword search)
#   - MemoryView   : real stats, real knowledge breakdown, real recent files,
#                    and a WORKING keyword search over vault markdown.
# Honest labeling: this is a knowledge browser + keyword search, NOT a vector/
# semantic index (no fake "embeddings/chunks/vectorized" claims).
# Built/verified against the real repo.
set -e
if [ ! -f components/MemoryView.tsx ]; then
  echo "❌ Run from inside the aegis project directory."; exit 1
fi

echo "📦 Backing up to .pre-memview-backup/"
mkdir -p .pre-memview-backup/components .pre-memview-backup/app/api/memory
cp components/MemoryView.tsx .pre-memview-backup/components/ 2>/dev/null || true
[ -f app/api/memory/route.ts ] && cp app/api/memory/route.ts .pre-memview-backup/app/api/memory/ 2>/dev/null || true

# ----------------------------------------------------------------------------
# 1. Backend API: /api/memory  (reads the real vault)
# ----------------------------------------------------------------------------
echo "✏️  Creating app/api/memory/route.ts (reads real vault)"
mkdir -p app/api/memory
cat > app/api/memory/route.ts <<'TSEOF'
import { promises as fs } from "fs";
import path from "path";
import matter from "gray-matter";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

function vaultRoot(): string | null {
  return process.env.OBSIDIAN_VAULT || null;
}
function aegisDir(root: string, ...p: string[]): string {
  return path.join(root, "AEGIS", ...p);
}

interface MemFile {
  name: string;
  kind: "brief" | "conversation" | "context" | "source" | "strategy" | "other";
  project?: string;
  path: string;
  size: number;
  updated: string; // ISO
}

// Recursively collect .md files under a dir, tagging kind + project.
async function collect(root: string): Promise<MemFile[]> {
  const out: MemFile[] = [];

  async function walk(dir: string, kind: MemFile["kind"], project?: string) {
    let entries: any[] = [];
    try { entries = await fs.readdir(dir, { withFileTypes: true }); } catch { return; }
    for (const e of entries) {
      const full = path.join(dir, e.name);
      if (e.isDirectory()) {
        // Projects/<id>/ subfolders: source-docs, strategies
        if (kind === "brief") {
          if (e.name === "source-docs") await walk(full, "source", project);
          else if (e.name === "strategies") await walk(full, "strategy", project);
          else await walk(full, kind, e.name);
        } else if (kind === "conversation") {
          await walk(full, "conversation", e.name); // Chats/<agent>/
        } else {
          await walk(full, kind, project);
        }
        continue;
      }
      if (!e.name.endsWith(".md")) continue;
      try {
        const st = await fs.stat(full);
        const proj = kind === "brief" && !project ? e.name.replace(/\.md$/, "") : project;
        out.push({
          name: e.name.replace(/\.md$/, ""),
          kind,
          project: proj,
          path: full,
          size: st.size,
          updated: st.mtime.toISOString(),
        });
      } catch {}
    }
  }

  await walk(aegisDir(root, "Projects"), "brief");
  await walk(aegisDir(root, "Chats"), "conversation");
  await walk(aegisDir(root, "Context"), "context");
  return out;
}

export async function GET(req: Request) {
  const root = vaultRoot();
  if (!root) {
    return Response.json({ ok: false, error: "OBSIDIAN_VAULT not set in .env.local" }, { status: 500 });
  }
  const url = new URL(req.url);
  const q = (url.searchParams.get("q") || "").trim().toLowerCase();

  let files: MemFile[];
  try { files = await collect(root); }
  catch (e: any) { return Response.json({ ok: false, error: String(e?.message || e) }, { status: 500 }); }

  // Search mode: scan file contents for the query, return matches + snippet.
  if (q) {
    const results: any[] = [];
    for (const f of files) {
      try {
        const raw = await fs.readFile(f.path, "utf8");
        const body = matter(raw).content || raw;
        const idx = body.toLowerCase().indexOf(q);
        if (idx >= 0) {
          const start = Math.max(0, idx - 60);
          const snippet = body.slice(start, idx + 120).replace(/\s+/g, " ").trim();
          results.push({ name: f.name, kind: f.kind, project: f.project, snippet, updated: f.updated });
        }
      } catch {}
    }
    results.sort((a, b) => (a.name > b.name ? 1 : -1));
    return Response.json({ ok: true, mode: "search", query: q, count: results.length, results: results.slice(0, 40) });
  }

  // Overview mode: stats + breakdown + recent.
  const byKind: Record<string, number> = {};
  let totalSize = 0;
  for (const f of files) { byKind[f.kind] = (byKind[f.kind] || 0) + 1; totalSize += f.size; }

  const recent = [...files]
    .sort((a, b) => (a.updated < b.updated ? 1 : -1))
    .slice(0, 8)
    .map(f => ({ name: f.name, kind: f.kind, project: f.project, updated: f.updated, size: f.size }));

  return Response.json({
    ok: true,
    mode: "overview",
    stats: {
      total: files.length,
      briefs: byKind["brief"] || 0,
      conversations: byKind["conversation"] || 0,
      context: byKind["context"] || 0,
      sources: byKind["source"] || 0,
      strategies: byKind["strategy"] || 0,
      totalSize,
    },
    recent,
  });
}
TSEOF
echo "   ✓ /api/memory created (stats, recent, keyword search — all real)"

echo ""
echo "   (MemoryView.tsx rewrite continues in part 2 of this script...)"

# ----------------------------------------------------------------------------
# 2. Frontend: rewrite MemoryView.tsx to use real /api/memory data
# ----------------------------------------------------------------------------
echo "✏️  Rewriting components/MemoryView.tsx (real data + working search)"
cat > components/MemoryView.tsx <<'TSEOF'
"use client";
import { useEffect, useState, useCallback } from "react";
import { motion } from "framer-motion";
import { Database, FileText, Layers, Search, MessageSquare, BookOpen, FileStack, Loader2 } from "lucide-react";
import StatTile from "./StatTile";
import SectionHeader from "./SectionHeader";
import { COLOR_MAP } from "@/lib/theme";

interface Recent { name: string; kind: string; project?: string; updated: string; size: number; }
interface SearchHit { name: string; kind: string; project?: string; snippet: string; updated: string; }
interface Overview {
  ok: boolean; error?: string;
  stats?: { total: number; briefs: number; conversations: number; context: number; sources: number; strategies: number; totalSize: number; };
  recent?: Recent[];
}

const KIND_META: Record<string, { label: string; color: string; icon: any }> = {
  brief:        { label: "Brief",        color: "cyan",    icon: BookOpen },
  conversation: { label: "Conversation", color: "emerald", icon: MessageSquare },
  context:      { label: "Context",      color: "amber",   icon: Database },
  source:       { label: "Source Doc",   color: "violet",  icon: FileText },
  strategy:     { label: "Strategy",     color: "rose",    icon: FileStack },
  other:        { label: "File",         color: "cyan",    icon: FileText },
};

function ago(iso: string): string {
  const s = Math.floor((Date.now() - new Date(iso).getTime()) / 1000);
  if (s < 60) return `${s}s ago`;
  if (s < 3600) return `${Math.floor(s / 60)}m ago`;
  if (s < 86400) return `${Math.floor(s / 3600)}h ago`;
  return `${Math.floor(s / 86400)}d ago`;
}
function kb(n: number): string { return n < 1024 ? `${n} B` : `${(n / 1024).toFixed(1)} KB`; }

export default function MemoryView() {
  const [data, setData] = useState<Overview | null>(null);
  const [loading, setLoading] = useState(true);
  const [query, setQuery] = useState("");
  const [results, setResults] = useState<SearchHit[] | null>(null);
  const [searching, setSearching] = useState(false);

  useEffect(() => {
    fetch("/api/memory").then(r => r.json()).then(setData).catch(() => setData({ ok: false, error: "Failed to load" })).finally(() => setLoading(false));
  }, []);

  const runSearch = useCallback(async () => {
    const q = query.trim();
    if (!q) { setResults(null); return; }
    setSearching(true);
    try {
      const r = await fetch(`/api/memory?q=${encodeURIComponent(q)}`);
      const j = await r.json();
      setResults(j.ok ? j.results : []);
    } catch { setResults([]); }
    finally { setSearching(false); }
  }, [query]);

  const s = data?.stats;

  return (
    <div>
      <SectionHeader kicker="SYSTEM / MEMORY" title="Memory & Knowledge" />

      {/* Real stats from the vault */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-3 mb-8">
        <StatTile label="TOTAL FILES"   value={loading ? "—" : String(s?.total ?? 0)}         sub="IN VAULT"       accent="amber"   sparkSeed={3} />
        <StatTile label="PROJECT BRIEFS" value={loading ? "—" : String(s?.briefs ?? 0)}        sub="KNOWLEDGE BASE" accent="cyan"    sparkSeed={5} />
        <StatTile label="CONVERSATIONS"  value={loading ? "—" : String(s?.conversations ?? 0)} sub="AGENT THREADS"  accent="emerald" sparkSeed={9} />
        <StatTile label="CONTEXT FILES"  value={loading ? "—" : String(s?.context ?? 0)}       sub="ALWAYS-ON"      accent="violet"  sparkSeed={2} />
      </div>

      {!loading && data && !data.ok && (
        <div className="rounded-2xl border border-rose-500/20 bg-rose-500/[0.04] p-4 mb-6 text-[12px] text-rose-300/80 font-mono">
          Memory source unavailable: {data.error}
        </div>
      )}

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-3 mb-6">
        {/* Knowledge breakdown — real counts */}
        <div className="rounded-2xl border border-white/[0.07] bg-white/[0.02] p-6">
          <div className="flex items-center gap-2 mb-4">
            <Layers className="h-3.5 w-3.5 text-amber-400" />
            <span className="font-mono text-[10px] tracking-[0.28em] text-white/80">KNOWLEDGE BREAKDOWN</span>
          </div>
          <div className="space-y-4">
            {([
              ["Project Briefs",  s?.briefs ?? 0,        "cyan"],
              ["Conversations",   s?.conversations ?? 0, "emerald"],
              ["Context Files",   s?.context ?? 0,       "amber"],
              ["Source Docs",     s?.sources ?? 0,       "violet"],
              ["Strategies",      s?.strategies ?? 0,    "rose"],
            ] as const).map(([k, v, col]) => {
              const c = COLOR_MAP[col as keyof typeof COLOR_MAP];
              const max = Math.max(1, s?.total ?? 1);
              const pct = ((v as number) / max) * 100;
              return (
                <div key={k}>
                  <div className="flex items-center justify-between mb-1.5">
                    <span className="text-[12px] text-white/75">{k}</span>
                    <span className="font-mono text-[10px] text-white/85 tabular-nums">{v}</span>
                  </div>
                  <div className="h-1.5 bg-white/[0.05] rounded-full overflow-hidden">
                    <motion.div className="h-full rounded-full" style={{ background: c.hex, boxShadow: `0 0 6px ${c.glow}` }}
                      initial={{ width: 0 }} animate={{ width: `${pct}%` }} transition={{ duration: 1 }} />
                  </div>
                </div>
              );
            })}
          </div>
        </div>

        {/* Recently updated — real files */}
        <div className="rounded-2xl border border-white/[0.07] bg-white/[0.02] p-6">
          <div className="flex items-center gap-2 mb-4">
            <FileText className="h-3.5 w-3.5 text-amber-400" />
            <span className="font-mono text-[10px] tracking-[0.28em] text-white/80">RECENTLY UPDATED</span>
          </div>
          <div className="space-y-1.5">
            {loading && <div className="flex items-center gap-2 text-white/40 text-[12px]"><Loader2 className="h-3.5 w-3.5 animate-spin" /> Reading vault…</div>}
            {!loading && (data?.recent ?? []).map((f, i) => {
              const meta = KIND_META[f.kind] || KIND_META.other;
              const c = COLOR_MAP[meta.color as keyof typeof COLOR_MAP];
              const Icon = meta.icon;
              return (
                <motion.div key={f.name + i}
                  initial={{ opacity: 0, x: -8 }} animate={{ opacity: 1, x: 0 }} transition={{ delay: i * 0.03 }}
                  className="flex items-center gap-3 rounded-xl border border-white/[0.05] p-3">
                  <div className="h-8 w-8 rounded-lg grid place-items-center shrink-0" style={{ background: c.soft, border: `1px solid ${c.hex}33` }}>
                    <Icon className="h-3.5 w-3.5" style={{ color: c.hex }} strokeWidth={1.5} />
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="text-[12px] text-white/85 truncate">{f.name}</div>
                    <div className="text-[10px] text-white/40 mt-0.5">{meta.label}{f.project && f.project !== f.name ? ` · ${f.project}` : ""} · {kb(f.size)}</div>
                  </div>
                  <span className="font-mono text-[10px] tracking-[0.18em] text-white/40 shrink-0">{ago(f.updated)}</span>
                </motion.div>
              );
            })}
            {!loading && (data?.recent ?? []).length === 0 && (
              <div className="text-[12px] text-white/40">No files found in vault.</div>
            )}
          </div>
        </div>
      </div>

      {/* Working keyword search */}
      <div className="rounded-2xl border border-white/[0.07] bg-white/[0.02] p-6">
        <div className="flex items-center gap-2 mb-3">
          <Search className="h-3.5 w-3.5 text-amber-400" />
          <span className="font-mono text-[10px] tracking-[0.28em] text-white/80">SEARCH MEMORY</span>
        </div>
        <div className="flex items-center gap-2 rounded-full border border-white/10 bg-black/40 px-4 py-1">
          <span className="text-amber-400 font-mono">⌕</span>
          <input
            value={query}
            onChange={e => setQuery(e.target.value)}
            onKeyDown={e => { if (e.key === "Enter") runSearch(); }}
            placeholder="Keyword search across briefs, conversations, context…"
            className="flex-1 bg-transparent py-2.5 text-[13px] text-white placeholder-white/30 outline-none"
          />
          <button onClick={runSearch} disabled={searching}
            className="px-4 py-1.5 rounded-full bg-amber-400 text-black text-[11px] tracking-[0.18em] font-mono font-medium hover:bg-amber-300 disabled:opacity-50 flex items-center gap-1.5">
            {searching ? <Loader2 className="h-3 w-3 animate-spin" /> : null}
            SEARCH
          </button>
        </div>

        {results !== null && (
          <div className="mt-4 space-y-1.5">
            <div className="font-mono text-[10px] tracking-[0.2em] text-white/40 mb-2">
              {results.length} {results.length === 1 ? "MATCH" : "MATCHES"}
            </div>
            {results.map((r, i) => {
              const meta = KIND_META[r.kind] || KIND_META.other;
              const c = COLOR_MAP[meta.color as keyof typeof COLOR_MAP];
              return (
                <motion.div key={r.name + i}
                  initial={{ opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: i * 0.02 }}
                  className="rounded-xl border border-white/[0.05] p-3">
                  <div className="flex items-center gap-2 mb-1">
                    <span className="h-1.5 w-1.5 rounded-full shrink-0" style={{ background: c.hex, boxShadow: `0 0 6px ${c.glow}` }} />
                    <span className="text-[12px] text-white/85">{r.name}</span>
                    <span className="font-mono text-[9px] tracking-[0.18em] text-white/35 uppercase">{meta.label}{r.project && r.project !== r.name ? ` · ${r.project}` : ""}</span>
                  </div>
                  <div className="text-[11px] text-white/45 leading-relaxed pl-3.5">…{r.snippet}…</div>
                </motion.div>
              );
            })}
            {results.length === 0 && <div className="text-[12px] text-white/40">No matches found.</div>}
          </div>
        )}
      </div>
    </div>
  );
}
TSEOF
echo "   ✓ MemoryView.tsx now reads real vault data + working keyword search"

echo ""
echo "✅ Memory view is now connected to your Obsidian vault."
echo ""
echo "Restart:  aegis-control restart"
echo ""
echo "The Memory view now shows REAL data from AEGIS/Projects, AEGIS/Chats, and"
echo "AEGIS/Context: real file counts, real knowledge breakdown, the actually most"
echo "recently-updated files, and a WORKING keyword search across your vault."
echo "Honest labeling: this is a knowledge browser + keyword search, not a vector"
echo "index (no fake embeddings/chunks). A true semantic/RAG layer would be a"
echo "separate, larger build."
echo ""
echo "Backups in .pre-memview-backup/ — revert: cp -r .pre-memview-backup/* ."
