# AEGIS Patches

Idempotent patch scripts. Each backs up to a `.pre-*-backup/` folder and is safe to re-run.

## Applying a patch (from anywhere via SSH)
    ssh aegis
    cd ~/projects/aegis && git pull && bash patches/<name>.sh && aegis-control restart

## Convention
- New patches land here, get committed + pushed.
- Other machines apply via `git pull` — no scp needed.
- Historical dependency order: bootstrap -> multiproject -> hydration -> branding -> netty-banks -> projects-level1 -> gemini -> gemini-upload -> hermes -> hermes-control -> context -> herald -> vanguard -> autostart.
