"use client";
import { useEffect, useRef, useState } from "react";
import { X, Pause, Play, RotateCcw, Search } from "lucide-react";
import { getAgent } from "@/lib/agents";

interface MemFile { name: string; kind: string; project?: string; size: number; updated: string; }
interface Node extends MemFile { x: number; y: number; z: number; r: number; color: string; hub?: boolean; }
interface Link { a: number; b: number; spoke?: boolean; }

const KIND_COLOR: Record<string, string> = {
  brief: "#22D3EE", conversation: "#34D399", context: "#F5B400",
  source: "#A78BFA", strategy: "#FB7185", other: "#94A3B8",
};
const KIND_LABEL: Record<string, string> = {
  brief: "Briefs", conversation: "Conversations", context: "Context",
  source: "Source Docs", strategy: "Strategies", other: "Files",
};

function h(s: string, salt = 0): number {
  let x = 2166136261 ^ salt;
  for (let i = 0; i < s.length; i++) { x ^= s.charCodeAt(i); x = Math.imul(x, 16777619); }
  return ((x >>> 0) % 100000) / 100000;
}
function sphereDir(u: number, v: number): [number, number, number] {
  const th = u * Math.PI * 2, ph = Math.acos(2 * v - 1);
  return [Math.sin(ph) * Math.cos(th), Math.cos(ph), Math.sin(ph) * Math.sin(th)];
}

function layout(files: MemFile[]): { nodes: Node[]; links: Link[]; byKind: Record<string, number>; totalBytes: number } {
  const nodes: Node[] = []; const links: Link[] = [];
  const byKind: Record<string, number> = {}; let totalBytes = 0;
  for (const f of files) { byKind[f.kind] = (byKind[f.kind] || 0) + 1; totalBytes += f.size; }
  const rOf = (size: number) => Math.min(8.5, 3.0 + Math.log10(Math.max(100, size)) * 1.25);
  const briefs = files.filter(f => f.kind === "brief").sort((a, b) => a.name.localeCompare(b.name));
  const GA = Math.PI * (3 - Math.sqrt(5));
  const briefIdx: Record<string, number> = {};
  briefs.forEach((f, i) => {
    const y = briefs.length > 1 ? 1 - (2 * i) / (briefs.length - 1) : 0;
    const rad = Math.sqrt(Math.max(0, 1 - y * y)), th = GA * i;
    nodes.push({ ...f, x: Math.cos(th) * rad * 100, y: y * 74, z: Math.sin(th) * rad * 100, r: rOf(f.size) + 1.4, color: KIND_COLOR.brief, hub: true });
    briefIdx[(f.project || f.name).toLowerCase()] = nodes.length - 1;
  });
  files.filter(f => f.kind === "context").forEach(f => {
    const [dx, dy, dz] = sphereDir(h(f.name), h(f.name, 7));
    nodes.push({ ...f, x: dx * 25, y: dy * 19, z: dz * 25, r: rOf(f.size), color: KIND_COLOR.context });
  });
  files.filter(f => f.kind === "source" || f.kind === "strategy").forEach(f => {
    const pi = briefIdx[(f.project || "").toLowerCase()];
    const [dx, dy, dz] = sphereDir(h(f.name, 3), h(f.name, 11));
    if (pi !== undefined) {
      const p = nodes[pi];
      nodes.push({ ...f, x: p.x + dx * 27, y: p.y + dy * 23, z: p.z + dz * 27, r: rOf(f.size), color: KIND_COLOR[f.kind] });
      links.push({ a: nodes.length - 1, b: pi });
    } else {
      nodes.push({ ...f, x: dx * 130, y: dy * 92, z: dz * 130, r: rOf(f.size), color: KIND_COLOR[f.kind] });
    }
  });
  const convs = files.filter(f => f.kind === "conversation");
  const agents = Array.from(new Set(convs.map(f => f.project || "agent"))).sort();
  const centers: Record<string, [number, number, number]> = {};
  agents.forEach((a, i) => {
    const y = agents.length > 1 ? 1 - (2 * i) / (agents.length - 1) : 0;
    const rad = Math.sqrt(Math.max(0, 1 - y * y)), th = GA * i + 1.7;
    centers[a] = [Math.cos(th) * rad * 165, y * 110, Math.sin(th) * rad * 165];
  });
  const firstOf: Record<string, number> = {};
  convs.forEach(f => {
    const a = f.project || "agent"; const c = centers[a];
    const [dx, dy, dz] = sphereDir(h(f.name, 5), h(f.name, 13));
    nodes.push({ ...f, x: c[0] + dx * 18, y: c[1] + dy * 15, z: c[2] + dz * 18, r: rOf(f.size), color: KIND_COLOR.conversation });
    const i = nodes.length - 1;
    if (firstOf[a] === undefined) firstOf[a] = i; else links.push({ a: i, b: firstOf[a] });
  });
  Object.values(briefIdx).forEach(i => {
    let nearest = -1, best = 1e9;
    nodes.forEach((n, j) => { if (n.kind === "context") { const d = (n.x - nodes[i].x) ** 2 + (n.y - nodes[i].y) ** 2 + (n.z - nodes[i].z) ** 2; if (d < best) { best = d; nearest = j; } } });
    if (nearest >= 0) links.push({ a: i, b: nearest, spoke: true });
  });
  return { nodes, links, byKind, totalBytes };
}

const kb = (n: number) => n < 1024 ? `${n} B` : n < 1048576 ? `${(n / 1024).toFixed(1)} KB` : `${(n / 1048576).toFixed(2)} MB`;

export default function MemoryConstellation({ onSearch }: { onSearch?: (q: string) => void }) {
  const wrapRef = useRef<HTMLDivElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const dataRef = useRef<{ nodes: Node[]; links: Link[] }>({ nodes: [], links: [] });
  const ctrlRef = useRef({ rotY: 0.6, rotX: -0.22, zoom: 1.15, auto: true, resumeAt: 0 });
  const [meta, setMeta] = useState<{ count: number; byKind: Record<string, number>; totalBytes: number } | null>(null);
  const [failed, setFailed] = useState(false);
  const [paused, setPaused] = useState(false);
  const [selected, setSelected] = useState<Node | null>(null);
  const selRef = useRef<Node | null>(null);
  useEffect(() => { selRef.current = selected; }, [selected]);

  useEffect(() => {
    let alive = true;
    fetch("/api/memory?list=1").then(r => r.json()).then(j => {
      if (!alive) return;
      if (j.ok && Array.isArray(j.files)) {
        const L = layout(j.files);
        dataRef.current = { nodes: L.nodes, links: L.links };
        setMeta({ count: j.files.length, byKind: L.byKind, totalBytes: L.totalBytes });
      } else setFailed(true);
    }).catch(() => alive && setFailed(true));
    return () => { alive = false; };
  }, []);

  useEffect(() => {
    const canvas = canvasRef.current, wrap = wrapRef.current;
    if (!canvas || !wrap) return;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;
    const C = ctrlRef.current;
    let w = 0, hgt = 0, dpr = 1, raf = 0;
    let dragging = false, lastX = 0, lastY = 0, moved = false;
    let hover = -1, mx = -1, my = -1;
    const F = 460;
    const stars = Array.from({ length: 120 }, (_, i) => ({ x: h(`sx${i}`), y: h(`sy${i}`), r: 0.5 + h(`sr${i}`) * 1.1, p: h(`sp${i}`) * Math.PI * 2 }));

    const resize = () => {
      dpr = Math.min(2, window.devicePixelRatio || 1);
      w = wrap.clientWidth; hgt = wrap.clientHeight;
      canvas.width = w * dpr; canvas.height = hgt * dpr;
      canvas.style.width = w + "px"; canvas.style.height = hgt + "px";
    };
    resize();
    const ro = new ResizeObserver(resize); ro.observe(wrap);

    const proj = (n: { x: number; y: number; z: number }) => {
      const cY = Math.cos(C.rotY), sY = Math.sin(C.rotY), cX = Math.cos(C.rotX), sX = Math.sin(C.rotX);
      const x1 = n.x * cY + n.z * sY, z1 = -n.x * sY + n.z * cY;
      const y2 = n.y * cX - z1 * sX, z2 = n.y * sX + z1 * cX;
      const s = (F / (F + z2)) * C.zoom;
      return { sx: w / 2 + x1 * s, sy: hgt / 2 + y2 * s, s, z: z2 };
    };

    const draw = () => {
      const t = performance.now();
      const { nodes, links } = dataRef.current;
      if (C.auto && !dragging && t > C.resumeAt) C.rotY += 0.0014;
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      ctx.clearRect(0, 0, w, hgt);

      // starfield
      for (let i = 0; i < stars.length; i++) {
        const st = stars[i];
        const a = 0.05 + 0.09 * Math.abs(Math.sin(t * 0.0004 + st.p));
        ctx.fillStyle = `rgba(255,255,255,${a.toFixed(3)})`;
        ctx.beginPath(); ctx.arc(st.x * w, st.y * hgt, st.r, 0, Math.PI * 2); ctx.fill();
      }

      const P = nodes.map(proj);
      // links, tinted by the child node's color
      for (const L of links) {
        const pa = P[L.a], pb = P[L.b], n = nodes[L.a];
        const al = Math.max(0.05, (L.spoke ? 0.22 : 0.15) * Math.min(pa.s, pb.s));
        ctx.strokeStyle = n.color + Math.round(al * 255).toString(16).padStart(2, "0");
        ctx.lineWidth = L.spoke ? 1.1 : 0.8;
        ctx.beginPath(); ctx.moveTo(pa.sx, pa.sy); ctx.lineTo(pb.sx, pb.sy); ctx.stroke();
      }
      // pulses travelling along spokes toward the core
      let si = 0;
      for (const L of links) {
        if (!L.spoke) continue;
        const pa = P[L.a], pb = P[L.b];
        const tt = (t * 0.00016 + si * 0.23) % 1;
        const px = pa.sx + (pb.sx - pa.sx) * tt, py = pa.sy + (pb.sy - pa.sy) * tt;
        ctx.fillStyle = `rgba(245,180,0,${(0.5 * Math.min(pa.s, pb.s)).toFixed(3)})`;
        ctx.shadowColor = "#F5B400"; ctx.shadowBlur = 6;
        ctx.beginPath(); ctx.arc(px, py, 1.5, 0, Math.PI * 2); ctx.fill();
        ctx.shadowBlur = 0; si++;
      }

      const order = P.map((_, i) => i).sort((a, b) => P[b].z - P[a].z);
      hover = -1; let hd = 220;
      if (mx >= 0) for (const i of order) {
        const p = P[i]; const d = (p.sx - mx) ** 2 + (p.sy - my) ** 2;
        if (d < hd) { hd = d; hover = i; }
      }
      for (const i of order) {
        const n = nodes[i], p = P[i];
        const r = Math.max(1.2, n.r * p.s);
        const hot = i === hover || (selRef.current !== null && n.name === selRef.current.name && n.kind === selRef.current.kind);
        const depthA = Math.max(0.3, Math.min(1, p.s));
        // hub ring
        if (n.hub) {
          ctx.strokeStyle = n.color + "38"; ctx.lineWidth = 1;
          ctx.beginPath(); ctx.arc(p.sx, p.sy, r * 1.75, 0, Math.PI * 2); ctx.stroke();
        }
        ctx.shadowColor = n.color; ctx.shadowBlur = hot ? 26 : (n.hub ? 17 : 11);
        ctx.globalAlpha = depthA * (hot ? 1 : 0.93);
        ctx.fillStyle = n.color;
        ctx.beginPath(); ctx.arc(p.sx, p.sy, hot ? r * 1.3 : r, 0, Math.PI * 2); ctx.fill();
        // specular core
        ctx.shadowBlur = 0;
        ctx.fillStyle = "rgba(255,255,255,0.4)";
        ctx.beginPath(); ctx.arc(p.sx - r * 0.25, p.sy - r * 0.3, r * 0.3, 0, Math.PI * 2); ctx.fill();
        ctx.globalAlpha = 1;
        if (n.hub && p.z < 0 && !hot) {
          ctx.font = "10px JetBrains Mono, monospace"; ctx.fillStyle = "rgba(255,255,255,0.34)";
          ctx.fillText(n.name, p.sx + r + 8, p.sy + 3);
        }
      }
      // hover tooltip chip
      if (hover >= 0) {
        const n = nodes[hover], p = P[hover];
        ctx.font = "11px JetBrains Mono, monospace";
        const label = n.name, sub = (KIND_LABEL[n.kind] || "File").toUpperCase();
        const tw = Math.max(ctx.measureText(label).width, ctx.measureText(sub).width * 0.82) + 20;
        let bx = p.sx + 14, by = p.sy - 20;
        if (bx + tw > w - 8) bx = p.sx - tw - 14;
        if (by < 8) by = p.sy + 12;
        ctx.fillStyle = "rgba(8,8,8,0.88)";
        ctx.strokeStyle = "rgba(255,255,255,0.14)"; ctx.lineWidth = 1;
        ctx.beginPath(); (ctx as any).roundRect(bx, by, tw, 36, 8); ctx.fill(); ctx.stroke();
        ctx.fillStyle = "rgba(255,255,255,0.92)"; ctx.fillText(label, bx + 10, by + 15);
        ctx.font = "8px JetBrains Mono, monospace"; ctx.fillStyle = n.color;
        ctx.fillText(sub, bx + 10, by + 28);
      }
      canvas.style.cursor = hover >= 0 ? "pointer" : dragging ? "grabbing" : "grab";
      raf = requestAnimationFrame(draw);
    };
    raf = requestAnimationFrame(draw);

    const down = (e: PointerEvent) => { dragging = true; moved = false; lastX = e.clientX; lastY = e.clientY; canvas.setPointerCapture(e.pointerId); };
    const move = (e: PointerEvent) => {
      const rect = canvas.getBoundingClientRect();
      mx = e.clientX - rect.left; my = e.clientY - rect.top;
      if (!dragging) return;
      if (Math.abs(e.clientX - lastX) + Math.abs(e.clientY - lastY) > 2) moved = true;
      C.rotY += (e.clientX - lastX) * 0.005;
      C.rotX = Math.max(-1.3, Math.min(1.3, C.rotX + (e.clientY - lastY) * 0.005));
      lastX = e.clientX; lastY = e.clientY;
    };
    const up = () => {
      dragging = false; C.resumeAt = performance.now() + 2500;
      if (!moved && hover >= 0) setSelected(dataRef.current.nodes[hover]);
      else if (!moved) setSelected(null);
    };
    const leave = () => { mx = -1; my = -1; };
    const wheel = (e: WheelEvent) => { e.preventDefault(); C.zoom = Math.max(0.45, Math.min(2.6, C.zoom * (e.deltaY > 0 ? 0.93 : 1.075))); };
    canvas.addEventListener("pointerdown", down);
    canvas.addEventListener("pointermove", move);
    canvas.addEventListener("pointerup", up);
    canvas.addEventListener("pointerleave", leave);
    canvas.addEventListener("wheel", wheel, { passive: false });
    return () => {
      cancelAnimationFrame(raf); ro.disconnect();
      canvas.removeEventListener("pointerdown", down); canvas.removeEventListener("pointermove", move);
      canvas.removeEventListener("pointerup", up); canvas.removeEventListener("pointerleave", leave);
      canvas.removeEventListener("wheel", wheel);
    };
  }, []);

  const togglePause = () => { ctrlRef.current.auto = !ctrlRef.current.auto; ctrlRef.current.resumeAt = 0; setPaused(!ctrlRef.current.auto); };
  const resetView = () => { const C = ctrlRef.current; C.rotY = 0.6; C.rotX = -0.22; C.zoom = 1.15; C.resumeAt = 0; };
  const selAgent = selected?.kind === "conversation" && selected.project ? getAgent(selected.project) : null;

  return (
    <div className="relative rounded-2xl border border-white/[0.08] overflow-hidden mb-6"
      style={{ background: "linear-gradient(180deg, rgba(255,255,255,0.025), rgba(0,0,0,0.25))" }}>
      <div className="absolute top-0 left-0 right-0 z-10 flex items-center justify-between px-5 pt-4 pointer-events-none">
        <div className="flex items-center gap-2.5">
          <span className="h-1.5 w-1.5 rounded-full bg-amber-400 animate-pulse" style={{ boxShadow: "0 0 8px #f5b400" }} />
          <span className="font-mono text-[11px] tracking-[0.3em] text-white/80">MEMORY CONSTELLATION</span>
          <span className="font-mono text-[10px] text-white/35">
            {failed ? "· OFFLINE" : meta === null ? "· READING VAULT…" : `· ${meta.count} FILES · ${kb(meta.totalBytes)} · LIVE`}
          </span>
        </div>
        <div className="flex items-center gap-1.5 pointer-events-auto">
          <button onClick={togglePause} title={paused ? "Resume rotation" : "Pause rotation"}
            className="h-7 w-7 grid place-items-center rounded-full border border-white/10 bg-black/40 hover:bg-white/10 text-white/50 hover:text-white">
            {paused ? <Play className="h-3 w-3" strokeWidth={2} /> : <Pause className="h-3 w-3" strokeWidth={2} />}
          </button>
          <button onClick={resetView} title="Reset view"
            className="h-7 w-7 grid place-items-center rounded-full border border-white/10 bg-black/40 hover:bg-white/10 text-white/50 hover:text-white">
            <RotateCcw className="h-3 w-3" strokeWidth={2} />
          </button>
        </div>
      </div>

      <div ref={wrapRef} className="h-[460px] md:h-[560px] w-full"
        style={{ background: "radial-gradient(ellipse at 50% 45%, rgba(245,180,0,0.05), transparent 60%)" }}>
        <canvas ref={canvasRef} className="touch-none" />
      </div>

      <div className="absolute bottom-0 left-0 right-0 z-10 flex items-center justify-between gap-3 px-5 pb-4 flex-wrap pointer-events-none">
        <div className="flex items-center gap-4 flex-wrap">
          {Object.keys(KIND_LABEL).filter(k => k !== "other").map(k => (
            <span key={k} className="flex items-center gap-1.5 font-mono text-[9px] tracking-[0.18em] text-white/50">
              <span className="h-1.5 w-1.5 rounded-full" style={{ background: KIND_COLOR[k], boxShadow: `0 0 6px ${KIND_COLOR[k]}` }} />
              {KIND_LABEL[k].toUpperCase()}
              <span className="text-white/85 tabular-nums">{meta?.byKind[k] ?? 0}</span>
            </span>
          ))}
        </div>
        <span className="font-mono text-[9px] tracking-[0.18em] text-white/25 hidden md:inline">DRAG TO ROTATE · SCROLL TO ZOOM · CLICK TO INSPECT</span>
      </div>

      {selected && (
        <div className="absolute top-14 right-4 z-10 w-72 rounded-xl border border-white/12 bg-black/90 backdrop-blur-md p-4">
          <div className="flex items-start justify-between gap-2">
            <div className="min-w-0 flex-1">
              <div className="flex items-center gap-2 mb-1.5">
                <span className="h-2 w-2 rounded-full shrink-0" style={{ background: selected.color, boxShadow: `0 0 8px ${selected.color}` }} />
                <span className="text-[13px] text-white/95 font-medium truncate">{selected.name}</span>
              </div>
              <div className="font-mono text-[9px] tracking-[0.18em] uppercase mb-2.5" style={{ color: selected.color }}>
                {(KIND_LABEL[selected.kind] || "File").replace(/s$/, "")}
                {selAgent ? ` · ${selAgent.name}` : selected.project && selected.project !== selected.name ? ` · ${selected.project}` : ""}
              </div>
              <div className="space-y-1 text-[11px] text-white/55">
                <div className="flex justify-between"><span className="text-white/35 font-mono text-[9px] tracking-[0.14em]">SIZE</span><span className="tabular-nums">{kb(selected.size)}</span></div>
                <div className="flex justify-between"><span className="text-white/35 font-mono text-[9px] tracking-[0.14em]">UPDATED</span><span>{new Date(selected.updated).toLocaleString(undefined, { dateStyle: "medium", timeStyle: "short" })}</span></div>
              </div>
              {onSearch && (
                <button onClick={() => { onSearch(selected.name); setSelected(null); }}
                  className="mt-3 w-full flex items-center justify-center gap-1.5 px-3 py-1.5 rounded-full bg-amber-400/15 border border-amber-400/30 hover:bg-amber-400/25 font-mono text-[10px] tracking-[0.16em] text-amber-300">
                  <Search className="h-3 w-3" strokeWidth={2} /> SEARCH THIS FILE
                </button>
              )}
            </div>
            <button onClick={() => setSelected(null)} className="h-5 w-5 grid place-items-center rounded-full hover:bg-white/10 text-white/40 hover:text-white shrink-0">
              <X className="h-3 w-3" strokeWidth={1.5} />
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
