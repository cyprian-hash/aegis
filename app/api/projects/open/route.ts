import { spawn } from "child_process";
import { promises as fs } from "fs";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function POST(req: Request) {
  let body: { path: string };
  try { body = await req.json(); }
  catch { return new Response(JSON.stringify({ ok: false, error: "Invalid JSON" }), { status: 400 }); }
  if (!body?.path) {
    return new Response(JSON.stringify({ ok: false, error: "path required" }), { status: 400 });
  }
  try {
    await fs.access(body.path);
  } catch {
    return new Response(JSON.stringify({
      ok: false, error: `Path doesn't exist: ${body.path}`,
    }), { status: 404 });
  }

  try {
    const proc = spawn("open", [body.path], { detached: true, stdio: "ignore" });
    proc.unref();
    return new Response(JSON.stringify({ ok: true, opened: body.path }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (err: any) {
    return new Response(JSON.stringify({ ok: false, error: err?.message }), { status: 500 });
  }
}
