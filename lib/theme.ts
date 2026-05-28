export const COLOR_MAP: Record<string, { hex: string; glow: string; soft: string }> = {
  ledgergreen: { hex: "#15803D", glow: "rgba(21,128,61,0.55)", soft: "rgba(21,128,61,0.08)" },
  teal: { hex: "#14B8A6", glow: "rgba(20,184,166,0.55)", soft: "rgba(20,184,166,0.08)" },
  crimson: { hex: "#E11D48", glow: "rgba(225,29,72,0.55)",   soft: "rgba(225,29,72,0.08)" },
  coral:   { hex: "#FF6B4A", glow: "rgba(255,107,74,0.55)",  soft: "rgba(255,107,74,0.08)" },
  gblue:   { hex: "#4285F4", glow: "rgba(66,133,244,0.55)",  soft: "rgba(66,133,244,0.08)" },
  amber:   { hex: "#f5b400", glow: "rgba(245,180,0,0.55)",  soft: "rgba(245,180,0,0.12)" },
  cyan:    { hex: "#22d3ee", glow: "rgba(34,211,238,0.55)", soft: "rgba(34,211,238,0.12)" },
  violet:  { hex: "#a78bfa", glow: "rgba(167,139,250,0.55)",soft: "rgba(167,139,250,0.12)" },
  emerald: { hex: "#34d399", glow: "rgba(52,211,153,0.55)", soft: "rgba(52,211,153,0.12)" },
  rose:    { hex: "#fb7185", glow: "rgba(251,113,133,0.55)",soft: "rgba(251,113,133,0.12)" },
  sky:     { hex: "#7dd3fc", glow: "rgba(125,211,252,0.55)",soft: "rgba(125,211,252,0.12)" },
  gold:    { hex: "#fbbf24", glow: "rgba(251,191,36,0.6)",  soft: "rgba(251,191,36,0.13)" },
};

export const pad = (n: number, w = 2) => String(n).padStart(w, "0");
export const fmtNum = (n: number) => n.toLocaleString("en-US");
export const fmtTime = (d: Date) =>
  `${pad(d.getUTCHours())}:${pad(d.getUTCMinutes())}:${pad(d.getUTCSeconds())} UTC`;
