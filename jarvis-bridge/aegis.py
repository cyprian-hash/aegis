"""AEGIS command-center bridge — a native tool bay for Jarvis (brain-jarvis).
Lets the voice brain delegate questions to AEGIS agents and read live status.
Everything stays on this machine: calls go to the AEGIS server on localhost.
Installed by ~/projects/aegis/jarvis-bridge/install-jarvis-bridge.sh
"""
import json
import urllib.request

BASE = "http://127.0.0.1:3000"
CFG = {}


def init(cfg, root):
    global BASE
    CFG.update(cfg or {})
    BASE = (CFG.get("url") or BASE).rstrip("/")


def connected():
    return True  # per-call errors speak for themselves; no startup probe


NATIVE_TOOLS = [
    {
        "name": "aegis_ask_agent",
        "description": (
            "Delegate a question to an agent in the AEGIS command center on this machine. "
            "Agents answer grounded in the Commander's full business knowledge (project briefs, "
            "learned facts, context) — far more than the local vault. Agents: claude-prime "
            "(chief of staff — the default), ledger-12 (spend and finance), oracle-11 (live web "
            "research), plus scout-01, forge-02, archive-03, weaver-04, sentry-05, hermes-07, "
            "gemini-08, herald-09, vanguard-10. Pass a project id to ground the answer in one "
            "business: sotto-i-castagni, dubova-villas, jetpedia, yachtpedia, prive-systems…"
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "agent": {"type": "string", "description": "agent id or spoken name; defaults to claude-prime"},
                "question": {"type": "string", "description": "what to ask the agent"},
                "project": {"type": "string", "description": "optional AEGIS project id for context"},
            },
            "required": ["question"],
        },
    },
    {
        "name": "aegis_status",
        "description": (
            "Live AEGIS command-center status on this machine: open decisions awaiting the "
            "Commander, new CRM leads per business, and today's API spend against budget."
        ),
        "input_schema": {"type": "object", "properties": {}},
    },
]


def native_tools():
    return list(NATIVE_TOOLS)


def _get(path, timeout=6):
    with urllib.request.urlopen(BASE + path, timeout=timeout) as r:
        return json.loads(r.read().decode())


def _resolve_agent(name):
    name = (name or "").strip().lower().replace(".", "-").replace(" ", "-")
    if not name:
        return "claude-prime"
    try:
        agents = _get("/api/agents").get("agents", [])
    except Exception:
        agents = []
    for a in agents:
        if name == (a.get("id") or "").lower():
            return a["id"]
    for a in agents:
        aid = (a.get("id") or "").lower()
        an = (a.get("name") or "").lower().replace(".", "-")
        if aid.startswith(name) or name in an:
            return a["id"]
    return "claude-prime"


def _ask(agent, question, project):
    req = urllib.request.Request(
        BASE + "/api/claude",
        data=json.dumps({
            "agentId": agent,
            "activeProjectId": project or None,
            "messages": [{"role": "user", "content": question}],
        }).encode(),
        headers={"Content-Type": "application/json"},
    )
    text, err, ev = [], "", ""
    with urllib.request.urlopen(req, timeout=180) as r:
        for raw in r:
            line = raw.decode("utf-8", "replace").strip()
            if line.startswith("event:"):
                ev = line[6:].strip()
            elif line.startswith("data:"):
                try:
                    d = json.loads(line[5:].strip())
                except Exception:
                    continue
                if ev == "delta" and d.get("text"):
                    text.append(d["text"])
                elif ev == "error" and d.get("message"):
                    err = d["message"]
    if err:
        raise RuntimeError(err)
    return "".join(text).strip()


def execute(name, inp):
    inp = inp or {}
    try:
        if name == "aegis_ask_agent":
            agent = _resolve_agent(inp.get("agent"))
            question = (inp.get("question") or "").strip()
            if not question:
                return {"error": "no question given"}, True
            project = (inp.get("project") or "").strip() or None
            answer = _ask(agent, question, project)
            return {"agent": agent, "answer": answer[:6000]}, False

        if name == "aegis_status":
            out = {}
            try:
                d = _get("/api/decisions")
                out["open_decisions"] = d.get("openCount", 0)
                out["decision_titles"] = [
                    x.get("title") for x in (d.get("decisions") or [])
                    if x.get("status") == "open"
                ][:5]
            except Exception as e:
                out["decisions_error"] = str(e)[:80]
            try:
                c = _get("/api/crm", timeout=10)
                new = [l for l in (c.get("leads") or []) if l.get("status") == "new"]
                out["new_leads"] = len(new)
                by = {}
                for l in new:
                    pid = l.get("projectId", "?")
                    by[pid] = by.get(pid, 0) + 1
                out["new_leads_by_business"] = by
            except Exception as e:
                out["crm_error"] = str(e)[:80]
            try:
                lj = _get("/api/ledger")
                out["spend_today_usd"] = lj.get("today")
                out["daily_budget_usd"] = lj.get("budget")
            except Exception as e:
                out["ledger_error"] = str(e)[:80]
            return out, False

        return {"error": "unknown aegis tool " + name}, True
    except Exception as e:
        return {"error": "AEGIS unreachable or errored: " + str(e)[:200]}, True
