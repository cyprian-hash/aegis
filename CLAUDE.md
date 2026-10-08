# AEGIS Mission Control

12-agent AI fleet dashboard. Next.js 14 App Router, TypeScript, Tailwind, Framer Motion.
Runs on the Mac mini (`cypmacmini@Cyprians-Mac-mini`) as the always-on server via LaunchAgents;
MacBook and iPhone are clients over Tailscale. **GitHub (`cyprian-hash/aegis`) is the source of truth.**

## Run & operate

- `aegis-control start|stop|restart|status|logs [aegis|hermes]` — manages both LaunchAgents
  (`com.aegis.dev`, `com.hermes.gateway`). Logs in `~/Library/Logs/aegis/`.
- Dev server on :3000 (dev mode — **TS errors do NOT block it; always run `npx tsc --noEmit` after changes**).
- Hermes Agent gateway on `localhost:8642` (HERMES-07 depends on it).
- LaunchAgent PATH is minimal: never rely on `which <tool>` from server code (see decisions.md 2026-07).

## Architecture map

- `app/api/claude/route.ts` — the chat API. Branches by model: `sonar*` → Perplexity,
  `gemini*` → Google, `isHermesAgent` → localhost:8642, else Anthropic (streaming SSE:
  meta/delta/done/error). Injects `composedSystem` from `lib/context.ts` (global Context files
  + active project brief, 8,000-char cap). Logs token usage per call via `lib/usagelog.ts`.
- `lib/agents.ts` — the 12 agents (PRIME, SCOUT, FORGE, ARCHIVE, WEAVER, SENTRY, HERMES-07,
  GEMINI-08, HERALD-09, VANGUARD-10, ORACLE-11, LEDGER-12). `Agent.color` is a hex string
  keyed into `lib/theme.ts` COLOR_MAP. Sigils in `components/AgentAvatar.tsx` (SIGILS by agent id).
- `app/api/projects/route.ts` — projects are read from vault markdown frontmatter (gray-matter).
  POST creates/updates a project file with correct frontmatter — **always create projects via
  this API or the UI modal, never by hand**.
- `app/api/memory/route.ts` — vault inventory, keyword search, `?list=1` for the constellation.
  READMEs are excluded. `app/api/ledger/route.ts` + `data/usage.jsonl` — API spend tracking
  (estimates at published prices; warnings only, never blocks).
- `lib/chatstore.ts` — per-agent resumable threads at `AEGIS/Chats/<agent-id>/thread.json|md`.
- **Routines** — scheduled agent runs. Definitions in vault `AEGIS/Routines/routines.json`;
  `scripts/routines-runner.mjs` is fired every 5 min by the `com.aegis.routines` LaunchAgent
  (installed by `scripts/install-routines-agent.sh`), calls the chat API (so runs are
  context-grounded and Ledger-tracked), writes reports to `AEGIS/Routines/<name>/<date>.md`,
  and files lines starting `DECISION:` into the Decisions inbox. State in `data/routines-state.json`.
  Test one: `node scripts/routines-runner.mjs --force <id>` (or `--dry`).
- **Decisions inbox** — `lib/decisionstore.ts` + `/api/decisions` + `components/DecisionsView.tsx`;
  items live in vault `AEGIS/Decisions/<id>.md` (frontmatter status: open/resolved/dismissed).
  Sidebar badge polls the open count.

## The Obsidian vault (agent memory)

Path from `OBSIDIAN_VAULT` in `.env.local` (iCloud-synced:
`~/Library/Mobile Documents/iCloud~md~obsidian/Documents/cyp vault`).
- `AEGIS/Context/` — global context, injected into EVERY agent call. Keep tight; never put
  logs or growing files here.
- `AEGIS/Projects/<id>.md` — project files. YAML frontmatter is what makes AEGIS recognize
  the file; **when briefing, edit only below `## Notes` — never touch the frontmatter**.
  `color` must be a quoted hex (named colors break the UI dots).
- `AEGIS/Projects/<id>/source-docs|strategies/` — per-project reference (not auto-loaded).
- Memory strategy is tiered curated briefs, NOT RAG — deliberate (decisions.md 2026-05).

## Working rules

- `.env.local` holds all keys (ANTHROPIC/GEMINI/PERPLEXITY_API_KEY, AEGIS_DAILY_BUDGET,
  OBSIDIAN_VAULT). Never commit it, never echo keys.
- After any change: `npx tsc --noEmit`, then verify the edit landed (grep for it), then
  `aegis-control restart`. A successful commit does not prove a change applied — grep does.
- Commit and push after every applied change so GitHub never drifts from the running code.
- `patches/` holds the historical patch scripts (idempotent, `.pre-*-backup/` convention);
  current workflow is direct edits with the same verify discipline.
- Agents inside AEGIS do content/strategy only — they cannot modify AEGIS's own code.
- See `decisions.md` for why things are the way they are before changing them.

## Memory distillation
- Routine kind `memory-distill` in routines runner: nightly 03:40, reads chats modified since last run, asks claude-prime for `FACT [project-id]:` lines, appends them dated under `## Learned` in that project's brief (frontmatter untouched; exact-duplicate lines skipped). Report in vault `AEGIS/Routines/memory-distill/`.
- `## Learned` is injected into agent context automatically via loadProjectContext (full brief body).
- Test: `node scripts/routines-runner.mjs --force memory-distill --lookback <hours>`.
- Known gap: runner marks state BEFORE running, so a run that fails while the server is down (e.g. Mac just woke) is skipped until the next scheduled day and files no Decision.

## Source docs sync
- Routine kind `source-sync` (weekly Mon 07:30): per-project folder map lives in the routine's `sources` in vault routines.json. Incremental by mtime — unchanged files cost zero tokens; ≤10 changed files per run, local extraction (textutil for docx/rtf, pdftotext for PDFs if installed, plain read for md/txt/csv; xlsx unsupported), distilled by claude-prime into dated bullets under `## Source Notes` in the project brief. State: data/source-sync-state.json. Reports: vault AEGIS/Routines/source-sync/.
- Test: `node scripts/routines-runner.mjs --force source-sync`.

## Per-project CRM (Leads)
- Each business keeps leads in its own Supabase project: dubova-villas `enquiries`, jetpedia `aircraft_inquiries` (both have status + internal_notes pipeline columns). Config in lib/crm.ts; per-project SERVICE ROLE keys in .env.local (CRM_DUBOVA_KEY, CRM_JETPEDIA_KEY) — never commit or echo.
- /api/crm GET lists normalized leads across sources, PATCH updates status/notes. LeadsView = Leads nav entry.
- Runner kind `leads-watch` runs every launchd pass: diffs lead ids vs data/leads-state.json, files a Decision per new lead (first run records baseline silently).
