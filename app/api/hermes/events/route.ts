import path from "path";
import os from "os";
import { promises as fs } from "fs";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

interface KanbanEvent {
  id: number;
  task_id: string;
  kind: string;
  payload: any;
  created_at: string;
  task_title: string | null;
  assignee: string | null;
}

export async function GET() {
  const dbPath = path.join(os.homedir(), ".hermes", "kanban.db");

  // Bail gracefully if the DB doesn't exist yet (no kanban activity)
  try {
    await fs.access(dbPath);
  } catch {
    return new Response(JSON.stringify({ events: [], dbExists: false }), {
      headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
    });
  }

  let Database: any;
  try {
    Database = require("better-sqlite3");
  } catch (err: any) {
    return new Response(
      JSON.stringify({ events: [], dbExists: true, error: "better-sqlite3 not installed: " + err.message }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }

  try {
    const db = new Database(dbPath, { readonly: true, fileMustExist: true });
    // The Hermes schema may or may not include these columns; try the rich query first,
    // fall back to a minimal one.
    let rows: any[] = [];
    try {
      rows = db.prepare(`
        SELECT
          e.id, e.task_id, e.kind, e.payload, e.created_at,
          t.title AS task_title, t.assignee AS assignee
        FROM task_events e
        LEFT JOIN tasks t ON t.id = e.task_id
        ORDER BY e.id DESC
        LIMIT 60
      `).all();
    } catch {
      try {
        rows = db.prepare(`
          SELECT id, task_id, kind, payload, created_at
          FROM task_events
          ORDER BY id DESC
          LIMIT 60
        `).all();
      } catch {
        rows = [];
      }
    }
    db.close();

    const events: KanbanEvent[] = rows.map((r: any) => ({
      id: r.id,
      task_id: r.task_id,
      kind: r.kind,
      payload: (() => { try { return JSON.parse(r.payload || "{}"); } catch { return {}; } })(),
      created_at: r.created_at,
      task_title: r.task_title || null,
      assignee: r.assignee || null,
    }));

    return new Response(JSON.stringify({ events, dbExists: true }), {
      headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
    });
  } catch (err: any) {
    return new Response(
      JSON.stringify({ events: [], dbExists: true, error: err?.message || "DB read failed" }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
}
