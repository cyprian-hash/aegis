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
