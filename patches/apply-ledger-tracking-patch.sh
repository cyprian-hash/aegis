#!/usr/bin/env bash
# apply-ledger-tracking-patch.sh
# API spend tracking + budget warnings ("Ledger" sidebar view).
#  - Logs REAL token usage from every Anthropic / Gemini / Perplexity call
#    (token counts come from each provider's own response) to data/usage.jsonl
#  - /api/ledger aggregates: today / 7d / 30d, by agent, by model
#  - Cost = tokens x published per-token prices (honest ESTIMATES; provider
#    bill is ground truth). Hermes = local = $0 (not logged).
#  - Daily budget via AEGIS_DAILY_BUDGET in .env.local (default $10).
#    WARNINGS ONLY at 80% / 100% — never blocks requests.
# Built/verified against the real repo.
set -e
if [ ! -f app/api/claude/route.ts ] || [ ! -f components/Sidebar.tsx ]; then
  echo "❌ Run from inside the aegis project directory."; exit 1
fi

echo "📦 Backing up to .pre-ledgerview-backup/"
mkdir -p .pre-ledgerview-backup/components .pre-ledgerview-backup/app/api/claude .pre-ledgerview-backup/app
cp app/api/claude/route.ts .pre-ledgerview-backup/app/api/claude/
cp components/Sidebar.tsx  .pre-ledgerview-backup/components/
cp app/page.tsx            .pre-ledgerview-backup/app/

# ----------------------------------------------------------------------------
# 1. lib/usagelog.ts — logger + pricing + cost estimation (shared)
# ----------------------------------------------------------------------------
echo "✏️  Creating lib/usagelog.ts"
cat > lib/usagelog.ts <<'TSEOF'
import { promises as fs } from "fs";
import path from "path";

export interface UsageEntry {
  ts: string;            // ISO timestamp
  agentId: string;
  model: string;
  provider: "anthropic" | "gemini" | "perplexity";
  inputTokens: number;
  outputTokens: number;
}

// Published per-1M-token prices (USD). ESTIMATES — the provider bill is truth.
// Prefix-matched so model variants resolve.
const PRICING: [prefix: string, inPerM: number, outPerM: number][] = [
  ["claude-opus",   15,   75],
  ["claude-sonnet",  3,   15],
  ["claude-haiku",   1,    5],
  ["gemini",         2,   12],
  ["sonar",          1,    1],
];

export function estimateCost(model: string, inputTokens: number, outputTokens: number): number {
  const row = PRICING.find(([p]) => model.startsWith(p));
  if (!row) return 0;
  return (inputTokens * row[1] + outputTokens * row[2]) / 1_000_000;
}

function logFile(): string {
  return path.join(process.cwd(), "data", "usage.jsonl");
}

export async function logUsage(e: Omit<UsageEntry, "ts">): Promise<void> {
  try {
    const entry: UsageEntry = { ts: new Date().toISOString(), ...e };
    const file = logFile();
    await fs.mkdir(path.dirname(file), { recursive: true });
    await fs.appendFile(file, JSON.stringify(entry) + "\n", "utf8");
  } catch { /* never break a chat over logging */ }
}

export async function readUsage(): Promise<UsageEntry[]> {
  try {
    const raw = await fs.readFile(logFile(), "utf8");
    return raw.split("\n").filter(Boolean).map(l => { try { return JSON.parse(l); } catch { return null; } }).filter(Boolean);
  } catch { return []; }
}
TSEOF
echo "   ✓ lib/usagelog.ts created (logger + pricing estimates)"

# ----------------------------------------------------------------------------
# 2. Hook usage logging into the three provider branches in route.ts
# ----------------------------------------------------------------------------
echo "✏️  Hooking usage capture into app/api/claude/route.ts"
python3 - <<'PYEOF'
p = "app/api/claude/route.ts"; src = open(p).read()
changed = []

# Import
old_imp = 'import { AGENTS, getAgent, isHermesAgent } from "@/lib/agents";'
if old_imp in src and "usagelog" not in src:
    src = src.replace(old_imp, old_imp + '\nimport { logUsage } from "@/lib/usagelog";', 1)
    changed.append("logUsage imported")

# --- Anthropic branch: capture input/output tokens from stream events ---
old_loop = '''        for await (const event of response) {
          if (event.type === "content_block_delta" && event.delta.type === "text_delta") {
            send("delta", { text: event.delta.text });
          } else if (event.type === "message_stop") {
            send("done", { ok: true });
          }
        }'''
new_loop = '''        let usageIn = 0, usageOut = 0;
        for await (const event of response) {
          if (event.type === "content_block_delta" && event.delta.type === "text_delta") {
            send("delta", { text: event.delta.text });
          } else if (event.type === "message_start") {
            usageIn = (event as any).message?.usage?.input_tokens || 0;
          } else if (event.type === "message_delta") {
            usageOut = (event as any).usage?.output_tokens ?? usageOut;
          } else if (event.type === "message_stop") {
            logUsage({ agentId: agent.id, model: body.model || agent.model, provider: "anthropic", inputTokens: usageIn, outputTokens: usageOut });
            send("done", { ok: true });
          }
        }'''
if old_loop in src:
    src = src.replace(old_loop, new_loop, 1); changed.append("Anthropic usage captured (real token counts)")

# --- Perplexity branch ---
old_cit = '          let citations: string[] = [];'
if old_cit in src:
    src = src.replace(old_cit, old_cit + '\n          let pplxUsage: any = null;', 1)
    changed.append("Perplexity usage var added")
old_cap = 'if (Array.isArray(json.citations) && json.citations.length) citations = json.citations;'
if old_cap in src:
    src = src.replace(old_cap, old_cap + '\n                if (json.usage) pplxUsage = json.usage;', 1)
    changed.append("Perplexity usage captured")
old_done_p = '''          send("done", { ok: true });
          controller.close();
        } catch (err: any) {
          send("error", { message: err?.message || "Perplexity request failed" });'''
new_done_p = '''          if (pplxUsage) logUsage({ agentId: agent.id, model, provider: "perplexity", inputTokens: pplxUsage.prompt_tokens || 0, outputTokens: pplxUsage.completion_tokens || 0 });
          send("done", { ok: true });
          controller.close();
        } catch (err: any) {
          send("error", { message: err?.message || "Perplexity request failed" });'''
if old_done_p in src:
    src = src.replace(old_done_p, new_done_p, 1); changed.append("Perplexity usage logged on done")

# --- Gemini branch ---
old_buf = '          let buf = "";'
if old_buf in src:
    src = src.replace(old_buf, old_buf + '\n          let gemUsage: any = null;', 1)
    changed.append("Gemini usage var added")
old_parts = 'const parts = json?.candidates?.[0]?.content?.parts;'
if old_parts in src:
    src = src.replace(old_parts, old_parts + '\n                if (json?.usageMetadata) gemUsage = json.usageMetadata;', 1)
    changed.append("Gemini usage captured")
old_done_g = '''          send("done", { ok: true });
        } catch (err: any) {
          send("error", { message: err?.message || "Gemini stream failed" });'''
new_done_g = '''          if (gemUsage) logUsage({ agentId: agent.id, model: effectiveModel, provider: "gemini", inputTokens: gemUsage.promptTokenCount || 0, outputTokens: gemUsage.candidatesTokenCount || 0 });
          send("done", { ok: true });
        } catch (err: any) {
          send("error", { message: err?.message || "Gemini stream failed" });'''
if old_done_g in src:
    src = src.replace(old_done_g, new_done_g, 1); changed.append("Gemini usage logged on done")

open(p, "w").write(src)
for c in changed: print(f"   ✓ {c}")
if len(changed) < 7: print(f"   ⚠ only {len(changed)}/7 route changes applied — check anchors")
PYEOF

# ----------------------------------------------------------------------------
# 3. /api/ledger — aggregation endpoint
# ----------------------------------------------------------------------------
echo "✏️  Creating app/api/ledger/route.ts"
mkdir -p app/api/ledger
cat > app/api/ledger/route.ts <<'TSEOF'
import { readUsage, estimateCost } from "@/lib/usagelog";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET() {
  const entries = await readUsage();
  const now = Date.now();
  const DAY = 86400_000;
  const budget = parseFloat(process.env.AEGIS_DAILY_BUDGET || "10");

  const withCost = entries.map(e => ({ ...e, cost: estimateCost(e.model, e.inputTokens, e.outputTokens) }));

  const todayStart = new Date(); todayStart.setUTCHours(0, 0, 0, 0);
  const inWindow = (e: any, ms: number) => now - new Date(e.ts).getTime() <= ms;
  const today = withCost.filter(e => new Date(e.ts).getTime() >= todayStart.getTime());
  const week  = withCost.filter(e => inWindow(e, 7 * DAY));
  const month = withCost.filter(e => inWindow(e, 30 * DAY));

  const sum = (arr: any[]) => arr.reduce((s, e) => s + e.cost, 0);
  const group = (arr: any[], key: string) => {
    const m: Record<string, { cost: number; calls: number; inTok: number; outTok: number }> = {};
    for (const e of arr) {
      const k = e[key] || "unknown";
      m[k] = m[k] || { cost: 0, calls: 0, inTok: 0, outTok: 0 };
      m[k].cost += e.cost; m[k].calls += 1; m[k].inTok += e.inputTokens; m[k].outTok += e.outputTokens;
    }
    return Object.entries(m).map(([name, v]) => ({ name, ...v })).sort((a, b) => b.cost - a.cost);
  };

  const todaySpend = sum(today);
  return Response.json({
    ok: true,
    budget,
    today: { spend: todaySpend, calls: today.length, pct: budget > 0 ? (todaySpend / budget) * 100 : 0 },
    week:  { spend: sum(week),  calls: week.length },
    month: { spend: sum(month), calls: month.length },
    byAgent: group(month, "agentId"),
    byModel: group(month, "model"),
    recent: withCost.slice(-12).reverse().map(e => ({ ts: e.ts, agentId: e.agentId, model: e.model, inTok: e.inputTokens, outTok: e.outputTokens, cost: e.cost })),
    note: "Costs are estimates from published per-token prices; the provider bill is ground truth. Tracks AEGIS usage only, from install date.",
  });
}
TSEOF
echo "   ✓ /api/ledger created (aggregation + budget)"

# ----------------------------------------------------------------------------
# 4. components/LedgerView.tsx
# ----------------------------------------------------------------------------
echo "✏️  Creating components/LedgerView.tsx"
cat > components/LedgerView.tsx <<'TSEOF'
"use client";
import { useEffect, useState } from "react";
import { motion } from "framer-motion";
import { Wallet, TrendingUp, AlertTriangle, Bot, Cpu, Loader2 } from "lucide-react";
import StatTile from "./StatTile";
import SectionHeader from "./SectionHeader";
import { COLOR_MAP } from "@/lib/theme";
import { getAgent } from "@/lib/agents";

interface Group { name: string; cost: number; calls: number; inTok: number; outTok: number; }
interface Ledger {
  ok: boolean; budget: number;
  today: { spend: number; calls: number; pct: number };
  week: { spend: number; calls: number };
  month: { spend: number; calls: number };
  byAgent: Group[]; byModel: Group[];
  recent: { ts: string; agentId: string; model: string; inTok: number; outTok: number; cost: number }[];
  note: string;
}

const usd = (n: number) => n < 0.01 && n > 0 ? "<$0.01" : `$${n.toFixed(2)}`;
const ago = (iso: string) => {
  const s = Math.floor((Date.now() - new Date(iso).getTime()) / 1000);
  if (s < 60) return `${s}s`; if (s < 3600) return `${Math.floor(s/60)}m`;
  if (s < 86400) return `${Math.floor(s/3600)}h`; return `${Math.floor(s/86400)}d`;
};

export default function LedgerView() {
  const [data, setData] = useState<Ledger | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetch("/api/ledger").then(r => r.json()).then(setData).catch(() => null).finally(() => setLoading(false));
    const id = setInterval(() => fetch("/api/ledger").then(r => r.json()).then(setData).catch(() => null), 30000);
    return () => clearInterval(id);
  }, []);

  const pct = data?.today.pct ?? 0;
  const warn = pct >= 80 && pct < 100;
  const over = pct >= 100;
  const barColor = over ? "#E11D48" : warn ? "#f5b400" : "#34d399";

  return (
    <div>
      <SectionHeader kicker="SYSTEM / LEDGER" title="API Spend & Safety" />

      {(warn || over) && (
        <motion.div initial={{ opacity: 0, y: -6 }} animate={{ opacity: 1, y: 0 }}
          className={`rounded-2xl border p-4 mb-6 flex items-center gap-3 ${over ? "border-rose-500/30 bg-rose-500/[0.06]" : "border-amber-400/30 bg-amber-400/[0.06]"}`}>
          <AlertTriangle className={`h-4 w-4 ${over ? "text-rose-400" : "text-amber-400"}`} />
          <div className="text-[13px] text-white/80">
            {over
              ? <>Today&apos;s estimated spend is <b>over budget</b> ({usd(data!.today.spend)} of ${data!.budget}/day). Requests are NOT blocked — this is a warning only.</>
              : <>Today&apos;s estimated spend is at <b>{Math.round(pct)}%</b> of your ${data!.budget}/day budget.</>}
          </div>
        </motion.div>
      )}

      <div className="grid grid-cols-2 lg:grid-cols-4 gap-3 mb-4">
        <StatTile label="TODAY"      value={loading ? "—" : usd(data?.today.spend ?? 0)} sub={`${data?.today.calls ?? 0} CALLS`}  accent="amber"   sparkSeed={4} />
        <StatTile label="LAST 7 DAYS"  value={loading ? "—" : usd(data?.week.spend ?? 0)}  sub={`${data?.week.calls ?? 0} CALLS`}   accent="cyan"    sparkSeed={7} />
        <StatTile label="LAST 30 DAYS" value={loading ? "—" : usd(data?.month.spend ?? 0)} sub={`${data?.month.calls ?? 0} CALLS`}  accent="violet"  sparkSeed={5} />
        <StatTile label="DAILY BUDGET" value={loading ? "—" : `$${data?.budget ?? 10}`}    sub="AEGIS_DAILY_BUDGET" accent="emerald" sparkSeed={2} />
      </div>

      {/* Budget bar */}
      <div className="rounded-2xl border border-white/[0.07] bg-white/[0.02] p-5 mb-6">
        <div className="flex items-center justify-between mb-2">
          <span className="font-mono text-[10px] tracking-[0.28em] text-white/60">TODAY VS BUDGET</span>
          <span className="font-mono text-[11px] tabular-nums" style={{ color: barColor }}>{Math.min(999, Math.round(pct))}%</span>
        </div>
        <div className="h-2 bg-white/[0.05] rounded-full overflow-hidden">
          <motion.div className="h-full rounded-full" style={{ background: barColor, boxShadow: `0 0 8px ${barColor}88` }}
            initial={{ width: 0 }} animate={{ width: `${Math.min(100, pct)}%` }} transition={{ duration: 0.8 }} />
        </div>
        <div className="mt-2 text-[10px] text-white/35 font-mono">WARNINGS ONLY · REQUESTS ARE NEVER BLOCKED</div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-3 mb-6">
        {/* By agent */}
        <div className="rounded-2xl border border-white/[0.07] bg-white/[0.02] p-6">
          <div className="flex items-center gap-2 mb-4">
            <Bot className="h-3.5 w-3.5 text-amber-400" />
            <span className="font-mono text-[10px] tracking-[0.28em] text-white/80">SPEND BY AGENT · 30D</span>
          </div>
          <div className="space-y-4">
            {loading && <div className="flex items-center gap-2 text-white/40 text-[12px]"><Loader2 className="h-3.5 w-3.5 animate-spin" /> Loading…</div>}
            {!loading && (data?.byAgent ?? []).length === 0 && <div className="text-[12px] text-white/40">No usage recorded yet. Chat with an agent and spend will appear here.</div>}
            {(data?.byAgent ?? []).map(g => {
              const ag = getAgent(g.name);
              const hex = (COLOR_MAP as any)[ag?.color || ""]?.hex || ag?.color || "#f5b400";
              const max = Math.max(0.0001, data!.byAgent[0].cost);
              return (
                <div key={g.name}>
                  <div className="flex items-center justify-between mb-1.5">
                    <span className="text-[12px] text-white/75">{ag?.name || g.name}</span>
                    <span className="font-mono text-[10px] text-white/85 tabular-nums">{usd(g.cost)} · {g.calls} calls</span>
                  </div>
                  <div className="h-1.5 bg-white/[0.05] rounded-full overflow-hidden">
                    <motion.div className="h-full rounded-full" style={{ background: hex, boxShadow: `0 0 6px ${hex}88` }}
                      initial={{ width: 0 }} animate={{ width: `${(g.cost / max) * 100}%` }} transition={{ duration: 0.8 }} />
                  </div>
                </div>
              );
            })}
          </div>
        </div>

        {/* By model */}
        <div className="rounded-2xl border border-white/[0.07] bg-white/[0.02] p-6">
          <div className="flex items-center gap-2 mb-4">
            <Cpu className="h-3.5 w-3.5 text-amber-400" />
            <span className="font-mono text-[10px] tracking-[0.28em] text-white/80">SPEND BY MODEL · 30D</span>
          </div>
          <div className="space-y-1.5">
            {!loading && (data?.byModel ?? []).length === 0 && <div className="text-[12px] text-white/40">No usage yet.</div>}
            {(data?.byModel ?? []).map(g => (
              <div key={g.name} className="flex items-center gap-3 rounded-xl border border-white/[0.05] p-3">
                <div className="flex-1 min-w-0">
                  <div className="text-[12px] text-white/85 truncate font-mono">{g.name}</div>
                  <div className="text-[10px] text-white/40 mt-0.5">{g.inTok.toLocaleString()} in · {g.outTok.toLocaleString()} out</div>
                </div>
                <span className="font-mono text-[11px] text-white/85 tabular-nums">{usd(g.cost)}</span>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Recent calls */}
      <div className="rounded-2xl border border-white/[0.07] bg-white/[0.02] p-6">
        <div className="flex items-center gap-2 mb-4">
          <TrendingUp className="h-3.5 w-3.5 text-amber-400" />
          <span className="font-mono text-[10px] tracking-[0.28em] text-white/80">RECENT CALLS</span>
        </div>
        <div className="space-y-1">
          {(data?.recent ?? []).map((r, i) => {
            const ag = getAgent(r.agentId);
            return (
              <div key={r.ts + i} className="flex items-center gap-3 py-1.5 border-b border-white/[0.03] last:border-0 text-[11px]">
                <span className="text-white/70 w-28 truncate">{ag?.name || r.agentId}</span>
                <span className="text-white/35 font-mono flex-1 truncate">{r.model}</span>
                <span className="text-white/40 font-mono tabular-nums hidden sm:inline">{r.inTok}→{r.outTok}</span>
                <span className="text-white/80 font-mono tabular-nums">{usd(r.cost)}</span>
                <span className="text-white/30 font-mono w-8 text-right">{ago(r.ts)}</span>
              </div>
            );
          })}
          {!loading && (data?.recent ?? []).length === 0 && <div className="text-[12px] text-white/40">No calls logged yet.</div>}
        </div>
        <div className="mt-4 text-[10px] text-white/30 font-mono leading-relaxed">
          ESTIMATES AT PUBLISHED PER-TOKEN PRICES · PROVIDER BILL IS GROUND TRUTH · TRACKS AEGIS USAGE ONLY, FROM INSTALL · HERMES (LOCAL) = $0
        </div>
      </div>
    </div>
  );
}
TSEOF
echo "   ✓ LedgerView.tsx created"

# ----------------------------------------------------------------------------
# 5. Sidebar + page wiring
# ----------------------------------------------------------------------------
echo "✏️  Wiring Ledger into Sidebar and page"
python3 - <<'PYEOF'
# Sidebar
p = "components/Sidebar.tsx"; src = open(p).read(); changed = []
old_ic = '  Gauge, Bot, MessageSquare, Activity, Network, Database,'
if old_ic in src and "Wallet" not in src:
    src = src.replace(old_ic, '  Gauge, Bot, MessageSquare, Activity, Network, Database, Wallet,', 1); changed.append("Wallet icon imported")
old_t = '| "logs" | "missions" | "mcp";'
if old_t in src:
    src = src.replace(old_t, '| "logs" | "missions" | "mcp" | "ledger";', 1); changed.append("ledger added to ViewId")
old_nav = '  { id: "memory",    label: "Memory",     icon: Database },'
if old_nav in src and '"ledger"' not in src.split("NAV")[1][:800]:
    src = src.replace(old_nav, old_nav + '\n  { id: "ledger",    label: "Ledger",     icon: Wallet },', 1); changed.append("Ledger NAV entry added")
open(p, "w").write(src)
for c in changed: print(f"   ✓ Sidebar: {c}")

# page.tsx
p = "app/page.tsx"; src = open(p).read(); changed = []
old_imp = 'import MemoryView from "@/components/MemoryView";'
if old_imp in src and "LedgerView" not in src:
    src = src.replace(old_imp, old_imp + '\nimport LedgerView from "@/components/LedgerView";', 1); changed.append("LedgerView imported")
lines = src.split("\n")
for i, l in enumerate(lines):
    if 'active === "memory"' in l and "MemoryView" in l:
        indent = l[:len(l) - len(l.lstrip())]
        lines.insert(i + 1, f'{indent}{{active === "ledger"    && <LedgerView />}}')
        changed.append("LedgerView rendered on ledger view")
        break
src = "\n".join(lines)
open(p, "w").write(src)
for c in changed: print(f"   ✓ page: {c}")
PYEOF

echo ""
echo "✅ Ledger spend tracking installed."
echo ""
echo "Optional — set your daily budget (default \$10):"
echo "  echo 'AEGIS_DAILY_BUDGET=5' >> .env.local"
echo ""
echo "Restart:  aegis-control restart"
echo ""
echo "Every Anthropic / Gemini / Perplexity call now logs real token usage to"
echo "data/usage.jsonl. The Ledger sidebar view shows today/7d/30d spend, by"
echo "agent and model, a budget bar with 80%/100% WARNINGS (never blocks), and"
echo "recent calls. Costs are estimates at published prices."
echo ""
echo "Backups in .pre-ledgerview-backup/ — revert: cp -r .pre-ledgerview-backup/* ."
