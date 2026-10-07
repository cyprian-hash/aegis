import { exec } from "child_process";
import { promisify } from "util";

const execAsync = promisify(exec);

/** Resolve the hermes binary. `which` fails under LaunchAgent (minimal PATH), so also try known install locations. */
export async function findHermesPath(): Promise<string | null> {
  try {
    const { stdout } = await execAsync("which hermes", { timeout: 3000 });
    if (stdout.trim()) return stdout.trim();
  } catch { /* fall through */ }
  const home = process.env.HOME || "";
  const candidates = [
    `${home}/.local/bin/hermes`,
    "/opt/homebrew/bin/hermes",
    "/usr/local/bin/hermes",
    `${home}/.hermes/bin/hermes`,
  ];
  for (const c of candidates) {
    try { await execAsync(`test -x "${c}"`, { timeout: 1500 }); return c; } catch { /* next */ }
  }
  return null;
}

/** PATH with common bin dirs appended, for child processes spawned under LaunchAgent's minimal PATH. */
export function augmentedPath(): string {
  const home = process.env.HOME || "";
  const extra = [`${home}/.local/bin`, "/opt/homebrew/bin", "/usr/local/bin", `${home}/.hermes/bin`];
  const cur = (process.env.PATH || "").split(":");
  return Array.from(new Set([...cur, ...extra])).filter(Boolean).join(":");
}

/** Health-check the Hermes gateway (same logic as the status card). */
export async function gatewayUp(): Promise<boolean> {
  const baseUrl = process.env.HERMES_BASE_URL || "http://localhost:8642/v1";
  try {
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
