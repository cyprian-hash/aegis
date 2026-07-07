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
