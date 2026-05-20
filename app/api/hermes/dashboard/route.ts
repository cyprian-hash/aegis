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
