#!/usr/bin/env node
// AEGIS routines runner — fired by launchd every 5 min; runs due routines
// through the existing chat API (context-grounded + Ledger-tracked), writes
// results to the vault, and files DECISION: lines into the Decisions inbox.
// Flags: --dry (print due, run nothing) · --force <id> (run one now)
import { promises as fs } from "fs";
import path from "path";
import { fileURLToPath } from "url";

const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const BASE = process.env.AEGIS_BASE_URL || "http://localhost:3000";

function log(...a) { console.log(new Date().toISOString(), ...a); }

async function readEnvLocal() {
  const out = {};
  try {
    const raw = await fs.readFile(path.join(repo, ".env.local"), "utf8");
    for (const line of raw.split("\n")) {
      const m = line.match(/^([A-Z0-9_]+)=(.*)$/);
      if (m) out[m[1]] = m[2].trim();
    }
  } catch {}
  return out;
}

function slug(s) { return s.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, ""); }

function dueNow(r, lastRunISO, now) {
  const s = r.schedule || {};
  const sched = new Date(now);
  sched.setHours(s.hour ?? 9, s.minute ?? 0, 0, 0);
  if (s.freq === "weekly" && now.getDay() !== (s.weekday ?? 1)) return false;
  if (now < sched) return false;
  if (!lastRunISO) return true;
  return new Date(lastRunISO) < sched;
}

async function callAgent(agentId, prompt, projectId) {
  const res = await fetch(`${BASE}/api/claude`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ agentId, activeProjectId: projectId || null, messages: [{ role: "user", content: prompt }] }),
  });
  if (!res.ok || !res.body) throw new Error(`chat API ${res.status}`);
  const reader = res.body.getReader();
  const dec = new TextDecoder();
  let buf = "", ev = "", text = "", errMsg = "";
  for (;;) {
    const { value, done } = await reader.read();
    if (done) break;
    buf += dec.decode(value, { stream: true });
    const lines = buf.split("\n"); buf = lines.pop() || "";
    for (const line of lines) {
      if (line.startsWith("event:")) ev = line.slice(6).trim();
      else if (line.startsWith("data:")) {
        try {
          const d = JSON.parse(line.slice(5).trim());
          if (ev === "delta" && d.text) text += d.text;
          if (ev === "error" && d.message) errMsg = d.message;
        } catch {}
      }
    }
  }
  if (errMsg) throw new Error(errMsg);
  return text.trim();
}

async function fileDecision(title, body, source, agentId) {
  try {
    const res = await fetch(`${BASE}/api/decisions`, {
      method: "POST", headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ title: title.slice(0, 90), body, source, agentId }),
    });
    const j = await res.json();
    log(j.ok ? `  decision filed: ${title.slice(0, 60)}` : `  decision FAILED: ${j.error}`);
  } catch (e) { log("  decision FAILED:", e.message); }
}

async function main() {
  const args = process.argv.slice(2);
  const dry = args.includes("--dry");
  const forceId = args.includes("--force") ? args[args.indexOf("--force") + 1] : null;

  const env = await readEnvLocal();
  const vault = process.env.OBSIDIAN_VAULT || env.OBSIDIAN_VAULT;
  if (!vault) { log("OBSIDIAN_VAULT not set; abort"); process.exit(1); }

  let routines = [];
  try { routines = JSON.parse(await fs.readFile(path.join(vault, "AEGIS", "Routines", "routines.json"), "utf8")); }
  catch (e) { log("no routines.json readable:", e.message); process.exit(0); }

  const statePath = path.join(repo, "data", "routines-state.json");
  let state = {};
  try { state = JSON.parse(await fs.readFile(statePath, "utf8")); } catch {}

  const now = new Date();
  const toRun = routines.filter(r => r.enabled !== false && (forceId ? r.id === forceId : dueNow(r, state[r.id], now)));
  log(`routines: ${routines.length} defined, ${toRun.length} due${forceId ? ` (forced: ${forceId})` : ""}`);
  if (dry) { toRun.forEach(r => log("  would run:", r.id)); return; }

  for (const r of toRun) {
    log(`running ${r.id} (${r.agentId})...`);
    // mark attempt first so a crash can't cause rapid-fire re-runs
    state[r.id] = now.toISOString();
    await fs.mkdir(path.dirname(statePath), { recursive: true });
    await fs.writeFile(statePath, JSON.stringify(state, null, 2), "utf8");
    try {
      let prompt = r.prompt;
      if (r.inject === "ledger") {
        try {
          const lj = await (await fetch(`${BASE}/api/ledger`)).json();
          const sum = { budget: lj.budget, today: lj.today, week: lj.week, month: lj.month, byAgent: (lj.byAgent || []).slice(0, 6) };
          prompt += `\n\nCurrent spend data (JSON):\n${JSON.stringify(sum)}`;
        } catch { prompt += "\n\n(Spend data unavailable this run.)"; }
      }
      const text = await callAgent(r.agentId, prompt, r.project);
      const day = now.toISOString().slice(0, 10);
      const dir = path.join(vault, "AEGIS", "Routines", slug(r.name || r.id));
      await fs.mkdir(dir, { recursive: true });
      const md = `---\nroutine: ${r.id}\nagent: ${r.agentId}\nranAt: '${now.toISOString()}'\n---\n\n# ${r.name || r.id} — ${day}\n\n${text}\n`;
      await fs.writeFile(path.join(dir, `${day}.md`), md, "utf8");
      log(`  result saved (${text.length} chars)`);
      const decisionLines = text.split("\n").filter(l => l.trim().startsWith("DECISION:"));
      for (const dl of decisionLines) {
        const t = dl.replace(/^\s*DECISION:\s*/, "");
        await fileDecision(t, `${t}\n\n— from routine "${r.name || r.id}" (${day}). Full report: AEGIS/Routines/${slug(r.name || r.id)}/${day}.md`, r.name || r.id, r.agentId);
      }
      if (r.alwaysDecision && decisionLines.length === 0) {
        await fileDecision(`${r.name || r.id} — ${day}`, text.slice(0, 1500), r.name || r.id, r.agentId);
      }
    } catch (e) {
      log(`  FAILED: ${e.message}`);
      await fileDecision(`Routine failed: ${r.name || r.id}`, `The scheduled routine "${r.id}" failed at ${now.toISOString()}: ${e.message}`, "routines-runner", r.agentId);
    }
  }
}
main().catch(e => { log("fatal:", e.message); process.exit(1); });
