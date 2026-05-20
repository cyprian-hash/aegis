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
