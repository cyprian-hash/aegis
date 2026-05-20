"use client";
import { useEffect, useState, useCallback } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { Cpu, Download, ExternalLink, RefreshCw, AlertCircle, CheckCircle2, X, Terminal } from "lucide-react";
import AgentAvatar from "./AgentAvatar";

interface HermesStatus {
  installed: boolean;
  installedVersion: string | null;
  latestVersion: string | null;
  updateAvailable: boolean;
  gatewayRunning: boolean;
  dashboardAvailable: boolean;
  hermesPath: string | null;
}

export default function HermesControlCenter() {
  const [status, setStatus] = useState<HermesStatus | null>(null);
  const [loading, setLoading] = useState(true);
  const [updating, setUpdating] = useState(false);
  const [updateLog, setUpdateLog] = useState<string>("");
  const [showLog, setShowLog] = useState(false);
  const [launching, setLaunching] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    try {
      const res = await fetch("/api/hermes/status", { cache: "no-store" });
      const data = await res.json();
      setStatus(data);
      setError(null);
    } catch (err: any) {
      setError(err.message || "Status check failed");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    refresh();
    const id = setInterval(refresh, 30000); // refresh every 30s
    return () => clearInterval(id);
  }, [refresh]);

  const runUpdate = async () => {
    if (updating) return;
    setUpdating(true);
    setUpdateLog("");
    setShowLog(true);
    try {
      const res = await fetch("/api/hermes/update", { method: "POST" });
      if (!res.body) throw new Error("No response stream");
      const reader = res.body.getReader();
      const decoder = new TextDecoder();
      let buf = "";
      while (true) {
        const { value, done } = await reader.read();
        if (done) break;
        buf += decoder.decode(value, { stream: true });
        const blocks = buf.split("\n\n");
        buf = blocks.pop() || "";
        for (const block of blocks) {
          let event = "message", data = "";
          for (const line of block.split("\n")) {
            if (line.startsWith("event:")) event = line.slice(6).trim();
            else if (line.startsWith("data:")) data += line.slice(5).trim();
          }
          if (!data) continue;
          try {
            const parsed = JSON.parse(data);
            if (event === "log") setUpdateLog((prev) => prev + parsed.line);
            else if (event === "done") setUpdateLog((prev) => prev + "\n✓ " + parsed.msg + "\n");
            else if (event === "error") setUpdateLog((prev) => prev + "\n✗ " + parsed.message + "\n");
          } catch { /* ignore parse errors */ }
        }
      }
    } catch (err: any) {
      setUpdateLog((prev) => prev + "\n✗ " + err.message);
    } finally {
      setUpdating(false);
      refresh();
    }
  };

  const launchDashboard = async () => {
    if (launching) return;
    setLaunching(true);
    try {
      const res = await fetch("/api/hermes/dashboard", { method: "POST" });
      const data = await res.json();
      if (data.ok && data.url) {
        window.open(data.url, "_blank");
      } else {
        setError(data.error || "Couldn't open Hermes dashboard");
      }
    } catch (err: any) {
      setError(err.message);
    } finally {
      setLaunching(false);
    }
  };

  if (loading) {
    return (
      <div className="rounded-2xl border border-white/[0.07] bg-white/[0.02] p-5">
        <div className="font-mono text-[10px] tracking-[0.28em] text-white/40">LOADING HERMES STATUS…</div>
      </div>
    );
  }

  if (!status?.installed) {
    return (
      <div className="rounded-2xl border border-white/[0.07] bg-white/[0.02] p-5">
        <div className="flex items-center gap-2 mb-2">
          <Cpu className="h-3.5 w-3.5 text-white/40" />
          <span className="font-mono text-[10px] tracking-[0.28em] text-white/60">HERMES AGENT</span>
        </div>
        <div className="text-[13px] text-white/70 mb-3">Hermes is not installed on this machine.</div>
        <div className="font-mono text-[11px] text-white/50 bg-black/40 rounded-lg p-2.5 select-all">
          curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash
        </div>
      </div>
    );
  }

  return (
    <div className="relative rounded-2xl border border-white/[0.07] bg-white/[0.02] p-5 overflow-hidden">
      <div className="absolute -top-12 -right-12 h-40 w-40 rounded-full opacity-20 pointer-events-none"
        style={{ background: "radial-gradient(circle, #fbbf24, transparent 70%)" }} />

      <div className="relative">
        <div className="flex items-start justify-between mb-4">
          <div className="flex items-center gap-3">
            <AgentAvatar agentId="hermes-07" size={42} animated={false} />
            <div>
              <div className="flex items-center gap-2">
                <span className="font-display text-[14px] text-white font-medium">Hermes Control</span>
                {status.updateAvailable && (
                  <span className="font-mono text-[9px] tracking-[0.2em] px-1.5 py-0.5 rounded bg-amber-400/15 text-amber-300">
                    UPDATE AVAILABLE
                  </span>
                )}
              </div>
              <div className="font-mono text-[10px] text-white/50">
                v{status.installedVersion}
                {status.latestVersion && status.installedVersion !== status.latestVersion && (
                  <span className="text-white/30"> → v{status.latestVersion}</span>
                )}
              </div>
            </div>
          </div>
          <button onClick={refresh}
            className="h-7 w-7 grid place-items-center rounded-full hover:bg-white/5 text-white/40 hover:text-white"
            title="Refresh">
            <RefreshCw className="h-3 w-3" strokeWidth={1.5} />
          </button>
        </div>

        <div className="grid grid-cols-2 gap-2 mb-4">
          <StatusPill label="GATEWAY" on={status.gatewayRunning} onLabel="RUNNING" offLabel="STOPPED" />
          <StatusPill label="DASHBOARD" on={status.dashboardAvailable} onLabel="READY" offLabel="N/A" />
        </div>

        <div className="flex items-center gap-2">
          {status.updateAvailable ? (
            <motion.button
              onClick={runUpdate} disabled={updating}
              whileTap={{ scale: 0.97 }}
              className="flex-1 flex items-center justify-center gap-1.5 py-2 rounded-full bg-amber-400 hover:bg-amber-300 disabled:opacity-50 text-black font-mono text-[11px] tracking-[0.18em] font-medium"
              style={{ boxShadow: "0 0 14px rgba(245,180,0,0.3)" }}>
              <Download className="h-3 w-3" strokeWidth={2.5} />
              {updating ? "UPDATING…" : `UPDATE TO v${status.latestVersion}`}
            </motion.button>
          ) : (
            <div className="flex-1 flex items-center justify-center gap-1.5 py-2 rounded-full bg-emerald-400/10 border border-emerald-400/20 text-emerald-300 font-mono text-[11px] tracking-[0.18em]">
              <CheckCircle2 className="h-3 w-3" strokeWidth={2} />
              UP TO DATE
            </div>
          )}
          <button
            onClick={launchDashboard} disabled={launching || !status.installed}
            className="flex items-center justify-center gap-1.5 px-3 py-2 rounded-full border border-white/10 hover:border-white/30 hover:bg-white/5 text-white/70 font-mono text-[11px] tracking-[0.18em] disabled:opacity-40"
            title="Launch hermes dashboard in a new tab">
            <ExternalLink className="h-3 w-3" strokeWidth={2} />
            DASHBOARD
          </button>
        </div>

        {error && (
          <div className="mt-3 rounded-lg border border-rose-400/30 bg-rose-400/[0.06] p-2 font-mono text-[11px] text-rose-300 flex items-center justify-between gap-2">
            <span className="truncate">{error}</span>
            <button onClick={() => setError(null)}><X className="h-3 w-3" /></button>
          </div>
        )}
      </div>

      <AnimatePresence>
        {showLog && (
          <motion.div
            initial={{ height: 0, opacity: 0 }}
            animate={{ height: "auto", opacity: 1 }}
            exit={{ height: 0, opacity: 0 }}
            className="overflow-hidden mt-4"
          >
            <div className="rounded-lg border border-white/[0.06] bg-black/50 overflow-hidden">
              <div className="flex items-center justify-between px-3 py-1.5 border-b border-white/[0.06]">
                <div className="flex items-center gap-1.5">
                  <Terminal className="h-3 w-3 text-white/40" strokeWidth={1.5} />
                  <span className="font-mono text-[9px] tracking-[0.2em] text-white/50">UPDATE LOG</span>
                </div>
                <button onClick={() => setShowLog(false)} className="text-white/40 hover:text-white">
                  <X className="h-3 w-3" />
                </button>
              </div>
              <pre className="font-mono text-[10px] text-white/70 p-3 max-h-40 overflow-y-auto whitespace-pre-wrap">
                {updateLog || "starting…"}
              </pre>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}

function StatusPill({ label, on, onLabel, offLabel }: { label: string; on: boolean; onLabel: string; offLabel: string }) {
  return (
    <div className="rounded-lg border border-white/[0.05] bg-white/[0.015] px-3 py-2">
      <div className="font-mono text-[9px] tracking-[0.2em] text-white/40 mb-0.5">{label}</div>
      <div className="flex items-center gap-1.5">
        <span className={`h-1.5 w-1.5 rounded-full ${on ? "bg-emerald-400" : "bg-white/25"}`}
          style={on ? { boxShadow: "0 0 6px rgba(52,211,153,0.6)" } : {}} />
        <span className={`font-mono text-[11px] tabular-nums ${on ? "text-emerald-300" : "text-white/50"}`}>
          {on ? onLabel : offLabel}
        </span>
      </div>
    </div>
  );
}
