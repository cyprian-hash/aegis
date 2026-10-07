import { listDecisions, createDecision, setDecisionStatus } from "@/lib/decisionstore";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET() {
  const decisions = await listDecisions();
  const open = decisions.filter(d => d.status === "open");
  return Response.json({ ok: true, openCount: open.length, decisions: decisions.slice(0, 60) });
}

export async function POST(req: Request) {
  let body: { title?: string; body?: string; source?: string; agentId?: string };
  try { body = await req.json(); } catch { return Response.json({ ok: false, error: "Invalid JSON" }, { status: 400 }); }
  if (!body.title || !body.body) return Response.json({ ok: false, error: "title and body required" }, { status: 400 });
  const d = await createDecision({ title: body.title, body: body.body, source: body.source || "manual", agentId: body.agentId });
  if (!d) return Response.json({ ok: false, error: "OBSIDIAN_VAULT not set" }, { status: 500 });
  return Response.json({ ok: true, decision: d });
}

export async function PATCH(req: Request) {
  let body: { id?: string; status?: "resolved" | "dismissed" | "open" };
  try { body = await req.json(); } catch { return Response.json({ ok: false, error: "Invalid JSON" }, { status: 400 }); }
  if (!body.id || !body.status) return Response.json({ ok: false, error: "id and status required" }, { status: 400 });
  const ok = await setDecisionStatus(body.id, body.status);
  return Response.json({ ok });
}
