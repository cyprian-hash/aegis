import { loadThread, saveThread, clearThread, StoredMsg } from "@/lib/chatstore";
import { getAgent } from "@/lib/agents";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET(_req: Request, { params }: { params: { agentId: string } }) {
  const messages = await loadThread(params.agentId);
  return new Response(JSON.stringify({ messages: messages || [] }), {
    headers: { "Content-Type": "application/json" },
  });
}

export async function POST(req: Request, { params }: { params: { agentId: string } }) {
  let body: { messages?: StoredMsg[] };
  try { body = await req.json(); } catch { return new Response(JSON.stringify({ error: "bad json" }), { status: 400 }); }
  const agent = getAgent(params.agentId);
  const name = agent?.name || params.agentId;
  const ok = await saveThread(params.agentId, name, body.messages || []);
  return new Response(JSON.stringify({ ok }), { headers: { "Content-Type": "application/json" } });
}

export async function DELETE(_req: Request, { params }: { params: { agentId: string } }) {
  const ok = await clearThread(params.agentId);
  return new Response(JSON.stringify({ ok }), { headers: { "Content-Type": "application/json" } });
}
