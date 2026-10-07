# AEGIS — decision log

Why things are the way they are. One dated entry per architectural call; append, don't rewrite.

- **2026-05 · Mac mini is the primary server.** Always-on, LaunchAgent auto-start; MacBook and
  iPhone are thin clients over Tailscale. No second independent instance — one source of state.
- **2026-05 · GitHub is the source of truth.** Every applied change is committed and pushed.
  Root cause: Claude's build reference drifted from production and patches silently missed
  their anchors; all builds/verification now run against the real repo (or directly on the mini).
- **2026-05 · Tiered curated context over RAG.** Tier 1 always-on global context, Tier 2
  active-project brief, Tier 3 on-demand source docs. Curated briefs beat early-stage retrieval
  on hallucination, stability and cost at this scale. Revisit only when briefs feel insufficient.
- **2026-05 · Chat persistence lives in the vault.** Per-agent `AEGIS/Chats/<id>/thread.json|md`,
  synced via iCloud. Persistence is recall for the user, not memory for the agents.
- **2026-05 · ORACLE-11 gets no attachments.** Perplexity Sonar is text-only; the paperclip is
  disabled there rather than faking a capability that errors. All Claude agents + GEMINI accept files.
- **2026-07 · Memory view shows only real data.** Replaced hardcoded "vectorized docs" theater
  with a live vault browser + keyword search, honestly labeled (no fake embeddings claims).
- **2026-07 · Never trust `which` under LaunchAgents.** The server runs with a minimal PATH;
  Hermes "installed" detection counts a responding gateway on :8642, with absolute-path fallbacks.
- **2026-07 · Vault frontmatter is load-bearing.** The projects grid is built from frontmatter;
  briefs edit only `## Notes`. Colors are quoted hex only (named colors rendered invisible dots).
- **2026-10 · Spend tracking is self-metered, warnings-only.** Token counts captured from each
  provider's own responses into `data/usage.jsonl`; costs are estimates at published prices;
  the daily budget (AEGIS_DAILY_BUDGET) warns at 80%/100% and never blocks a request.
- **2026-10 · Projects are created through the API/modal only.** `POST /api/projects` writes
  correct frontmatter; hand-created files caused the MCD/named-color class of bugs.
- **2026-10 · Memory constellation is dependency-free.** Pure canvas 3D projection, no three.js:
  no npm install risk across the device mount, hydration-safe, deterministic hashed layout.
- **2026-10 · READMEs are housekeeping, not knowledge.** Excluded from memory collection so
  counts and the constellation reflect real briefs/conversations/context only.
- **2026-10 · Claude's direct device access runs read-only git.** A sandboxed `git status` left
  a stale `index.lock` it couldn't delete and blocked local git; Claude edits files and verifies,
  the owner commits, restarts and pushes.
- **2026-10 · Routines + Decisions are AEGIS-native, not a second platform.** After evaluating
  Paperclip (meta-harness for agent orgs), we adopted its two best ideas — scheduled agent runs
  and a human decisions inbox — on the existing chat API and vault instead of adding a new
  platform: runs stay context-grounded and Ledger-tracked, and the owner remains "the board."
  Routine output flags items via a `DECISION:` line convention parsed by the runner.
