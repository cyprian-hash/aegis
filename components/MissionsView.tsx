"use client";
import { useState, useMemo } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { Plus, X, ChevronRight, ChevronUp, Clock, CheckCircle2, Circle, Workflow, Sparkles, Send } from "lucide-react";
import { COLOR_MAP, pad } from "@/lib/theme";
import { AGENTS, Agent } from "@/lib/agents";
import SectionHeader from "./SectionHeader";
import AgentAvatar from "./AgentAvatar";

type Status = "queued" | "active" | "review" | "complete";
type Priority = "P0" | "P1" | "P2" | "P3";

interface Mission {
  id: string;
  title: string;
  brief: string;
  status: Status;
  priority: Priority;
  progress: number;
  agentIds: string[];
  steps: { label: string; done: boolean }[];
  createdAt: string;
}


function saveMissionToVault(m: Mission) {
  const agents = m.agentIds.map(id => AGENTS.find(a => a.id === id)?.name || id).join(", ");
  const stepLines = m.steps.map(s => `- [${s.done ? "x" : " "}] ${s.label}`).join("\n");
  const content = `---
mission_id: ${m.id}
status: ${m.status}
priority: ${m.priority}
progress: ${m.progress}
agents: [${m.agentIds.join(", ")}]
type: aegis-mission
tags: [aegis, mission, ${m.status}, ${m.priority.toLowerCase()}]
---

# ${m.id} — ${m.title}

**Status:** ${m.status.toUpperCase()} · **Priority:** ${m.priority} · **Progress:** ${m.progress}%

**Assigned:** ${agents}

## Brief

${m.brief}

## Steps

${stepLines}

---
_Last updated by AEGIS at ${new Date().toLocaleString()}_
`;
  fetch("/api/vault", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ kind: "mission", missionId: m.id, missionContent: content }),
  }).catch(() => { /* vault save is best-effort */ });
}

const PRIORITY_COLOR: Record<Priority, keyof typeof COLOR_MAP> = {
  P0: "rose", P1: "amber", P2: "cyan", P3: "violet",
};

const SEED: Mission[] = [
  {
    id: "M-0042", title: "Migrate auth surface to OAuth 2.1",
    brief: "Replace legacy OAuth 2.0 in /api/auth with a 2.1-compliant flow. Maintain backward compat for 14 days.",
    status: "active", priority: "P0", progress: 64, agentIds: ["forge-02", "sentry-05"],
    steps: [
      { label: "Audit existing endpoints", done: true },
      { label: "Draft 2.1 spec", done: true },
      { label: "Implement /authorize", done: true },
      { label: "Implement /token", done: false },
      { label: "Pass SENTRY eval", done: false },
    ],
    createdAt: "today",
  },
  {
    id: "M-0041", title: "Research surface code error correction",
    brief: "Crawl recent arXiv papers (2024-2026) on surface code QEC. Produce 2-page digest with citations.",
    status: "active", priority: "P1", progress: 38, agentIds: ["scout-01", "claude-prime"],
    steps: [
      { label: "Identify relevant papers", done: true },
      { label: "Extract key claims", done: false },
      { label: "Verify primary sources", done: false },
      { label: "Compose digest", done: false },
    ],
    createdAt: "today",
  },
  {
    id: "M-0040", title: "Index Q2 mission transcripts",
    brief: "Embed and index all Q2 mission transcripts into the long-term vector store.",
    status: "review", priority: "P2", progress: 92, agentIds: ["archive-03", "sentry-05"],
    steps: [
      { label: "Pull transcripts", done: true },
      { label: "Chunk + embed", done: true },
      { label: "Tag + write", done: true },
      { label: "Verification pass", done: false },
    ],
    createdAt: "yesterday",
  },
  {
    id: "M-0039", title: "Compose weekly digest for Commander",
    brief: "Synthesize last 7 days of agent activity into a one-page brief.",
    status: "queued", priority: "P2", progress: 0, agentIds: ["claude-prime", "weaver-04"],
    steps: [
      { label: "Pull mission outcomes", done: false },
      { label: "Synthesize themes", done: false },
      { label: "Compose draft", done: false },
    ],
    createdAt: "today",
  },
  {
    id: "M-0038", title: "Nightly safety eval cron",
    brief: "Verify all agent outputs pass safety eval at 03:00 UTC daily.",
    status: "complete", priority: "P3", progress: 100, agentIds: ["sentry-05"],
    steps: [
      { label: "Define eval suite", done: true },
      { label: "Schedule cron", done: true },
      { label: "Verify last 7 runs", done: true },
    ],
    createdAt: "Mon",
  },
];

const COLUMNS: { id: Status; label: string; accent: keyof typeof COLOR_MAP }[] = [
  { id: "queued",   label: "QUEUED",   accent: "cyan" },
  { id: "active",   label: "ACTIVE",   accent: "amber" },
  { id: "review",   label: "REVIEW",   accent: "violet" },
  { id: "complete", label: "COMPLETE", accent: "emerald" },
];

export default function MissionsView() {
  const [missions, setMissions] = useState<Mission[]>(SEED);
  const [selected, setSelected] = useState<Mission | null>(null);
  const [showNew, setShowNew] = useState(false);

  const grouped = useMemo(() => {
    const g: Record<Status, Mission[]> = { queued: [], active: [], review: [], complete: [] };
    missions.forEach(m => g[m.status].push(m));
    return g;
  }, [missions]);

  const advance = (id: string) => {
    setMissions(prev => {
      const next = prev.map(m => {
        if (m.id !== id) return m;
        const order: Status[] = ["queued", "active", "review", "complete"];
        const nextStatus = order[Math.min(order.length - 1, order.indexOf(m.status) + 1)];
        return { ...m, status: nextStatus, progress: nextStatus === "complete" ? 100 : Math.max(m.progress, 25) };
      });
      const updated = next.find(m => m.id === id);
      if (updated) saveMissionToVault(updated);
      return next;
    });
    if (selected?.id === id) {
      setSelected(s => s ? { ...s, status: s.status === "complete" ? s.status : "active" } : null);
    }
  };

  return (
    <div>
      <SectionHeader
        kicker="OPERATIONS / KANBAN"
        title="Mission Planner"
        right={
          <motion.button
            whileHover={{ y: -1 }} whileTap={{ scale: 0.97 }}
            onClick={() => setShowNew(true)}
            className="flex items-center gap-2 px-4 py-2.5 rounded-full bg-amber-400 text-black text-[11px] tracking-[0.18em] font-mono font-medium"
            style={{ boxShadow: "0 0 14px rgba(245,180,0,0.3)" }}
          >
            <Plus className="h-3.5 w-3.5" strokeWidth={2.5} /> NEW MISSION
          </motion.button>
        }
      />

      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-4 gap-3">
        {COLUMNS.map(col => {
          const c = COLOR_MAP[col.accent];
          const list = grouped[col.id];
          return (
            <div key={col.id} className="rounded-2xl border border-white/[0.07] bg-white/[0.015] p-3 min-h-[420px]">
              <div className="flex items-center justify-between mb-3 px-1">
                <div className="flex items-center gap-2">
                  <span className="h-1.5 w-1.5 rounded-full" style={{ background: c.hex, boxShadow: `0 0 8px ${c.glow}` }} />
                  <span className="font-mono text-[10px] tracking-[0.28em]" style={{ color: c.hex }}>{col.label}</span>
                </div>
                <span className="font-mono text-[10px] text-white/40 tabular-nums">{pad(list.length)}</span>
              </div>
              <div className="space-y-2">
                {list.map((m, i) => (
                  <MissionCard key={m.id} m={m} delay={i * 0.04} onClick={() => setSelected(m)} />
                ))}
                {list.length === 0 && (
                  <div className="px-3 py-8 text-center font-mono text-[10px] tracking-[0.18em] text-white/25">EMPTY</div>
                )}
              </div>
            </div>
          );
        })}
      </div>

      <AnimatePresence>
        {selected && (
          <MissionDetail m={selected} onClose={() => setSelected(null)} onAdvance={() => advance(selected.id)} />
        )}
      </AnimatePresence>
      <AnimatePresence>
        {showNew && (
          <NewMissionModal
            onClose={() => setShowNew(false)}
            onCreate={(m) => { setMissions(prev => [m, ...prev]); saveMissionToVault(m); setShowNew(false); }}
            nextId={`M-${String(Math.max(...missions.map(m => parseInt(m.id.split("-")[1]))) + 1).padStart(4, "0")}`}
          />
        )}
      </AnimatePresence>
    </div>
  );
}


async function sendMissionToHermes(m: Mission): Promise<{ ok: boolean; task_id?: string; error?: string }> {
  const assignee = AGENTS.find(a => m.agentIds.includes(a.id))?.shortName?.toLowerCase() || undefined;
  const stepLines = m.steps.map(s => `- [${s.done ? "x" : " "}] ${s.label}`).join("\n");
  const body = [m.brief, "", "## Steps", stepLines].join("\n");
  try {
    const res = await fetch("/api/hermes/dispatch", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        title: `[${m.id}] ${m.title}`,
        body,
        priority: m.priority === "P0" ? 0 : m.priority === "P1" ? 1 : m.priority === "P2" ? 2 : 3,
      }),
    });
    const data = await res.json();
    return { ok: data.ok, task_id: data.task_id, error: data.error };
  } catch (err: any) {
    return { ok: false, error: err?.message || "dispatch failed" };
  }
}

function MissionCard({ m, delay, onClick }: { m: Mission; delay: number; onClick: () => void }) {
  const pc = COLOR_MAP[PRIORITY_COLOR[m.priority]];
  return (
    <motion.button
      initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} transition={{ delay, duration: 0.4 }}
      whileHover={{ y: -2 }} onClick={onClick}
      className="w-full text-left rounded-xl border border-white/[0.06] bg-white/[0.02] hover:border-white/20 hover:bg-white/[0.04] transition-all p-3.5 group"
    >
      <div className="flex items-center justify-between mb-2">
        <span className="font-mono text-[9px] tracking-[0.22em] text-white/40">{m.id}</span>
        <span className="px-1.5 py-0.5 rounded font-mono text-[9px] tracking-[0.18em]"
          style={{ background: pc.soft, color: pc.hex }}>{m.priority}</span>
      </div>
      <div className="font-display text-[13px] text-white/90 leading-snug mb-3 line-clamp-2">{m.title}</div>
      <div className="flex items-center justify-between gap-2 mb-2">
        <div className="flex -space-x-2">
          {m.agentIds.slice(0, 3).map(id => (
            <div key={id} className="ring-2 ring-[#0a0a0a] rounded-full">
              <AgentAvatar agentId={id} size={22} animated={false} />
            </div>
          ))}
        </div>
        <span className="font-mono text-[9px] text-white/60 tabular-nums">{m.progress}%</span>
      </div>
      <div className="h-1 bg-white/[0.05] rounded-full overflow-hidden">
        <motion.div className="h-full rounded-full"
          style={{ background: pc.hex, boxShadow: `0 0 6px ${pc.glow}` }}
          initial={{ width: 0 }} animate={{ width: `${m.progress}%` }}
          transition={{ duration: 0.8, delay: delay + 0.15 }}
        />
      </div>
    </motion.button>
  );
}

function MissionDetail({ m, onClose, onAdvance }: { m: Mission; onClose: () => void; onAdvance: () => void }) {
  const pc = COLOR_MAP[PRIORITY_COLOR[m.priority]];
  const assigned = m.agentIds.map(id => AGENTS.find(a => a.id === id)).filter(Boolean) as Agent[];
  return (
    <>
      <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
        onClick={onClose} className="fixed inset-0 bg-black/70 backdrop-blur-sm z-40" />
      <motion.div
        initial={{ opacity: 0, scale: 0.96, y: 20 }} animate={{ opacity: 1, scale: 1, y: 0 }} exit={{ opacity: 0, scale: 0.96, y: 20 }}
        transition={{ duration: 0.3, ease: [0.22, 1, 0.36, 1] }}
        className="fixed inset-x-4 top-[5%] bottom-[5%] md:inset-x-auto md:left-1/2 md:-translate-x-1/2 md:w-[640px] md:top-[8%] md:bottom-[8%] rounded-2xl border border-white/10 bg-[#0c0c0c] z-50 overflow-y-auto"
      >
        <div className="sticky top-0 bg-[#0c0c0c]/95 backdrop-blur-xl border-b border-white/[0.06] px-6 py-4 flex items-center justify-between z-10">
          <div>
            <div className="flex items-center gap-2 mb-1">
              <span className="font-mono text-[10px] tracking-[0.22em] text-white/40">{m.id}</span>
              <span className="px-1.5 py-0.5 rounded font-mono text-[9px] tracking-[0.18em]"
                style={{ background: pc.soft, color: pc.hex }}>{m.priority}</span>
              <span className="font-mono text-[9px] tracking-[0.22em] text-white/40 uppercase">· {m.status}</span>
            </div>
            <div className="font-display text-[18px] text-white tracking-tight">{m.title}</div>
          </div>
          <button onClick={onClose} className="h-8 w-8 grid place-items-center rounded-full hover:bg-white/5 text-white/50 hover:text-white">
            <X className="h-4 w-4" />
          </button>
        </div>

        <div className="p-6 space-y-6">
          <div>
            <div className="font-mono text-[9px] tracking-[0.25em] text-white/40 mb-2">BRIEF</div>
            <div className="text-[14px] text-white/80 leading-relaxed">{m.brief}</div>
          </div>

          <div>
            <div className="flex items-center justify-between mb-2">
              <div className="font-mono text-[9px] tracking-[0.25em] text-white/40">PROGRESS</div>
              <span className="font-mono text-[10px] text-white/85 tabular-nums">{m.progress}%</span>
            </div>
            <div className="h-1.5 bg-white/[0.05] rounded-full overflow-hidden">
              <motion.div className="h-full rounded-full" style={{ background: pc.hex, boxShadow: `0 0 8px ${pc.glow}` }}
                initial={{ width: 0 }} animate={{ width: `${m.progress}%` }} transition={{ duration: 0.8 }} />
            </div>
          </div>

          <div>
            <div className="font-mono text-[9px] tracking-[0.25em] text-white/40 mb-2">ASSIGNED</div>
            <div className="space-y-2">
              {assigned.map(a => (
                <div key={a.id} className="flex items-center gap-3 rounded-xl border border-white/[0.06] bg-white/[0.02] p-3">
                  <AgentAvatar agentId={a.id} size={36} animated={false} />
                  <div className="flex-1 min-w-0">
                    <div className="font-display text-[13px] text-white/90">{a.name}</div>
                    <div className="text-[11px] text-white/50">{a.role}</div>
                  </div>
                  <span className="font-mono text-[10px] text-white/60 tabular-nums">LOAD {a.load}%</span>
                </div>
              ))}
            </div>
          </div>

          <div>
            <div className="font-mono text-[9px] tracking-[0.25em] text-white/40 mb-2">STEPS</div>
            <div className="space-y-1">
              {m.steps.map((s, i) => (
                <div key={i} className="flex items-center gap-3 px-3 py-2.5 rounded-lg hover:bg-white/[0.02]">
                  {s.done
                    ? <CheckCircle2 className="h-4 w-4 text-emerald-400 shrink-0" strokeWidth={1.5} />
                    : <Circle className="h-4 w-4 text-white/30 shrink-0" strokeWidth={1.5} />}
                  <span className={`text-[12px] ${s.done ? "text-white/55 line-through" : "text-white/90"}`}>{s.label}</span>
                </div>
              ))}
            </div>
          </div>

          <div className="flex items-center gap-2 pt-2 border-t border-white/[0.06] flex-wrap">
            <button
              onClick={onAdvance}
              disabled={m.status === "complete"}
              className="flex-1 flex items-center justify-center gap-2 py-2.5 rounded-full bg-amber-400 text-black hover:bg-amber-300 disabled:opacity-40 disabled:cursor-not-allowed font-mono text-[11px] tracking-[0.18em] font-medium"
            >
              <ChevronRight className="h-3.5 w-3.5" strokeWidth={2.5} /> ADVANCE STATUS
            </button>
            <button
              onClick={async () => {
                const r = await sendMissionToHermes(m);
                if (r.ok) {
                  alert(`Sent to Hermes${r.task_id ? ` as ${r.task_id}` : ""}.`);
                } else {
                  alert(`Hermes dispatch failed: ${r.error || "unknown error"}`);
                }
              }}
              className="px-4 py-2.5 rounded-full border border-amber-400/30 hover:border-amber-400/60 hover:bg-amber-400/10 font-mono text-[11px] tracking-[0.18em] text-amber-300"
              title="Create a Hermes kanban task from this mission"
            >
              <Send className="h-3.5 w-3.5 inline mr-1" strokeWidth={2} /> SEND TO HERMES
            </button>
            <button className="px-4 py-2.5 rounded-full border border-white/10 hover:border-white/30 hover:bg-white/5 font-mono text-[11px] tracking-[0.18em] text-white/70">
              <ChevronUp className="h-3.5 w-3.5 inline mr-1" strokeWidth={2} /> ESCALATE
            </button>
          </div>
        </div>
      </motion.div>
    </>
  );
}

function NewMissionModal({ onClose, onCreate, nextId }: { onClose: () => void; onCreate: (m: Mission) => void; nextId: string }) {
  const [title, setTitle] = useState("");
  const [brief, setBrief] = useState("");
  const [priority, setPriority] = useState<Priority>("P1");
  const [agentIds, setAgentIds] = useState<string[]>([]);

  const toggleAgent = (id: string) => {
    setAgentIds(prev => prev.includes(id) ? prev.filter(x => x !== id) : [...prev, id]);
  };

  const submit = () => {
    if (!title.trim() || agentIds.length === 0) return;
    onCreate({
      id: nextId,
      title: title.trim(),
      brief: brief.trim() || "Mission brief pending.",
      status: "queued",
      priority,
      progress: 0,
      agentIds,
      steps: [{ label: "Define objective", done: false }, { label: "Execute", done: false }],
      createdAt: "just now",
    });
  };

  return (
    <>
      <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
        onClick={onClose} className="fixed inset-0 bg-black/70 backdrop-blur-sm z-40" />
      <motion.div
        initial={{ opacity: 0, scale: 0.96, y: 20 }} animate={{ opacity: 1, scale: 1, y: 0 }} exit={{ opacity: 0, scale: 0.96, y: 20 }}
        transition={{ duration: 0.3, ease: [0.22, 1, 0.36, 1] }}
        className="fixed inset-x-4 top-[8%] bottom-[8%] md:inset-x-auto md:left-1/2 md:-translate-x-1/2 md:w-[560px] md:top-[10%] md:bottom-[10%] rounded-2xl border border-white/10 bg-[#0c0c0c] z-50 overflow-y-auto"
      >
        <div className="sticky top-0 bg-[#0c0c0c]/95 backdrop-blur-xl border-b border-white/[0.06] px-6 py-4 flex items-center justify-between z-10">
          <div className="flex items-center gap-2">
            <Sparkles className="h-3.5 w-3.5 text-amber-400" strokeWidth={1.5} />
            <span className="font-mono text-[10px] tracking-[0.28em] text-white/80">NEW MISSION · {nextId}</span>
          </div>
          <button onClick={onClose} className="h-8 w-8 grid place-items-center rounded-full hover:bg-white/5 text-white/50 hover:text-white">
            <X className="h-4 w-4" />
          </button>
        </div>

        <div className="p-6 space-y-5">
          <div>
            <div className="font-mono text-[9px] tracking-[0.25em] text-white/40 mb-2">TITLE</div>
            <input value={title} onChange={e => setTitle(e.target.value)} autoFocus
              placeholder="What's the objective?"
              className="w-full bg-black/40 border border-white/10 focus:border-white/30 rounded-xl px-4 py-3 text-[14px] text-white placeholder-white/30 outline-none transition-colors" />
          </div>

          <div>
            <div className="font-mono text-[9px] tracking-[0.25em] text-white/40 mb-2">BRIEF</div>
            <textarea value={brief} onChange={e => setBrief(e.target.value)} rows={3}
              placeholder="Describe the mission in a few sentences…"
              className="w-full bg-black/40 border border-white/10 focus:border-white/30 rounded-xl px-4 py-3 text-[13px] text-white placeholder-white/30 outline-none transition-colors resize-none" />
          </div>

          <div>
            <div className="font-mono text-[9px] tracking-[0.25em] text-white/40 mb-2">PRIORITY</div>
            <div className="flex items-center gap-2">
              {(["P0", "P1", "P2", "P3"] as Priority[]).map(p => {
                const c = COLOR_MAP[PRIORITY_COLOR[p]];
                const on = priority === p;
                return (
                  <button key={p} onClick={() => setPriority(p)}
                    className="flex-1 py-2 rounded-full text-[11px] tracking-[0.18em] font-mono font-medium transition-all"
                    style={on
                      ? { background: c.hex, color: "#000", boxShadow: `0 0 12px ${c.glow}` }
                      : { background: c.soft, color: c.hex, opacity: 0.6 }}
                  >
                    {p}
                  </button>
                );
              })}
            </div>
          </div>

          <div>
            <div className="font-mono text-[9px] tracking-[0.25em] text-white/40 mb-2">
              ASSIGN AGENTS · <span className="text-white/60">{agentIds.length} SELECTED</span>
            </div>
            <div className="space-y-1.5">
              {AGENTS.map(a => {
                const on = agentIds.includes(a.id);
                const c = COLOR_MAP[a.color];
                return (
                  <button key={a.id} onClick={() => toggleAgent(a.id)}
                    className={`w-full flex items-center gap-3 p-2.5 rounded-xl border transition-all ${
                      on ? "" : "hover:bg-white/[0.02]"
                    }`}
                    style={on
                      ? { borderColor: `${c.hex}55`, background: c.soft }
                      : { borderColor: "rgba(255,255,255,0.06)" }}>
                    <AgentAvatar agentId={a.id} size={28} animated={false} />
                    <div className="flex-1 text-left">
                      <div className="font-display text-[12px] text-white/90">{a.name}</div>
                      <div className="text-[10px] text-white/50">{a.role}</div>
                    </div>
                    <div className={`h-4 w-4 rounded-full border-2 grid place-items-center ${on ? "" : "border-white/20"}`}
                      style={on ? { background: c.hex, borderColor: c.hex } : {}}>
                      {on && <CheckCircle2 className="h-3 w-3 text-black" strokeWidth={3} />}
                    </div>
                  </button>
                );
              })}
            </div>
          </div>

          <div className="pt-3 border-t border-white/[0.06] flex gap-2">
            <button onClick={onClose}
              className="px-5 py-2.5 rounded-full border border-white/10 hover:border-white/30 font-mono text-[11px] tracking-[0.18em] text-white/70">
              CANCEL
            </button>
            <button
              onClick={submit}
              disabled={!title.trim() || agentIds.length === 0}
              className="flex-1 flex items-center justify-center gap-2 py-2.5 rounded-full bg-amber-400 text-black hover:bg-amber-300 disabled:opacity-30 disabled:cursor-not-allowed font-mono text-[11px] tracking-[0.18em] font-medium"
              style={{ boxShadow: title.trim() && agentIds.length ? "0 0 14px rgba(245,180,0,0.3)" : "none" }}
            >
              <Workflow className="h-3.5 w-3.5" strokeWidth={2.5} /> LAUNCH MISSION
            </button>
          </div>
        </div>
      </motion.div>
    </>
  );
}
