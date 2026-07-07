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
