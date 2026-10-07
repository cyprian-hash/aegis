import { execFile } from "child_process";
import { promisify } from "util";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const run = promisify(execFile);

export interface GhRepo {
  fullName: string;
  name: string;
  description: string;
  private: boolean;
  language: string;
  pushedAt: string;
  homepage: string;
}

function norm(r: any): GhRepo {
  return {
    fullName: r.full_name || r.nameWithOwner || "",
    name: r.name || "",
    description: r.description || "",
    private: !!(r.private ?? r.isPrivate),
    language: r.language || r.primaryLanguage?.name || "",
    pushedAt: r.pushed_at || r.pushedAt || "",
    homepage: r.homepage || r.homepageUrl || "",
  };
}

async function viaToken(token: string): Promise<GhRepo[]> {
  const res = await fetch(
    "https://api.github.com/user/repos?per_page=100&sort=pushed&affiliation=owner",
    { headers: { Authorization: `Bearer ${token}`, Accept: "application/vnd.github+json" }, cache: "no-store" }
  );
  if (!res.ok) throw new Error(`GitHub API ${res.status}`);
  return ((await res.json()) as any[]).map(norm);
}

async function viaGhCli(): Promise<GhRepo[]> {
  const { stdout } = await run("gh", [
    "repo", "list", "--limit", "100",
    "--json", "nameWithOwner,name,description,isPrivate,primaryLanguage,pushedAt,homepageUrl",
  ], { timeout: 20000 });
  return (JSON.parse(stdout) as any[]).map(norm);
}

async function viaPublic(user: string): Promise<GhRepo[]> {
  const res = await fetch(
    `https://api.github.com/users/${encodeURIComponent(user)}/repos?per_page=100&sort=pushed`,
    { headers: { Accept: "application/vnd.github+json" }, cache: "no-store" }
  );
  if (!res.ok) throw new Error(`GitHub API ${res.status}`);
  return ((await res.json()) as any[]).map(norm);
}

export async function GET() {
  const errors: string[] = [];
  const token = process.env.GITHUB_TOKEN;

  if (token) {
    try {
      const repos = await viaToken(token);
      return Response.json({ ok: true, source: "token", repos });
    } catch (e: any) { errors.push(`token: ${e?.message}`); }
  }
  try {
    const repos = await viaGhCli();
    return Response.json({ ok: true, source: "gh-cli", repos });
  } catch (e: any) { errors.push(`gh: ${e?.message}`); }
  try {
    const user = process.env.GITHUB_USER || "cyprian-hash";
    const repos = await viaPublic(user);
    return Response.json({
      ok: true, source: "public", repos,
      note: "Public repos only. Add GITHUB_TOKEN to .env.local (repo scope) to list private repos.",
    });
  } catch (e: any) { errors.push(`public: ${e?.message}`); }

  return Response.json({ ok: false, error: errors.join(" | "), repos: [] }, { status: 502 });
}
