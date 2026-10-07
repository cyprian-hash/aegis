import { promises as fs } from "fs";
import path from "path";
import os from "os";
import { execFile } from "child_process";
import { promisify } from "util";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const run = promisify(execFile);
const REPO_RE = /^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/;

export async function POST(req: Request) {
  let body: { repo?: string };
  try { body = await req.json(); }
  catch { return Response.json({ ok: false, error: "Invalid JSON" }, { status: 400 }); }

  const repo = (body.repo || "").trim();
  if (!REPO_RE.test(repo) || repo.includes("..")) {
    return Response.json({ ok: false, error: "repo must be owner/name" }, { status: 400 });
  }
  const name = repo.split("/")[1];
  const baseDir = process.env.PROJECTS_DIR || path.join(os.homedir(), "projects");
  const dest = path.join(baseDir, name);

  // already cloned?
  try {
    await fs.access(path.join(dest, ".git"));
    return Response.json({ ok: true, existing: true, localPath: dest });
  } catch { /* not cloned yet */ }

  await fs.mkdir(baseDir, { recursive: true });

  const attempts = [
    `git@github.com:${repo}.git`,
    `https://github.com/${repo}.git`,
  ];
  const errors: string[] = [];
  for (const url of attempts) {
    try {
      await run("git", ["clone", "--depth", "1", url, dest], {
        timeout: 120000,
        env: { ...process.env, GIT_TERMINAL_PROMPT: "0", GIT_SSH_COMMAND: "ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new" },
      });
      return Response.json({ ok: true, existing: false, localPath: dest, via: url.startsWith("git@") ? "ssh" : "https" });
    } catch (e: any) {
      errors.push(`${url}: ${(e?.stderr || e?.message || "").toString().slice(0, 300)}`);
      try { await fs.rm(dest, { recursive: true, force: true }); } catch { /* ignore */ }
    }
  }
  return Response.json({ ok: false, error: errors.join(" || ") }, { status: 502 });
}
