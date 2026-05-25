#!/usr/bin/env bash
# apply-hermes-control-patch.sh
#
# Adds Hermes integration to AEGIS:
#   - Hermes Control Center tile (version, status, update button, dashboard launcher)
#   - Hermes Activity feed (live task_events from kanban.db)
#   - "Send to Hermes" button on missions
#
# Run from inside the aegis project directory:
#   bash apply-hermes-control-patch.sh

set -e

if [ ! -f package.json ] || [ ! -d components ]; then
  echo "❌ Run from inside the aegis project directory."
  exit 1
fi

echo "📦 Backing up files to .pre-control-backup/"
mkdir -p .pre-control-backup/components .pre-control-backup/app/api
cp components/OverviewView.tsx .pre-control-backup/components/
cp components/MissionsView.tsx .pre-control-backup/components/
cp package.json .pre-control-backup/

# -----------------------------------------------------------------------------
# 1. Install better-sqlite3 for reading Hermes kanban.db
# -----------------------------------------------------------------------------
echo "📥 Installing better-sqlite3 (used to read Hermes kanban.db)"
npm install --save better-sqlite3 2>&1 | tail -2 || npm install --save better-sqlite3
echo "   ✓ dependency added"

# -----------------------------------------------------------------------------
# 2. Hermes status API route
# -----------------------------------------------------------------------------
echo "✏️  Creating app/api/hermes/status/route.ts"
mkdir -p app/api/hermes/status
cat > app/api/hermes/status/route.ts <<'EOF'
import { exec } from "child_process";
import { promisify } from "util";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const execAsync = promisify(exec);

interface StatusResponse {
  installed: boolean;
  installedVersion: string | null;
  latestVersion: string | null;
  updateAvailable: boolean;
  gatewayRunning: boolean;
  dashboardAvailable: boolean;
  hermesPath: string | null;
  error?: string;
}

// Cache latest version for 1 hour to avoid hammering GitHub API
let cachedLatest: { version: string; fetchedAt: number } | null = null;
const CACHE_MS = 60 * 60 * 1000;

async function getInstalledVersion(): Promise<{ version: string | null; path: string | null }> {
  try {
    const { stdout: pathOut } = await execAsync("which hermes", { timeout: 3000 });
    const hermesPath = pathOut.trim() || null;
    if (!hermesPath) return { version: null, path: null };

    const { stdout } = await execAsync("hermes --version 2>&1 | head -3", { timeout: 5000 });
    // Output formats seen in the wild:
    //   "Hermes Agent v0.14.0 (2026.5.16)"
    //   "hermes 0.14.0"
    //   "v0.14.0"
    const match = stdout.match(/v?(\d+\.\d+\.\d+)/);
    return { version: match ? match[1] : stdout.trim().split("\n")[0], path: hermesPath };
  } catch {
    return { version: null, path: null };
  }
}

async function getLatestVersion(): Promise<string | null> {
  if (cachedLatest && Date.now() - cachedLatest.fetchedAt < CACHE_MS) {
    return cachedLatest.version;
  }
  try {
    const res = await fetch("https://api.github.com/repos/NousResearch/hermes-agent/releases/latest", {
      headers: { "User-Agent": "aegis-control-center" },
      // Don't cache on the fetch layer; we manage our own cache.
      cache: "no-store",
    });
    if (!res.ok) return null;
    const data = await res.json();
    const tag: string = data.tag_name || "";
    // Tags look like "v2026.5.16" or "v0.14.0"; the release body has the semver.
    // Prefer extracting semver from the body / name.
    const name: string = data.name || "";
    const match = (name + " " + tag).match(/v?(\d+\.\d+\.\d+)/);
    const version = match ? match[1] : tag.replace(/^v/, "");
    cachedLatest = { version, fetchedAt: Date.now() };
    return version;
  } catch {
    return null;
  }
}

async function isGatewayRunning(): Promise<boolean> {
  const baseUrl = process.env.HERMES_BASE_URL || "http://localhost:8642/v1";
  try {
    // Try /health first; fall back to root.
    const healthUrl = baseUrl.replace(/\/v1\/?$/, "/v1/health");
    const ctrl = new AbortController();
    const t = setTimeout(() => ctrl.abort(), 1500);
    const res = await fetch(healthUrl, { signal: ctrl.signal });
    clearTimeout(t);
    return res.ok;
  } catch {
    return false;
  }
}

function compareSemver(a: string, b: string): number {
  const pa = a.split(".").map(Number);
  const pb = b.split(".").map(Number);
  for (let i = 0; i < 3; i++) {
    const x = pa[i] || 0;
    const y = pb[i] || 0;
    if (x !== y) return x - y;
  }
  return 0;
}

export async function GET() {
  const [{ version: installedVersion, path: hermesPath }, latestVersion, gatewayRunning] =
    await Promise.all([getInstalledVersion(), getLatestVersion(), isGatewayRunning()]);

  let updateAvailable = false;
  if (installedVersion && latestVersion) {
    const cleanInstalled = (installedVersion.match(/(\d+\.\d+\.\d+)/) || [])[1];
    if (cleanInstalled && compareSemver(latestVersion, cleanInstalled) > 0) {
      updateAvailable = true;
    }
  }

  const resp: StatusResponse = {
    installed: !!installedVersion,
    installedVersion,
    latestVersion,
    updateAvailable,
    gatewayRunning,
    dashboardAvailable: !!installedVersion,
    hermesPath,
  };
  return new Response(JSON.stringify(resp), {
    headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
  });
}
EOF
echo "   ✓ status route created"

# -----------------------------------------------------------------------------
# 3. Hermes update API route
# -----------------------------------------------------------------------------
echo "✏️  Creating app/api/hermes/update/route.ts"
mkdir -p app/api/hermes/update
cat > app/api/hermes/update/route.ts <<'EOF'
import { spawn } from "child_process";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function POST() {
  const encoder = new TextEncoder();

  const stream = new ReadableStream({
    async start(controller) {
      const send = (event: string, data: any) => {
        controller.enqueue(encoder.encode(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`));
      };

      send("start", { msg: "Running hermes update…" });

      const proc = spawn("hermes", ["update"], { shell: false });
      proc.stdout.on("data", (chunk) => {
        send("log", { line: chunk.toString() });
      });
      proc.stderr.on("data", (chunk) => {
        send("log", { line: chunk.toString() });
      });
      proc.on("error", (err) => {
        send("error", { message: err.message });
        controller.close();
      });
      proc.on("close", (code) => {
        if (code === 0) {
          send("done", { ok: true, msg: "Update complete" });
        } else {
          send("error", { message: `hermes update exited with code ${code}` });
        }
        controller.close();
      });
    },
  });

  return new Response(stream, {
    headers: {
      "Content-Type": "text/event-stream",
      "Cache-Control": "no-cache, no-transform",
      "Connection": "keep-alive",
    },
  });
}
EOF
echo "   ✓ update route created"

# -----------------------------------------------------------------------------
# 4. Hermes activity events route (reads kanban.db)
# -----------------------------------------------------------------------------
echo "✏️  Creating app/api/hermes/events/route.ts"
mkdir -p app/api/hermes/events
cat > app/api/hermes/events/route.ts <<'EOF'
import path from "path";
import os from "os";
import { promises as fs } from "fs";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

interface KanbanEvent {
  id: number;
  task_id: string;
  kind: string;
  payload: any;
  created_at: string;
  task_title: string | null;
  assignee: string | null;
}

export async function GET() {
  const dbPath = path.join(os.homedir(), ".hermes", "kanban.db");

  // Bail gracefully if the DB doesn't exist yet (no kanban activity)
  try {
    await fs.access(dbPath);
  } catch {
    return new Response(JSON.stringify({ events: [], dbExists: false }), {
      headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
    });
  }

  let Database: any;
  try {
    Database = require("better-sqlite3");
  } catch (err: any) {
    return new Response(
      JSON.stringify({ events: [], dbExists: true, error: "better-sqlite3 not installed: " + err.message }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }

  try {
    const db = new Database(dbPath, { readonly: true, fileMustExist: true });
    // The Hermes schema may or may not include these columns; try the rich query first,
    // fall back to a minimal one.
    let rows: any[] = [];
    try {
      rows = db.prepare(`
        SELECT
          e.id, e.task_id, e.kind, e.payload, e.created_at,
          t.title AS task_title, t.assignee AS assignee
        FROM task_events e
        LEFT JOIN tasks t ON t.id = e.task_id
        ORDER BY e.id DESC
        LIMIT 60
      `).all();
    } catch {
      try {
        rows = db.prepare(`
          SELECT id, task_id, kind, payload, created_at
          FROM task_events
          ORDER BY id DESC
          LIMIT 60
        `).all();
      } catch {
        rows = [];
      }
    }
    db.close();

    const events: KanbanEvent[] = rows.map((r: any) => ({
      id: r.id,
      task_id: r.task_id,
      kind: r.kind,
      payload: (() => { try { return JSON.parse(r.payload || "{}"); } catch { return {}; } })(),
      created_at: r.created_at,
      task_title: r.task_title || null,
      assignee: r.assignee || null,
    }));

    return new Response(JSON.stringify({ events, dbExists: true }), {
      headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
    });
  } catch (err: any) {
    return new Response(
      JSON.stringify({ events: [], dbExists: true, error: err?.message || "DB read failed" }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
}
EOF
echo "   ✓ events route created"

# -----------------------------------------------------------------------------
# 5. Hermes dispatch route (Send to Hermes kanban)
# -----------------------------------------------------------------------------
echo "✏️  Creating app/api/hermes/dispatch/route.ts"
mkdir -p app/api/hermes/dispatch
cat > app/api/hermes/dispatch/route.ts <<'EOF'
import { spawn } from "child_process";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

interface DispatchRequest {
  title: string;
  body?: string;
  assignee?: string;
  priority?: number;
}

// We use the `hermes kanban create --json` CLI rather than a network API,
// because the Hermes API server doesn't expose a dedicated kanban_create
// endpoint outside the agent toolset. The CLI talks straight to kanban.db.
export async function POST(req: Request) {
  let body: DispatchRequest;
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ ok: false, error: "Invalid JSON" }), { status: 400 });
  }

  if (!body.title?.trim()) {
    return new Response(JSON.stringify({ ok: false, error: "title required" }), { status: 400 });
  }

  const args = ["kanban", "create", body.title];
  if (body.body) args.push("--body", body.body);
  if (body.assignee) args.push("--assignee", body.assignee);
  if (typeof body.priority === "number") args.push("--priority", String(body.priority));
  args.push("--json");

  return new Promise<Response>((resolve) => {
    const proc = spawn("hermes", args, { shell: false });
    let stdout = "", stderr = "";
    const timer = setTimeout(() => {
      try { proc.kill(); } catch {}
      resolve(new Response(JSON.stringify({ ok: false, error: "hermes kanban create timed out" }),
        { status: 504, headers: { "Content-Type": "application/json" } }));
    }, 10000);

    proc.stdout.on("data", (d) => { stdout += d.toString(); });
    proc.stderr.on("data", (d) => { stderr += d.toString(); });
    proc.on("error", (err) => {
      clearTimeout(timer);
      resolve(new Response(JSON.stringify({ ok: false, error: err.message }),
        { status: 500, headers: { "Content-Type": "application/json" } }));
    });
    proc.on("close", (code) => {
      clearTimeout(timer);
      if (code !== 0) {
        resolve(new Response(JSON.stringify({ ok: false, error: stderr || `exited ${code}` }),
          { status: 500, headers: { "Content-Type": "application/json" } }));
        return;
      }
      let parsed: any = null;
      try { parsed = JSON.parse(stdout); } catch {
        // Some hermes versions print preamble before JSON; grab the last brace-balanced block.
        const m = stdout.match(/\{[\s\S]*\}/);
        if (m) { try { parsed = JSON.parse(m[0]); } catch {} }
      }
      resolve(new Response(JSON.stringify({
        ok: true,
        task_id: parsed?.task_id || parsed?.id || null,
        raw: parsed,
      }), { headers: { "Content-Type": "application/json" } }));
    });
  });
}
EOF
echo "   ✓ dispatch route created"

# -----------------------------------------------------------------------------
# 6. Hermes dashboard launcher route — returns dashboard URL if running, otherwise starts it
# -----------------------------------------------------------------------------
echo "✏️  Creating app/api/hermes/dashboard/route.ts"
mkdir -p app/api/hermes/dashboard
cat > app/api/hermes/dashboard/route.ts <<'EOF'
import { spawn } from "child_process";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const DASHBOARD_URL = process.env.HERMES_DASHBOARD_URL || "http://localhost:8765";

async function probe(url: string, timeoutMs = 1200): Promise<boolean> {
  try {
    const ctrl = new AbortController();
    const t = setTimeout(() => ctrl.abort(), timeoutMs);
    const res = await fetch(url, { signal: ctrl.signal });
    clearTimeout(t);
    return res.ok || res.status < 500; // any non-server-error counts as "up"
  } catch {
    return false;
  }
}

export async function POST() {
  if (await probe(DASHBOARD_URL)) {
    return new Response(JSON.stringify({ ok: true, url: DASHBOARD_URL, started: false }), {
      headers: { "Content-Type": "application/json" },
    });
  }
  // Spawn detached so it survives this request
  try {
    const proc = spawn("hermes", ["dashboard"], {
      detached: true, stdio: "ignore", shell: false,
    });
    proc.unref();
    // Wait up to 5 seconds for it to come up
    const start = Date.now();
    while (Date.now() - start < 5000) {
      await new Promise(r => setTimeout(r, 400));
      if (await probe(DASHBOARD_URL)) {
        return new Response(JSON.stringify({ ok: true, url: DASHBOARD_URL, started: true }), {
          headers: { "Content-Type": "application/json" },
        });
      }
    }
    return new Response(JSON.stringify({
      ok: false,
      error: "Started hermes dashboard but it didn't respond within 5s. Try running it manually in a terminal."
    }), { status: 504, headers: { "Content-Type": "application/json" } });
  } catch (err: any) {
    return new Response(JSON.stringify({ ok: false, error: err.message }), {
      status: 500, headers: { "Content-Type": "application/json" },
    });
  }
}
EOF
echo "   ✓ dashboard route created"

# -----------------------------------------------------------------------------
# 7. HermesControlCenter component
# -----------------------------------------------------------------------------
echo "✏️  Creating components/HermesControlCenter.tsx"
cat > components/HermesControlCenter.tsx <<'EOF'
"use client";
import { useEffect, useState, useCallback } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { Cpu, Download, ExternalLink, RefreshCw, AlertCircle, CheckCircle2, X, Terminal } from "lucide-react";
import AgentAvatar from "./AgentAvatar";

interface HermesStatus {
  installed: boolean;
  installedVersion: string | null;
  latestVersion: string | null;
  updateAvailable: boolean;
  gatewayRunning: boolean;
  dashboardAvailable: boolean;
  hermesPath: string | null;
}

export default function HermesControlCenter() {
  const [status, setStatus] = useState<HermesStatus | null>(null);
  const [loading, setLoading] = useState(true);
  const [updating, setUpdating] = useState(false);
  const [updateLog, setUpdateLog] = useState<string>("");
  const [showLog, setShowLog] = useState(false);
  const [launching, setLaunching] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    try {
      const res = await fetch("/api/hermes/status", { cache: "no-store" });
      const data = await res.json();
      setStatus(data);
      setError(null);
    } catch (err: any) {
      setError(err.message || "Status check failed");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    refresh();
    const id = setInterval(refresh, 30000); // refresh every 30s
    return () => clearInterval(id);
  }, [refresh]);

  const runUpdate = async () => {
    if (updating) return;
    setUpdating(true);
    setUpdateLog("");
    setShowLog(true);
    try {
      const res = await fetch("/api/hermes/update", { method: "POST" });
      if (!res.body) throw new Error("No response stream");
      const reader = res.body.getReader();
      const decoder = new TextDecoder();
      let buf = "";
      while (true) {
        const { value, done } = await reader.read();
        if (done) break;
        buf += decoder.decode(value, { stream: true });
        const blocks = buf.split("\n\n");
        buf = blocks.pop() || "";
        for (const block of blocks) {
          let event = "message", data = "";
          for (const line of block.split("\n")) {
            if (line.startsWith("event:")) event = line.slice(6).trim();
            else if (line.startsWith("data:")) data += line.slice(5).trim();
          }
          if (!data) continue;
          try {
            const parsed = JSON.parse(data);
            if (event === "log") setUpdateLog((prev) => prev + parsed.line);
            else if (event === "done") setUpdateLog((prev) => prev + "\n✓ " + parsed.msg + "\n");
            else if (event === "error") setUpdateLog((prev) => prev + "\n✗ " + parsed.message + "\n");
          } catch { /* ignore parse errors */ }
        }
      }
    } catch (err: any) {
      setUpdateLog((prev) => prev + "\n✗ " + err.message);
    } finally {
      setUpdating(false);
      refresh();
    }
  };

  const launchDashboard = async () => {
    if (launching) return;
    setLaunching(true);
    try {
      const res = await fetch("/api/hermes/dashboard", { method: "POST" });
      const data = await res.json();
      if (data.ok && data.url) {
        window.open(data.url, "_blank");
      } else {
        setError(data.error || "Couldn't open Hermes dashboard");
      }
    } catch (err: any) {
      setError(err.message);
    } finally {
      setLaunching(false);
    }
  };

  if (loading) {
    return (
      <div className="rounded-2xl border border-white/[0.07] bg-white/[0.02] p-5">
        <div className="font-mono text-[10px] tracking-[0.28em] text-white/40">LOADING HERMES STATUS…</div>
      </div>
    );
  }

  if (!status?.installed) {
    return (
      <div className="rounded-2xl border border-white/[0.07] bg-white/[0.02] p-5">
        <div className="flex items-center gap-2 mb-2">
          <Cpu className="h-3.5 w-3.5 text-white/40" />
          <span className="font-mono text-[10px] tracking-[0.28em] text-white/60">HERMES AGENT</span>
        </div>
        <div className="text-[13px] text-white/70 mb-3">Hermes is not installed on this machine.</div>
        <div className="font-mono text-[11px] text-white/50 bg-black/40 rounded-lg p-2.5 select-all">
          curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash
        </div>
      </div>
    );
  }

  return (
    <div className="relative rounded-2xl border border-white/[0.07] bg-white/[0.02] p-5 overflow-hidden">
      <div className="absolute -top-12 -right-12 h-40 w-40 rounded-full opacity-20 pointer-events-none"
        style={{ background: "radial-gradient(circle, #fbbf24, transparent 70%)" }} />

      <div className="relative">
        <div className="flex items-start justify-between mb-4">
          <div className="flex items-center gap-3">
            <AgentAvatar agentId="hermes-07" size={42} animated={false} />
            <div>
              <div className="flex items-center gap-2">
                <span className="font-display text-[14px] text-white font-medium">Hermes Control</span>
                {status.updateAvailable && (
                  <span className="font-mono text-[9px] tracking-[0.2em] px-1.5 py-0.5 rounded bg-amber-400/15 text-amber-300">
                    UPDATE AVAILABLE
                  </span>
                )}
              </div>
              <div className="font-mono text-[10px] text-white/50">
                v{status.installedVersion}
                {status.latestVersion && status.installedVersion !== status.latestVersion && (
                  <span className="text-white/30"> → v{status.latestVersion}</span>
                )}
              </div>
            </div>
          </div>
          <button onClick={refresh}
            className="h-7 w-7 grid place-items-center rounded-full hover:bg-white/5 text-white/40 hover:text-white"
            title="Refresh">
            <RefreshCw className="h-3 w-3" strokeWidth={1.5} />
          </button>
        </div>

        <div className="grid grid-cols-2 gap-2 mb-4">
          <StatusPill label="GATEWAY" on={status.gatewayRunning} onLabel="RUNNING" offLabel="STOPPED" />
          <StatusPill label="DASHBOARD" on={status.dashboardAvailable} onLabel="READY" offLabel="N/A" />
        </div>

        <div className="flex items-center gap-2">
          {status.updateAvailable ? (
            <motion.button
              onClick={runUpdate} disabled={updating}
              whileTap={{ scale: 0.97 }}
              className="flex-1 flex items-center justify-center gap-1.5 py-2 rounded-full bg-amber-400 hover:bg-amber-300 disabled:opacity-50 text-black font-mono text-[11px] tracking-[0.18em] font-medium"
              style={{ boxShadow: "0 0 14px rgba(245,180,0,0.3)" }}>
              <Download className="h-3 w-3" strokeWidth={2.5} />
              {updating ? "UPDATING…" : `UPDATE TO v${status.latestVersion}`}
            </motion.button>
          ) : (
            <div className="flex-1 flex items-center justify-center gap-1.5 py-2 rounded-full bg-emerald-400/10 border border-emerald-400/20 text-emerald-300 font-mono text-[11px] tracking-[0.18em]">
              <CheckCircle2 className="h-3 w-3" strokeWidth={2} />
              UP TO DATE
            </div>
          )}
          <button
            onClick={launchDashboard} disabled={launching || !status.installed}
            className="flex items-center justify-center gap-1.5 px-3 py-2 rounded-full border border-white/10 hover:border-white/30 hover:bg-white/5 text-white/70 font-mono text-[11px] tracking-[0.18em] disabled:opacity-40"
            title="Launch hermes dashboard in a new tab">
            <ExternalLink className="h-3 w-3" strokeWidth={2} />
            DASHBOARD
          </button>
        </div>

        {error && (
          <div className="mt-3 rounded-lg border border-rose-400/30 bg-rose-400/[0.06] p-2 font-mono text-[11px] text-rose-300 flex items-center justify-between gap-2">
            <span className="truncate">{error}</span>
            <button onClick={() => setError(null)}><X className="h-3 w-3" /></button>
          </div>
        )}
      </div>

      <AnimatePresence>
        {showLog && (
          <motion.div
            initial={{ height: 0, opacity: 0 }}
            animate={{ height: "auto", opacity: 1 }}
            exit={{ height: 0, opacity: 0 }}
            className="overflow-hidden mt-4"
          >
            <div className="rounded-lg border border-white/[0.06] bg-black/50 overflow-hidden">
              <div className="flex items-center justify-between px-3 py-1.5 border-b border-white/[0.06]">
                <div className="flex items-center gap-1.5">
                  <Terminal className="h-3 w-3 text-white/40" strokeWidth={1.5} />
                  <span className="font-mono text-[9px] tracking-[0.2em] text-white/50">UPDATE LOG</span>
                </div>
                <button onClick={() => setShowLog(false)} className="text-white/40 hover:text-white">
                  <X className="h-3 w-3" />
                </button>
              </div>
              <pre className="font-mono text-[10px] text-white/70 p-3 max-h-40 overflow-y-auto whitespace-pre-wrap">
                {updateLog || "starting…"}
              </pre>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}

function StatusPill({ label, on, onLabel, offLabel }: { label: string; on: boolean; onLabel: string; offLabel: string }) {
  return (
    <div className="rounded-lg border border-white/[0.05] bg-white/[0.015] px-3 py-2">
      <div className="font-mono text-[9px] tracking-[0.2em] text-white/40 mb-0.5">{label}</div>
      <div className="flex items-center gap-1.5">
        <span className={`h-1.5 w-1.5 rounded-full ${on ? "bg-emerald-400" : "bg-white/25"}`}
          style={on ? { boxShadow: "0 0 6px rgba(52,211,153,0.6)" } : {}} />
        <span className={`font-mono text-[11px] tabular-nums ${on ? "text-emerald-300" : "text-white/50"}`}>
          {on ? onLabel : offLabel}
        </span>
      </div>
    </div>
  );
}
EOF
echo "   ✓ control center component created"

# -----------------------------------------------------------------------------
# 8. HermesActivity component
# -----------------------------------------------------------------------------
echo "✏️  Creating components/HermesActivity.tsx"
cat > components/HermesActivity.tsx <<'EOF'
"use client";
import { useEffect, useState, useCallback } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { Radio, Inbox } from "lucide-react";
import AgentAvatar from "./AgentAvatar";

interface KanbanEvent {
  id: number;
  task_id: string;
  kind: string;
  payload: any;
  created_at: string;
  task_title: string | null;
  assignee: string | null;
}

interface EventsResponse {
  events: KanbanEvent[];
  dbExists: boolean;
  error?: string;
}

const KIND_COLOR: Record<string, string> = {
  created:    "#22d3ee",
  promoted:   "#a78bfa",
  claimed:    "#fbbf24",
  spawned:    "#fbbf24",
  heartbeat:  "#7dd3fc",
  completed:  "#34d399",
  blocked:    "#fb7185",
  unblocked:  "#34d399",
  archived:   "#94a3b8",
  reclaimed:  "#fb7185",
  crashed:    "#fb7185",
  timed_out:  "#fb7185",
  gave_up:    "#fb7185",
};

function relTime(iso: string): string {
  try {
    const t = new Date(iso).getTime();
    const ago = Date.now() - t;
    if (ago < 60_000) return `${Math.max(1, Math.floor(ago / 1000))}s ago`;
    if (ago < 3600_000) return `${Math.floor(ago / 60_000)}m ago`;
    if (ago < 86400_000) return `${Math.floor(ago / 3600_000)}h ago`;
    return `${Math.floor(ago / 86400_000)}d ago`;
  } catch { return ""; }
}

export default function HermesActivity() {
  const [state, setState] = useState<EventsResponse | null>(null);
  const [loading, setLoading] = useState(true);

  const refresh = useCallback(async () => {
    try {
      const res = await fetch("/api/hermes/events", { cache: "no-store" });
      const data: EventsResponse = await res.json();
      setState(data);
    } catch {
      setState({ events: [], dbExists: false });
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    refresh();
    const id = setInterval(refresh, 5000);
    return () => clearInterval(id);
  }, [refresh]);

  return (
    <div className="rounded-2xl border border-white/[0.07] bg-white/[0.02] p-5 h-full flex flex-col">
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-2">
          <Radio className="h-3.5 w-3.5 text-amber-400" strokeWidth={1.5} />
          <span className="font-mono text-[10px] tracking-[0.28em] text-white/80">HERMES ACTIVITY</span>
        </div>
        {state?.dbExists && (
          <span className="font-mono text-[9px] tracking-[0.22em] text-emerald-400 flex items-center gap-1.5">
            <motion.span className="h-1 w-1 rounded-full bg-emerald-400"
              animate={{ opacity: [1, 0.3, 1] }} transition={{ duration: 1, repeat: Infinity }} />
            STREAMING
          </span>
        )}
      </div>

      {loading && (
        <div className="font-mono text-[10px] text-white/30 tracking-[0.18em]">LOADING…</div>
      )}

      {!loading && !state?.dbExists && (
        <div className="flex-1 flex flex-col items-center justify-center text-center py-8">
          <Inbox className="h-6 w-6 text-white/25 mb-2" strokeWidth={1.5} />
          <div className="text-[12px] text-white/55">No Hermes activity yet.</div>
          <div className="font-mono text-[10px] text-white/30 mt-1 max-w-[260px] leading-relaxed">
            Send a task to Hermes from the Missions board to see it work in real time.
          </div>
        </div>
      )}

      {!loading && state?.dbExists && state.events.length === 0 && (
        <div className="flex-1 flex flex-col items-center justify-center text-center py-8">
          <Inbox className="h-6 w-6 text-white/25 mb-2" strokeWidth={1.5} />
          <div className="text-[12px] text-white/55">Hermes is idle.</div>
        </div>
      )}

      {!loading && state?.dbExists && state.events.length > 0 && (
        <div className="flex-1 overflow-y-auto space-y-1.5">
          <AnimatePresence initial={false}>
            {state.events.map((e) => {
              const color = KIND_COLOR[e.kind] || "#94a3b8";
              return (
                <motion.div
                  key={e.id}
                  layout
                  initial={{ opacity: 0, x: -8 }}
                  animate={{ opacity: 1, x: 0 }}
                  exit={{ opacity: 0 }}
                  transition={{ duration: 0.2 }}
                  className="flex items-center gap-2.5 rounded-lg border border-white/[0.04] bg-white/[0.015] px-3 py-2"
                >
                  <AgentAvatar agentId="hermes-07" size={20} animated={false} />
                  <span className="font-mono text-[9px] tracking-[0.2em] px-1.5 py-0.5 rounded shrink-0"
                    style={{ background: color + "22", color }}>
                    {e.kind.toUpperCase()}
                  </span>
                  <div className="flex-1 min-w-0">
                    <div className="text-[11px] text-white/85 truncate">
                      {e.task_title || e.task_id}
                    </div>
                    {e.assignee && (
                      <div className="font-mono text-[9px] text-white/40">{e.assignee}</div>
                    )}
                  </div>
                  <span className="font-mono text-[9px] tabular-nums text-white/40 shrink-0">
                    {relTime(e.created_at)}
                  </span>
                </motion.div>
              );
            })}
          </AnimatePresence>
        </div>
      )}
    </div>
  );
}
EOF
echo "   ✓ activity feed component created"

# -----------------------------------------------------------------------------
# 9. Patch OverviewView to include the two new components
# -----------------------------------------------------------------------------
echo "✏️  Patching components/OverviewView.tsx to include Hermes panels"
python3 - <<'PYEOF'
p = "components/OverviewView.tsx"
src = open(p).read()

if "HermesControlCenter" in src:
    print("   ⊙ already patched")
else:
    # add imports
    src = src.replace(
        'import AgentAvatar from "./AgentAvatar";',
        'import AgentAvatar from "./AgentAvatar";\nimport HermesControlCenter from "./HermesControlCenter";\nimport HermesActivity from "./HermesActivity";',
        1
    )
    # Find the "Direct Line" + LiveFeed block and replace the right column (LiveFeed) with a stack:
    # we instead REPLACE that whole block to a 3-col layout: Direct Line | Hermes Control | Live Feed/Activity
    old_block = '''      {/* CHAT SHORTCUT + LIVE FEED */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-3 mb-12">'''
    new_block = '''      {/* HERMES CONTROL CENTER + ACTIVITY */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-3 mb-6">
        <HermesControlCenter />
        <HermesActivity />
      </div>

      {/* CHAT SHORTCUT + LIVE FEED */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-3 mb-12">'''
    src = src.replace(old_block, new_block, 1)
    open(p, "w").write(src)
    print("   ✓ OverviewView patched")
PYEOF

# -----------------------------------------------------------------------------
# 10. Patch MissionsView to add a "Send to Hermes" button on detail modal
# -----------------------------------------------------------------------------
echo "✏️  Patching components/MissionsView.tsx to add Send-to-Hermes"
python3 - <<'PYEOF'
p = "components/MissionsView.tsx"
src = open(p).read()

if "send-to-hermes" in src.lower() or "sendToHermes" in src:
    print("   ⊙ already patched")
else:
    # 1. Add an icon import
    src = src.replace(
        'import { Plus, X, ChevronRight, ChevronUp, Clock, CheckCircle2, Circle, Workflow, Sparkles } from "lucide-react";',
        'import { Plus, X, ChevronRight, ChevronUp, Clock, CheckCircle2, Circle, Workflow, Sparkles, Send } from "lucide-react";',
        1
    )

    # 2. Add helper at top of file (after imports/agent import)
    helper = '''
async function sendMissionToHermes(m: Mission): Promise<{ ok: boolean; task_id?: string; error?: string }> {
  const assignee = AGENTS.find(a => m.agentIds.includes(a.id))?.shortName?.toLowerCase() || undefined;
  const stepLines = m.steps.map(s => `- [${s.done ? "x" : " "}] ${s.label}`).join("\\n");
  const body = [m.brief, "", "## Steps", stepLines].join("\\n");
  try {
    const res = await fetch("/api/hermes/dispatch", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        title: `[${m.id}] ${m.title}`,
        body,
        priority: m.priority === "P0" ? 0 : m.priority === "P1" ? 1 : m.priority === "P2" ? 2 : 3,
      }),
    });
    const data = await res.json();
    return { ok: data.ok, task_id: data.task_id, error: data.error };
  } catch (err: any) {
    return { ok: false, error: err?.message || "dispatch failed" };
  }
}

'''
    src = src.replace(
        "function MissionCard({",
        helper + "function MissionCard({",
        1
    )

    # 3. Wire the "ADVANCE STATUS" button row in MissionDetail to also have a Send-to-Hermes button
    old_row = '''          <div className="flex items-center gap-2 pt-2 border-t border-white/[0.06]">
            <button
              onClick={onAdvance}
              disabled={m.status === "complete"}
              className="flex-1 flex items-center justify-center gap-2 py-2.5 rounded-full bg-amber-400 text-black hover:bg-amber-300 disabled:opacity-40 disabled:cursor-not-allowed font-mono text-[11px] tracking-[0.18em] font-medium"
            >
              <ChevronRight className="h-3.5 w-3.5" strokeWidth={2.5} /> ADVANCE STATUS
            </button>
            <button className="px-4 py-2.5 rounded-full border border-white/10 hover:border-white/30 hover:bg-white/5 font-mono text-[11px] tracking-[0.18em] text-white/70">
              <ChevronUp className="h-3.5 w-3.5 inline mr-1" strokeWidth={2} /> ESCALATE
            </button>
          </div>'''
    new_row = '''          <div className="flex items-center gap-2 pt-2 border-t border-white/[0.06] flex-wrap">
            <button
              onClick={onAdvance}
              disabled={m.status === "complete"}
              className="flex-1 flex items-center justify-center gap-2 py-2.5 rounded-full bg-amber-400 text-black hover:bg-amber-300 disabled:opacity-40 disabled:cursor-not-allowed font-mono text-[11px] tracking-[0.18em] font-medium"
            >
              <ChevronRight className="h-3.5 w-3.5" strokeWidth={2.5} /> ADVANCE STATUS
            </button>
            <button
              onClick={async () => {
                const r = await sendMissionToHermes(m);
                if (r.ok) {
                  alert(`Sent to Hermes${r.task_id ? ` as ${r.task_id}` : ""}.`);
                } else {
                  alert(`Hermes dispatch failed: ${r.error || "unknown error"}`);
                }
              }}
              className="px-4 py-2.5 rounded-full border border-amber-400/30 hover:border-amber-400/60 hover:bg-amber-400/10 font-mono text-[11px] tracking-[0.18em] text-amber-300"
              title="Create a Hermes kanban task from this mission"
            >
              <Send className="h-3.5 w-3.5 inline mr-1" strokeWidth={2} /> SEND TO HERMES
            </button>
            <button className="px-4 py-2.5 rounded-full border border-white/10 hover:border-white/30 hover:bg-white/5 font-mono text-[11px] tracking-[0.18em] text-white/70">
              <ChevronUp className="h-3.5 w-3.5 inline mr-1" strokeWidth={2} /> ESCALATE
            </button>
          </div>'''
    src = src.replace(old_row, new_row, 1)

    open(p, "w").write(src)
    print("   ✓ MissionsView patched with Send to Hermes")
PYEOF

echo ""
echo "✅ Hermes Control Center installed."
echo ""
echo "Restart your dev server (Ctrl+C in npm run dev, then npm run dev again)."
echo ""
echo "What's new:"
echo "   - Overview now shows a Hermes Control Center tile (version, gateway status, update button)"
echo "   - Hermes Activity feed shows kanban events in real time"
echo "   - Each mission's detail modal has a 'SEND TO HERMES' button"
echo ""
echo "Backups in .pre-control-backup/ — to revert: cp -r .pre-control-backup/* ."
