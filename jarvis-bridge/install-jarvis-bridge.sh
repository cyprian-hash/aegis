#!/bin/bash
# Installs the AEGIS bridge into the local Jarvis (brain-jarvis v8.1).
# Idempotent: safe to run again; originals backed up as *.pre-aegis-bridge once.
set -e
J="$HOME/.claude/skills/brain-jarvis"
SRC="$(cd "$(dirname "$0")" && pwd)"
[ -f "$J/server.py" ] || { echo "ERROR: Jarvis not found at $J"; exit 1; }

cp "$SRC/aegis.py" "$J/aegis.py"
echo "aegis.py installed"

python3 - "$J" <<'PY'
import sys, os, py_compile, shutil
J = sys.argv[1]

def patch(fname, edits):
    p = os.path.join(J, fname)
    s = open(p).read()
    if "aegis" in s and "AEGIS bridge" in s:
        print(fname, "already patched"); return
    bak = p + ".pre-aegis-bridge"
    if not os.path.exists(bak): shutil.copyfile(p, bak)
    for old, new in edits:
        if old not in s:
            raise SystemExit(f"ANCHOR MISSING in {fname}: {old[:60]!r} — Jarvis version differs; aborting (nothing broken, backup kept).")
        if s.count(old) != 1:
            raise SystemExit(f"ANCHOR NOT UNIQUE in {fname}: {old[:60]!r}; aborting.")
        s = s.replace(old, new)
    open(p, "w").write(s)
    py_compile.compile(p, doraise=True)
    print(fname, "patched + syntax OK")

patch("server.py", [(
"""        except Exception as e:
            print("[gsuite] init failed:", e)""",
"""        except Exception as e:
            print("[gsuite] init failed:", e)
    if TOOLS:  # AEGIS bridge — command-center delegation (localhost only)
        try:
            import aegis as AEGIS_BRIDGE
            AEGIS_BRIDGE.init(CFG.get("aegis") or {}, ROOT)
            TOOLS.CTX["aegis"] = AEGIS_BRIDGE
            print("[aegis] bridge online")
        except Exception as e:
            print("[aegis] init failed:", e)"""
)])

patch("tools.py", [
(
"""READ_TOOLS = {"gmail_unread", "gmail_search", "gmail_read", "gcal_events", "gsheet_read", "gdoc_read", "gdrive_search"}""",
"""READ_TOOLS = {"gmail_unread", "gmail_search", "gmail_read", "gcal_events", "gsheet_read", "gdoc_read", "gdrive_search",
              "aegis_ask_agent", "aegis_status"}  # AEGIS bridge reads ride the same taint guard"""
),
(
"""    native_names = {t["name"] for t in native}""",
"""    ag = CTX.get("aegis")  # AEGIS bridge — command-center tools
    if ag:
        try: native = native + ag.native_tools()
        except Exception: pass
    native_names = {t["name"] for t in native}"""
),
(
"""                used.add(next((v for k, v in fam.items() if b["name"].startswith(k)), "google"))""",
"""                used.add("aegis" if b["name"].startswith("aegis_") else next((v for k, v in fam.items() if b["name"].startswith(k)), "google"))"""
),
(
"""                else:
                    out, is_err = gs.execute(name, b.get("input") or {})""",
"""                elif name.startswith("aegis_"):
                    out, is_err = CTX["aegis"].execute(name, b.get("input") or {})
                else:
                    out, is_err = gs.execute(name, b.get("input") or {})"""
),
])
print("ALL PATCHES APPLIED")
PY
echo "Done. Restart Jarvis to load the bridge."
