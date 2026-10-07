"use client";
import { useEffect, useRef, useState } from "react";
import { X } from "lucide-react";

interface MemFile { name: string; kind: string; project?: string; size: number; updated: string; }
interface Node extends MemFile { x: number; y: number; z: number; r: number; color: string; hub?: boolean; }

const KIND_COLOR: Record<string, string> = {
  brief: "#22D3EE", conversation: "#34D399", context: "#F5B400",
  source: "#A78BFA", strategy: "#FB7185", other: "#94A3B8",
};
const KIND_LABEL: Record<string, string> = {
  brief: "Brief", conversation: "Conversation", context: "Context",
  source: "Source Doc", strategy: "Strategy", other: "File",
};

// Deterministic hash -> [0,1)
function h(s: string, salt = 0): number {
  let x = 2166136261 ^ salt;
  for (let i = 0; i < s.length; i++) { x ^= s.charCodeAt(i); x = Math.imul(x, 16777619); }
  return ((x >>> 0) % 100000) / 100000;
}
function sphereDir(u: number, v: number): [number, number, number] {
  const th = u * Math.PI * 2, ph = Math.acos(2 * v - 1);
  return [Math.sin(ph) * Math.cos(th), Math.cos(ph), Math.sin(ph) * Math.sin(th)];
}

function layout(files: MemFile[]): { nodes: Node[]; links: [number, number][] } {
  const nodes: Node[] = []; const links: [number, number][] = [];
  const rOf = (size: number) => Math.min(7.5, 2.6 + Math.log10(Math.max(100, size)) * 1.1);
  const briefs = files.filter(f => f.kind === "brief").sort((a, b) => a.name.localeCompare(b.name));
  const GA = Math.PI * (3 - Math.sqrt(5)); // golden angle
  const briefIdx: Record<string, number> = {};
  briefs.forEach((f, i) => {
    const y = briefs.length > 1 ? 1 - (2 * i) / (briefs.length - 1) : 0;
    const rad = Math.sqrt(Math.max(0, 1 - y * y)), th = GA * i;
    nodes.push({ ...f, x: Math.cos(th) * rad * 95, y: y * 70, z: Math.sin(th) * rad * 95, r: rOf(f.size) + 1.2, color: KIND_COLOR.brief, hub: true });
    briefIdx[(f.project || f.name).toLowerCase()] = nodes.length - 1;
  });
  files.filter(f => f.kind === "context").forEach(f => {
    const [dx, dy, dz] = sphereDir(h(f.name), h(f.name, 7));
    nodes.push({ ...f, x: dx * 24, y: dy * 18, z: dz * 24, r: rOf(f.size), color: KIND_COLOR.context });
  });
  files.filter(f => f.kind === "source" || f.kind === "strategy").forEach(f => {
    const pi = briefIdx[(f.project || "").toLowerCase()];
    const [dx, dy, dz] = sphereDir(h(f.name, 3), h(f.name, 11));
    if (pi !== undefined) {
      const p = nodes[pi];
      nodes.push({ ...f, x: p.x + dx * 26, y: p.y + dy * 22, z: p.z + dz * 26, r: rOf(f.size), color: KIND_COLOR[f.kind] });
      links.push([nodes.length - 1, pi]);
    } else {
      nodes.push({ ...f, x: dx * 125, y: dy * 90, z: dz * 125, r: rOf(f.size), color: KIND_COLOR[f.kind] });
    }
  });
  const convs = files.filter(f => f.kind === "conversation");
  const agents = Array.from(new Set(convs.map(f => f.project || "agent"))).sort();
  const centers: Record<string, [number, number, number]> = {};
  agents.forEach((a, i) => {
    const y = agents.length > 1 ? 1 - (2 * i) / (agents.length - 1) : 0;
    const rad = Math.sqrt(Math.max(0, 1 - y * y)), th = GA * i + 1.7;
    centers[a] = [Math.cos(th) * rad * 158, y * 105, Math.sin(th) * rad * 158];
  });
  const firstOf: Record<string, number> = {};
  convs.forEach(f => {
    const a = f.project || "agent"; const c = centers[a];
    const [dx, dy, dz] = sphereDir(h(f.name, 5), h(f.name, 13));
    nodes.push({ ...f, x: c[0] + dx * 17, y: c[1] + dy * 14, z: c[2] + dz * 17, r: rOf(f.size), color: KIND_COLOR.conversation });
    const i = nodes.length - 1;
    if (firstOf[a] === undefined) firstOf[a] = i; else links.push([i, firstOf[a]]);
  });
  Object.values(briefIdx).forEach(i => { // faint spokes: briefs -> core
    let nearest = -1, best = 1e9;
    nodes.forEach((n, j) => { if (n.kind === "context") { const d = (n.x - nodes[i].x) ** 2 + (n.y - nodes[i].y) ** 2 + (n.z - nodes[i].z) ** 2; if (d < best) { best = d; nearest = j; } } });
    if (nearest >= 0) links.push([i, nearest]);
  });
  return { nodes, links };
}

export default function MemoryConstellation() {
  const wrapRef = useRef<HTMLDivElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const dataRef = useRef<{ nodes: Node[]; links: [number, number][] }>({ nodes: [], links: [] });
  const [count, setCount] = useState<number | null>(null);
  const [failed, setFailed] = useState(false);
  const [selected, setSelected] = useState<Node | null>(null);
  const selRef = useRef<Node | null>(null);
  useEffect(() => { selRef.current = selected; }, [selected]);

  useEffect(() => {
    let alive = true;
    fetch("/api/memory?list=1").then(r => r.json()).then(j => {
      if (!alive) return;
      if (j.ok && Array.isArray(j.files)) { dataRef.current = layout(j.files); setCount(j.files.length); }
      else setFailed(true);
    }).catch(() => alive && setFailed(true));
    return () => { alive = false; };
  }, []);

  useEffect(() => {
    const canvas = canvasRef.current, wrap = wrapRef.current;
    if (!canvas || !wrap) return;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;
    let w = 0, hgt = 0, dpr = 1, raf = 0;
    let rotY = 0.6, rotX = -0.22, zoom = 1, auto = true;
    let dragging = false, lastX = 0, lastY = 0;
    let hover = -1, mx = -1, my = -1;
    const F = 430;
    const resize = () => {
      dpr = Math.min(2, window.devicePixelRatio || 1);
      w = wrap.clientWidth; hgt = wrap.clientHeight;
      canvas.width = w * dpr; canvas.height = hgt * dpr;
      canvas.style.width = w + "px"; canvas.style.height = hgt + "px";
    };
    resize();
    const ro = new ResizeObserver(resize); ro.observe(wrap);

    const proj = (n: { x: number; y: number; z: number }) => {
      const cY = Math.cos(rotY), sY = Math.sin(rotY), cX = Math.cos(rotX), sX = Math.sin(rotX);
      const x1 = n.x * cY + n.z * sY, z1 = -n.x * sY + n.z * cY;
      const y2 = n.y * cX - z1 * sX, z2 = n.y * sX + z1 * cX;
      const s = (F / (F + z2)) * zoom;
      return { sx: w / 2 + x1 * s, sy: hgt / 2 + y2 * s, s, z: z2 };
    };

    const draw = () => {
      const { nodes, links } = dataRef.current;
      if (auto && !dragging) rotY += 0.0016;
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      ctx.clearRect(0, 0, w, hgt);
      const P = nodes.map(proj);
      ctx.lineWidth = 1;
      for (const [a, b] of links) {
        const pa = P[a], pb = P[b];
        const al = Math.max(0.04, 0.16 * Math.min(pa.s, pb.s));
        ctx.strokeStyle = `rgba(255,255,255,${al.toFixed(3)})`;
        ctx.beginPath(); ctx.moveTo(pa.sx, pa.sy); ctx.lineTo(pb.sx, pb.sy); ctx.stroke();
      }
      const order = P.map((p, i) => i).sort((a, b) => P[b].z - P[a].z);
      hover = -1; let hd = 196;
      for (const i of order) {
        const p = P[i];
        if (mx >= 0) { const d = (p.sx - mx) ** 2 + (p.sy - my) ** 2; if (d < hd) { hd = d; hover = i; } }
      }
      for (const i of order) {
        const n = nodes[i], p = P[i];
        const r = Math.max(1, n.r * p.s);
        const hot = i === hover || (selRef.current && n.name === selRef.current.name && n.kind === selRef.current.kind);
        ctx.shadowColor = n.color; ctx.shadowBlur = hot ? 22 : (n.hub ? 14 : 9);
        ctx.globalAlpha = Math.max(0.35, Math.min(1, p.s)) * (hot ? 1 : 0.92);
        ctx.fillStyle = n.color;
        ctx.beginPath(); ctx.arc(p.sx, p.sy, hot ? r * 1.35 : r, 0, Math.PI * 2); ctx.fill();
        ctx.shadowBlur = 0; ctx.globalAlpha = 1;
        if (hot) {
          ctx.font = "10px JetBrains Mono, monospace"; ctx.fillStyle = "rgba(255,255,255,0.92)";
          ctx.fillText(n.name, p.sx + r + 7, p.sy + 3);
        } else if (n.hub && p.z < 0) {
          ctx.font = "9px JetBrains Mono, monospace"; ctx.fillStyle = "rgba(255,255,255,0.28)";
          ctx.fillText(n.name, p.sx + r + 6, p.sy + 3);
        }
      }
      canvas.style.cursor = hover >= 0 ? "pointer" : dragging ? "grabbing" : "grab";
      raf = requestAnimationFrame(draw);
    };
    raf = requestAnimationFrame(draw);

    let moved = false;
    const down = (e: PointerEvent) => { dragging = true; moved = false; auto = false; lastX = e.clientX; lastY = e.clientY; canvas.setPointerCapture(e.pointerId); };
    const move = (e: PointerEvent) => {
      const rect = canvas.getBoundingClientRect();
      mx = e.clientX - rect.left; my = e.clientY - rect.top;
      if (!dragging) return;
      if (Math.abs(e.clientX - lastX) + Math.abs(e.clientY - lastY) > 2) moved = true;
      rotY += (e.clientX - lastX) * 0.005;
      rotX = Math.max(-1.3, Math.min(1.3, rotX + (e.clientY - lastY) * 0.005));
      lastX = e.clientX; lastY = e.clientY;
    };
    const up = () => {
      dragging = false; setTimeout(() => { auto = true; }, 2500);
      if (!moved && hover >= 0) setSelected(dataRef.current.nodes[hover]);
      else if (!moved) setSelected(null);
    };
    const leave = () => { mx = -1; my = -1; };
    const wheel = (e: WheelEvent) => { e.preventDefault(); zoom = Math.max(0.45, Math.min(2.4, zoom * (e.deltaY > 0 ? 0.93 : 1.075))); };
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

  const kb = (n: number) => n < 1024 ? `${n} B` : `${(n / 1024).toFixed(1)} KB`;
  return (
    <div className="relative rounded-2xl border border-white/[0.07] bg-white/[0.02] overflow-hidden mb-6">
      <div className="absolute top-4 left-5 z-10 flex items-center gap-2 pointer-events-none">
        <span className="h-1.5 w-1.5 rounded-full bg-amber-400 animate-pulse" />
        <span className="font-mono text-[10px] tracking-[0.28em] text-white/70">MEMORY CONSTELLATION</span>
        <span className="font-mono text-[10px] text-white/30">{failed ? "· OFFLINE" : count === null ? "· READING VAULT…" : `· ${count} FILES · LIVE`}</span>
      </div>
      <div ref={wrapRef} className="h-[380px] w-full"
        style={{ background: "radial-gradient(ellipse at 50% 42%, rgba(245,180,0,0.045), transparent 62%)" }}>
        <canvas ref={canvasRef} className="touch-none" />
      </div>
      <div className="absolute bottom-3.5 left-5 z-10 flex items-center gap-4 flex-wrap pointer-events-none">
        {Object.keys(KIND_LABEL).filter(k => k !== "other").map(k => (
          <span key={k} className="flex items-center gap-1.5 font-mono text-[9px] tracking-[0.18em] text-white/45">
            <span className="h-1.5 w-1.5 rounded-full" style={{ background: KIND_COLOR[k], boxShadow: `0 0 5px ${KIND_COLOR[k]}` }} />
            {KIND_LABEL[k].toUpperCase()}
          </span>
        ))}
        <span className="font-mono text-[9px] tracking-[0.18em] text-white/25 hidden sm:inline">DRAG · SCROLL · CLICK</span>
      </div>
      {selected && (
        <div className="absolute top-4 right-4 z-10 w-60 rounded-xl border border-white/10 bg-black/85 backdrop-blur-md p-3.5">
          <div className="flex items-start justify-between gap-2">
            <div className="min-w-0">
              <div className="flex items-center gap-1.5 mb-1">
                <span className="h-1.5 w-1.5 rounded-full shrink-0" style={{ background: selected.color, boxShadow: `0 0 6px ${selected.color}` }} />
                <span className="text-[12px] text-white/90 truncate">{selected.name}</span>
              </div>
              <div className="font-mono text-[9px] tracking-[0.16em] text-white/40 uppercase">
                {KIND_LABEL[selected.kind] || "File"}{selected.project && selected.project !== selected.name ? ` · ${selected.project}` : ""}
              </div>
              <div className="mt-1.5 text-[10px] text-white/45">{kb(selected.size)} · updated {new Date(selected.updated).toLocaleDateString()}</div>
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
