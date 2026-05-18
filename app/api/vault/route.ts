import { promises as fs } from "fs";
import path from "path";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

interface VaultRequest {
  kind: "chat" | "mission";
  // For chats: append a user/assistant exchange to today's per-agent daily file
  agentId?: string;
  agentName?: string;
  userText?: string;
  agentText?: string;
  // For missions: write/overwrite a mission file
  missionId?: string;
  missionContent?: string;
}

function getVaultRoot(): string | null {
  const p = process.env.OBSIDIAN_VAULT;
  if (!p) return null;
  return p;
}

async function ensureDir(dir: string) {
  await fs.mkdir(dir, { recursive: true });
}

async function ensureReadme(aegisFolder: string) {
  const readme = path.join(aegisFolder, "README.md");
  try {
    await fs.access(readme);
  } catch {
    const body = `# AEGIS

This folder is auto-populated by [AEGIS Mission Control](http://localhost:3000).

## Layout

- \`Chats/\` — one Markdown file per agent per day. Conversations append to the day's file.
- \`Missions/\` — one Markdown file per mission, updated when the mission's status changes.

Files are plain Markdown — edit, link, or backlink freely. AEGIS will only ever *append* to chat files and *overwrite* mission files when they update.

_Generated: ${new Date().toISOString()}_
`;
    await fs.writeFile(readme, body, "utf8");
  }
}

function todayStamp(): string {
  // YYYY-MM-DD in local time
  const d = new Date();
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${y}-${m}-${day}`;
}

function timeStamp(): string {
  const d = new Date();
  return d.toLocaleTimeString("en-US", { hour12: false });
}

function safeSlug(s: string): string {
  return s
    .toLowerCase()
    .replace(/[^a-z0-9-]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 60) || "untitled";
}

export async function POST(req: Request) {
  const root = getVaultRoot();
  if (!root) {
    return new Response(
      JSON.stringify({ ok: false, error: "OBSIDIAN_VAULT not set in .env.local" }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }

  let body: VaultRequest;
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ ok: false, error: "Invalid JSON" }), { status: 400 });
  }

  const aegisFolder = path.join(root, "AEGIS");
  await ensureDir(aegisFolder);
  await ensureReadme(aegisFolder);

  try {
    if (body.kind === "chat") {
      if (!body.agentId || !body.agentName) {
        return new Response(JSON.stringify({ ok: false, error: "agentId and agentName required for chat" }), { status: 400 });
      }
      const chatsDir = path.join(aegisFolder, "Chats");
      await ensureDir(chatsDir);
      const file = path.join(chatsDir, `${todayStamp()}-${safeSlug(body.agentId)}.md`);

      // If file doesn't exist, write a header first
      let exists = true;
      try { await fs.access(file); } catch { exists = false; }
      if (!exists) {
        const header =
`---
date: ${todayStamp()}
agent: ${body.agentName}
agent_id: ${body.agentId}
type: aegis-chat
tags: [aegis, chat, ${safeSlug(body.agentId)}]
---

# ${body.agentName} — ${todayStamp()}

`;
        await fs.writeFile(file, header, "utf8");
      }

      const entry =
`## ${timeStamp()}

**Commander:** ${body.userText || ""}

**${body.agentName}:** ${body.agentText || ""}

---

`;
      await fs.appendFile(file, entry, "utf8");
      return new Response(JSON.stringify({ ok: true, file }), { headers: { "Content-Type": "application/json" } });
    }

    if (body.kind === "mission") {
      if (!body.missionId || !body.missionContent) {
        return new Response(JSON.stringify({ ok: false, error: "missionId and missionContent required" }), { status: 400 });
      }
      const missionsDir = path.join(aegisFolder, "Missions");
      await ensureDir(missionsDir);
      const file = path.join(missionsDir, `${safeSlug(body.missionId)}.md`);
      await fs.writeFile(file, body.missionContent, "utf8");
      return new Response(JSON.stringify({ ok: true, file }), { headers: { "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ ok: false, error: "Unknown kind" }), { status: 400 });
  } catch (err: any) {
    return new Response(
      JSON.stringify({ ok: false, error: err?.message || "Write failed" }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
}
