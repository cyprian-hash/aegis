import { AGENTS } from "@/lib/agents";

export const runtime = "nodejs";

export async function GET() {
  // strip icon (not serializable) before sending
  const safe = AGENTS.map(({ icon, ...rest }) => rest);
  return Response.json({ agents: safe });
}
