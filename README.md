# AEGIS // Mission Control

A terminal-meets-luxury operating system for piloting Claude and a fleet of AI agents from your local machine. Built with Next.js 14, TypeScript, Tailwind, Framer Motion, and the official Anthropic SDK.

```
phosphor amber + electric cyan on obsidian black
seven agents · real chat-app feel · custom SVG sigils
optional Hermes Agent backend · Obsidian vault auto-save
```

## One-command install

```bash
curl -fsSL https://raw.githubusercontent.com/cyprian-hash/aegis/main/install.sh | bash
```

Installs Homebrew → Node → clones the repo → installs dependencies → runs the interactive setup wizard.

The wizard auto-detects whether Hermes Agent is installed, scans for your Obsidian vault in common iCloud locations, and asks for your Anthropic API key. Re-run `./setup.sh` later to reconfigure.

## What's inside

**Seven agents:** CLAUDE.PRIME (reasoning), SCOUT-01 (research), FORGE-02 (code), ARCHIVE-03 (memory), WEAVER-04 (orchestration), SENTRY-05 (safety eval), HERMES-07 (autonomous agent via Hermes).

**Nine views:** Overview, Agents, Chat (with voice input), Missions (kanban), Logs, MCP, Telemetry, Network, Memory.

**Features:** real Anthropic streaming over SSE · optional Hermes Agent backend with terminal/filesystem/web tools · browser-native voice input · Obsidian vault auto-save for chats and missions · animated SVG agent sigils.

## Configuration

All settings live in `.env.local` (gitignored, never committed):

```env
ANTHROPIC_API_KEY=sk-ant-api03-...
HERMES_BASE_URL=http://localhost:8642/v1     # optional
HERMES_API_KEY=local-dev                      # optional
OBSIDIAN_VAULT=/path/to/vault                 # optional
```

## Hermes Agent (optional)

```bash
# Install
curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash

# Enable the gateway
echo "API_SERVER_ENABLED=true" >> ~/.hermes/.env
echo "API_SERVER_KEY=local-dev" >> ~/.hermes/.env

# Run in a separate terminal
hermes gateway
```

Then HERMES-07 in AEGIS becomes fully functional. Docs: https://hermes-agent.nousresearch.com/docs

## Start / stop

```bash
cd ~/projects/aegis
npm run dev                  # AEGIS UI on :3000
hermes gateway               # Hermes (in another terminal tab), optional
```

Ctrl+C to stop.

## License

MIT.
