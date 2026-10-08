import { fetchAllLeads, sourceInfos, updateLead } from "@/lib/crm";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET() {
  try {
    const { leads, errors } = await fetchAllLeads();
    return Response.json({ ok: true, sources: sourceInfos(), leads, errors });
  } catch (e: any) {
    return Response.json({ ok: false, error: e?.message, sources: sourceInfos(), leads: [] }, { status: 500 });
  }
}

export async function PATCH(req: Request) {
  let body: { projectId?: string; id?: string; status?: string; internal_notes?: string };
  try { body = await req.json(); }
  catch { return Response.json({ ok: false, error: "Invalid JSON" }, { status: 400 }); }
  if (!body.projectId || !body.id) return Response.json({ ok: false, error: "projectId and id required" }, { status: 400 });
  if (!body.status && body.internal_notes === undefined) return Response.json({ ok: false, error: "nothing to update" }, { status: 400 });
  try {
    await updateLead(body.projectId, body.id, { status: body.status, internal_notes: body.internal_notes });
    return Response.json({ ok: true });
  } catch (e: any) {
    return Response.json({ ok: false, error: e?.message }, { status: 500 });
  }
}
