// Per-project CRM sources — each business keeps its own Supabase database and
// its own leads table; AEGIS reads them with per-project service keys from .env.local.
export interface CrmLead {
  id: string; projectId: string; name: string; email: string;
  phone?: string; message?: string; created: string; status: string;
  internalNotes?: string;
  extra: Record<string, string>;
}
export interface CrmSourceInfo {
  projectId: string; label: string; configured: boolean; statuses: string[]; keyEnv: string; error?: string;
}

interface SourceCfg {
  projectId: string; label: string; url: string; keyEnv: string; table: string;
  statuses: string[]; nameFields: string[]; emailField: string; phoneField?: string;
  messageField?: string; createdField: string; extraFields: string[];
}

export const CRM_SOURCES: SourceCfg[] = [
  {
    projectId: "dubova-villas", label: "Dubova Villas",
    url: "https://ukwhtzdxbxfwldcpxczh.supabase.co", keyEnv: "CRM_DUBOVA_KEY",
    table: "enquiries",
    statuses: ["new", "contacted", "qualified", "viewing", "won", "lost"],
    nameFields: ["first_name", "last_name"], emailField: "email", phoneField: "phone",
    messageField: "message", createdField: "created_at",
    extraFields: ["preferred_villa", "buyer_type", "purchase_route", "timeframe", "meeting_type", "country_city"],
  },
  {
    projectId: "jetpedia", label: "Jetpedia",
    url: "https://isqgkwkncjjawqtyyhqd.supabase.co", keyEnv: "CRM_JETPEDIA_KEY",
    table: "aircraft_inquiries",
    statuses: ["new", "contacted", "qualified", "won", "lost"],
    nameFields: ["name"], emailField: "email",
    messageField: "message", createdField: "created_at",
    extraFields: ["aircraft", "company"],
  },
];

function cfgFor(projectId: string): SourceCfg | undefined {
  return CRM_SOURCES.find(s => s.projectId === projectId);
}

export function sourceInfos(): CrmSourceInfo[] {
  return CRM_SOURCES.map(s => ({
    projectId: s.projectId, label: s.label, statuses: s.statuses, keyEnv: s.keyEnv,
    configured: !!process.env[s.keyEnv],
  }));
}

export async function fetchSourceLeads(cfg: SourceCfg): Promise<CrmLead[]> {
  const key = process.env[cfg.keyEnv];
  if (!key) return [];
  const res = await fetch(
    `${cfg.url}/rest/v1/${cfg.table}?select=*&order=${cfg.createdField}.desc&limit=200`,
    { headers: { apikey: key, Authorization: `Bearer ${key}` }, cache: "no-store" }
  );
  if (!res.ok) throw new Error(`${cfg.label}: supabase ${res.status}`);
  const rows = (await res.json()) as any[];
  return rows.map(r => {
    const extra: Record<string, string> = {};
    for (const f of cfg.extraFields) if (r[f]) extra[f] = String(r[f]);
    return {
      id: String(r.id), projectId: cfg.projectId,
      name: cfg.nameFields.map(f => r[f]).filter(Boolean).join(" ") || "(no name)",
      email: r[cfg.emailField] || "",
      phone: cfg.phoneField ? r[cfg.phoneField] || undefined : undefined,
      message: cfg.messageField ? r[cfg.messageField] || undefined : undefined,
      created: r[cfg.createdField] || "",
      status: r.status || "new",
      internalNotes: r.internal_notes || undefined,
      extra,
    };
  });
}

export async function fetchAllLeads(): Promise<{ leads: CrmLead[]; errors: string[] }> {
  const leads: CrmLead[] = []; const errors: string[] = [];
  await Promise.all(CRM_SOURCES.map(async cfg => {
    try { leads.push(...await fetchSourceLeads(cfg)); }
    catch (e: any) { errors.push(e?.message || `${cfg.label} failed`); }
  }));
  leads.sort((a, b) => (a.created < b.created ? 1 : -1));
  return { leads, errors };
}

export async function updateLead(projectId: string, id: string, patch: { status?: string; internal_notes?: string }): Promise<void> {
  const cfg = cfgFor(projectId);
  if (!cfg) throw new Error("unknown CRM source");
  const key = process.env[cfg.keyEnv];
  if (!key) throw new Error(`${cfg.keyEnv} not set`);
  if (patch.status && !cfg.statuses.includes(patch.status)) throw new Error("invalid status");
  const res = await fetch(`${cfg.url}/rest/v1/${cfg.table}?id=eq.${encodeURIComponent(id)}`, {
    method: "PATCH",
    headers: { apikey: key, Authorization: `Bearer ${key}`, "Content-Type": "application/json", Prefer: "return=minimal" },
    body: JSON.stringify(patch),
  });
  if (!res.ok) throw new Error(`update failed: ${res.status}`);
}
