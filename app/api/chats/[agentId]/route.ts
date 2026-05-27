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
  let body: { messages?: StoredMsg[]; append?: { userText: string; agentText: string } };
  try { body = await req.json(); } catch { return new Response(JSON.stringify({ error: "bad json" }), { status: 400 }); }
  const agent = getAgent(params.agentId);
  const name = agent?.name || params.agentId;
  if (body.append) {
    const existing = (await loadThread(params.agentId)) || [];
    const now = new Date().toISOString();
    if (body.append.userText && body.append.userText.trim())
      existing.push({ role: "user", text: body.append.userText, ts: now });
    if (body.append.agentText && body.append.agentText.trim())
      existing.push({ role: "assistant", text: body.append.agentText, ts: now });
    const ok = await saveThread(params.agentId, name, existing);
    return new Response(JSON.stringify({ ok, count: existing.length }), { headers: { "Content-Type": "application/json" } });
  }
  const ok = await saveThread(params.agentId, name, body.messages || []);
  return new Response(JSON.stringify({ ok }), { headers: { "Content-Type": "application/json" } });
}

export async function DELETE(_req: Request, { params }: { params: { agentId: string } }) {
  const ok = await clearThread(params.agentId);
  return new Response(JSON.stringify({ ok }), { headers: { "Content-Type": "application/json" } });
}
