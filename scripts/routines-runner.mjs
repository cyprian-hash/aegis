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

async function listProjects(vault) {
  const dir = path.join(vault, "AEGIS", "Projects");
  const out = [];
  for (const f of await fs.readdir(dir)) {
    if (!f.endsWith(".md") || f.toLowerCase() === "readme.md") continue;
    try {
      const raw = await fs.readFile(path.join(dir, f), "utf8");
      const name = (raw.match(/^name:\s*(.+)$/m) || [])[1] || f.replace(/\.md$/, "");
      out.push({ id: f.replace(/\.md$/, ""), name: name.trim() });
    } catch {}
  }
  return out;
}

async function runDistill(r, vault, now, prevRunISO) {
  const lookbackIdx = process.argv.indexOf("--lookback");
  const lookbackHours = lookbackIdx > -1 ? Number(process.argv[lookbackIdx + 1]) : (r.lookbackHours || 24);
  const cutoff = prevRunISO ? new Date(prevRunISO) : new Date(now.getTime() - lookbackHours * 3600_000);
  const chatsDir = path.join(vault, "AEGIS", "Chats");
  const picked = [];
  for (const f of await fs.readdir(chatsDir)) {
    if (!f.endsWith(".md")) continue;
    const full = path.join(chatsDir, f);
    const st = await fs.stat(full);
    if (st.mtime > cutoff) picked.push({ f, full, mtime: st.mtime });
  }
  picked.sort((a, b) => b.mtime - a.mtime);
  const batch = picked.slice(0, 15);
  const day = now.toISOString().slice(0, 10);
  const reportDir = path.join(vault, "AEGIS", "Routines", "memory-distill");
  await fs.mkdir(reportDir, { recursive: true });

  if (batch.length === 0) {
    await fs.writeFile(path.join(reportDir, `${day}.md`),
      `---\nroutine: ${r.id}\nranAt: '${now.toISOString()}'\n---\n\n# Memory Distiller — ${day}\n\nNo chats changed since ${cutoff.toISOString()}. Nothing to distill.\n`, "utf8");
    log("  distill: no recent chats");
    return;
  }

  let corpus = "";
  for (const c of batch) {
    let raw = await fs.readFile(c.full, "utf8");
    if (raw.length > 6000) raw = raw.slice(0, 6000) + "\n…(truncated)";
    corpus += `\n\n===== CHAT FILE: ${c.f} =====\n${raw}`;
    if (corpus.length > 24000) break;
  }

  const projects = await listProjects(vault);
  const projList = projects.map(p => `- ${p.id}: ${p.name}`).join("\n");
  const prompt = `You are the memory distiller for AEGIS. Below are recent conversation transcripts between the Commander and agents. Extract ONLY durable facts worth remembering long-term: decisions made, named people and their roles, deadlines, agreed plans, constraints, preferences, business facts. Skip pleasantries, one-off text edits, and anything transient.

Known projects:
${projList}

Output format — one line per fact, nothing else:
FACT [project-id]: <one-sentence fact>

Use the exact project-id from the list. If a fact clearly belongs to no listed project, omit it. If there are no durable facts, output exactly: NO FACTS

Transcripts:${corpus}`;

  const text = await callAgent(r.agentId, prompt, null);
  const facts = text.split("\n")
    .map(l => l.trim())
    .map(l => l.match(/^FACT\s*\[([a-z0-9-]+)\]:\s*(.+)$/i))
    .filter(Boolean)
    .map(m => ({ id: m[1].toLowerCase(), fact: m[2].trim() }));

  const validIds = new Set(projects.map(p => p.id));
  const written = [], skipped = [];
  for (const { id, fact } of facts) {
    if (!validIds.has(id)) { skipped.push(`${id}: ${fact} (unknown project)`); continue; }
    const briefPath = path.join(vault, "AEGIS", "Projects", `${id}.md`);
    let brief = await fs.readFile(briefPath, "utf8");
    if (brief.includes(fact)) { skipped.push(`${id}: ${fact} (already recorded)`); continue; }
    const line = `- ${day}: ${fact}`;
    if (brief.includes("\n## Learned")) {
      brief = brief.replace(/\n## Learned\s*\n/, `\n## Learned\n\n${line}\n`);
    } else {
      brief = brief.trimEnd() + `\n\n## Learned\n\n${line}\n`;
    }
    await fs.writeFile(briefPath, brief, "utf8");
    written.push(`${id}: ${fact}`);
  }

  const report = `---\nroutine: ${r.id}\nagent: ${r.agentId}\nranAt: '${now.toISOString()}'\n---\n\n# Memory Distiller — ${day}\n\nChats read (${batch.length}): ${batch.map(c => c.f).join(", ")}\n\n## Facts written (${written.length})\n${written.map(w => "- " + w).join("\n") || "_none_"}\n\n## Skipped (${skipped.length})\n${skipped.map(w => "- " + w).join("\n") || "_none_"}\n\n## Raw model output\n\n\u0060\u0060\u0060\n${text.slice(0, 3000)}\n\u0060\u0060\u0060\n`;
  await fs.writeFile(path.join(reportDir, `${day}.md`), report, "utf8");
  log(`  distill: ${batch.length} chats → ${written.length} facts written, ${skipped.length} skipped`);
}

const TEXT_EXT = new Set([".md", ".txt", ".csv", ".json"]);
const CONVERT_EXT = new Set([".docx", ".doc", ".rtf", ".rtfd", ".html"]);

async function extractText(full, ext) {
  const { execFile } = await import("child_process");
  const { promisify } = await import("util");
  const run = promisify(execFile);
  try {
    if (TEXT_EXT.has(ext)) return await fs.readFile(full, "utf8");
    if (CONVERT_EXT.has(ext)) {
      const { stdout } = await run("textutil", ["-convert", "txt", "-stdout", full], { timeout: 30000, maxBuffer: 10_000_000 });
      return stdout;
    }
    if (ext === ".pdf") {
      try {
        const { stdout } = await run("pdftotext", [full, "-"], { timeout: 30000, maxBuffer: 10_000_000 });
        return stdout;
      } catch { return null; } // pdftotext not installed or scanned pdf
    }
  } catch {}
  return null;
}

async function walkFiles(dir, depth = 0, out = []) {
  if (depth > 4) return out;
  let entries = [];
  try { entries = await fs.readdir(dir, { withFileTypes: true }); } catch { return out; }
  for (const e of entries) {
    if (e.name.startsWith(".")) continue;
    const full = path.join(dir, e.name);
    if (e.isDirectory()) await walkFiles(full, depth + 1, out);
    else out.push(full);
  }
  return out;
}

async function runSourceSync(r, vault, now) {
  const statePath = path.join(repo, "data", "source-sync-state.json");
  let st = {};
  try { st = JSON.parse(await fs.readFile(statePath, "utf8")); } catch {}
  const day = now.toISOString().slice(0, 10);
  const reportDir = path.join(vault, "AEGIS", "Routines", "source-sync");
  await fs.mkdir(reportDir, { recursive: true });
  const reportLines = [];

  for (const [projectId, srcDir] of Object.entries(r.sources || {})) {
    const briefPath = path.join(vault, "AEGIS", "Projects", `${projectId}.md`);
    try { await fs.access(briefPath); } catch { reportLines.push(`## ${projectId}\n\n_brief not found; skipped_`); continue; }
    st[projectId] = st[projectId] || {};
    const files = await walkFiles(srcDir);
    const changed = [], skippedFiles = [];
    for (const full of files) {
      const ext = path.extname(full).toLowerCase();
      let stat;
      try { stat = await fs.stat(full); } catch { continue; }
      if (stat.size > 15_000_000) { skippedFiles.push(`${path.basename(full)} (too large)`); continue; }
      const rel = path.relative(srcDir, full);
      if (st[projectId][rel] === stat.mtimeMs) continue; // unchanged — costs nothing
      if (!TEXT_EXT.has(ext) && !CONVERT_EXT.has(ext) && ext !== ".pdf") {
        st[projectId][rel] = stat.mtimeMs; // mark so we don't re-report it forever
        skippedFiles.push(`${rel} (unsupported type ${ext})`);
        continue;
      }
      changed.push({ full, rel, ext, mtimeMs: stat.mtimeMs });
      if (changed.length >= 10) break; // per-run cap; rest picked up next run
    }

    if (changed.length === 0) {
      reportLines.push(`## ${projectId}\n\nNo new or changed documents.${skippedFiles.length ? ` Skipped: ${skippedFiles.join(", ")}` : ""}`);
      continue;
    }

    let corpus = "", extracted = [], failed = [];
    for (const c of changed) {
      const text = await extractText(c.full, c.ext);
      if (!text || !text.trim()) { failed.push(c.rel); st[projectId][c.rel] = c.mtimeMs; continue; }
      let t = text.trim();
      if (t.length > 8000) t = t.slice(0, 8000) + "\n…(truncated)";
      corpus += `\n\n===== DOCUMENT: ${c.rel} =====\n${t}`;
      extracted.push(c);
      if (corpus.length > 20000) break;
    }

    if (!corpus) {
      reportLines.push(`## ${projectId}\n\n${changed.length} changed file(s) but none extractable: ${failed.join(", ")}`);
      await fs.writeFile(statePath, JSON.stringify(st, null, 2), "utf8");
      continue;
    }

    let brief = await fs.readFile(briefPath, "utf8");
    const briefBody = brief.split("## Notes").slice(1).join("## Notes").slice(0, 4000);
    const prompt = `You are the source-document distiller for the AEGIS project "${projectId}". Below are new or updated documents from the project's source folder, plus the current project brief. Extract durable business facts NOT already in the brief: numbers, terms, deadlines, named parties, commitments, plans. Max 10 bullets, each one tight sentence.

Output format — one line per fact, nothing else:
NOTE: <fact>

If the documents add nothing new, output exactly: NO NOTES

Current brief (excerpt):
${briefBody}

New documents:${corpus}`;

    try {
      const text = await callAgent(r.agentId, prompt, projectId);
      const notes = text.split("\n").map(l => l.trim()).filter(l => l.startsWith("NOTE:")).map(l => l.replace(/^NOTE:\s*/, "").trim()).slice(0, 10);
      const fresh = notes.filter(n => !brief.includes(n));
      if (fresh.length) {
        const lines = fresh.map(n => `- ${day}: ${n}`).join("\n");
        if (brief.includes("\n## Source Notes")) {
          brief = brief.replace(/\n## Source Notes\s*\n/, `\n## Source Notes\n\n${lines}\n`);
        } else {
          brief = brief.trimEnd() + `\n\n## Source Notes\n\n${lines}\n`;
        }
        await fs.writeFile(briefPath, brief, "utf8");
      }
      for (const c of extracted) st[projectId][c.rel] = c.mtimeMs;
      reportLines.push(`## ${projectId}\n\nRead: ${extracted.map(c => c.rel).join(", ")}\nNotes written: ${fresh.length}\n${fresh.map(n => "- " + n).join("\n")}${failed.length ? `\nFailed to extract: ${failed.join(", ")}` : ""}${skippedFiles.length ? `\nSkipped: ${skippedFiles.join(", ")}` : ""}`);
      log(`  source-sync ${projectId}: ${extracted.length} docs → ${fresh.length} notes`);
    } catch (e) {
      reportLines.push(`## ${projectId}\n\nDistill call FAILED: ${e.message} (files will retry next run)`);
      log(`  source-sync ${projectId} FAILED: ${e.message}`);
    }
  }

  await fs.writeFile(statePath, JSON.stringify(st, null, 2), "utf8");
  await fs.writeFile(path.join(reportDir, `${day}.md`),
    `---\nroutine: ${r.id}\nranAt: '${now.toISOString()}'\n---\n\n# Source Sync — ${day}\n\n${reportLines.join("\n\n")}\n`, "utf8");
}

async function runLeadsWatch(r, now) {
  const statePath = path.join(repo, "data", "leads-state.json");
  let st = { seen: [] };
  try { st = JSON.parse(await fs.readFile(statePath, "utf8")); } catch {}
  const seen = new Set(st.seen || []);
  const baseline = seen.size === 0;
  const j = await (await fetch(`${BASE}/api/crm`)).json();
  if (!j.ok) throw new Error(j.error || "crm api failed");
  let filed = 0;
  for (const l of j.leads || []) {
    const key = `${l.projectId}:${l.id}`;
    if (seen.has(key)) continue;
    seen.add(key);
    if (baseline || l.status !== "new" || filed >= 5) continue;
    await fileDecision(
      `New lead: ${l.name} — ${l.projectId}`,
      `${l.name} <${l.email}>${l.phone ? " · " + l.phone : ""}\n\n${(l.message || "").slice(0, 600)}\n\nFrom the ${l.projectId} CRM — open the Leads view in AEGIS to respond.`,
      "leads-watch", "claude-prime"
    );
    filed++;
  }
  st.seen = Array.from(seen).slice(-1000);
  await fs.mkdir(path.dirname(statePath), { recursive: true });
  await fs.writeFile(statePath, JSON.stringify(st), "utf8");
  if (baseline) log(`  leads-watch: baseline recorded (${seen.size} existing rows, no decisions)`);
  else if (filed) log(`  leads-watch: ${filed} new lead decision(s) filed`);
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
  const toRun = routines.filter(r => r.enabled !== false && (forceId ? r.id === forceId : (r.kind === "leads-watch" ? true : dueNow(r, state[r.id], now))));
  log(`routines: ${routines.length} defined, ${toRun.length} due${forceId ? ` (forced: ${forceId})` : ""}`);
  if (dry) { toRun.forEach(r => log("  would run:", r.id)); return; }

  const prevState = { ...state };
  for (const r of toRun) {
    log(`running ${r.id} (${r.agentId})...`);
    // mark attempt first so a crash can't cause rapid-fire re-runs
    state[r.id] = now.toISOString();
    await fs.mkdir(path.dirname(statePath), { recursive: true });
    await fs.writeFile(statePath, JSON.stringify(state, null, 2), "utf8");
    try {
      if (r.kind === "memory-distill") {
        await runDistill(r, vault, now, forceId ? null : prevState[r.id]);
        continue;
      }
      if (r.kind === "source-sync") {
        await runSourceSync(r, vault, now);
        continue;
      }
      if (r.kind === "leads-watch") {
        await runLeadsWatch(r, now);
        continue;
      }
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
