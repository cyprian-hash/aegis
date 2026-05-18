"use client";
import { motion } from "framer-motion";
import { COLOR_MAP } from "@/lib/theme";

type AgentColor = keyof typeof COLOR_MAP;

interface AvatarProps {
  agentId: string;
  size?: number;
  animated?: boolean;
}

// Each agent gets a unique generative avatar.
// Designed as concentric "sigils" — abstract, recognizable, on-brand.
export default function AgentAvatar({ agentId, size = 56, animated = true }: AvatarProps) {
  const config = SIGILS[agentId] || SIGILS["claude-prime"];
  const c = COLOR_MAP[config.color];

  return (
    <div
      className="relative shrink-0"
      style={{ width: size, height: size }}
    >
      {/* outer glow */}
      <div
        className="absolute inset-0 rounded-full opacity-60"
        style={{ background: `radial-gradient(circle, ${c.glow} 0%, transparent 70%)` }}
      />
      <svg
        viewBox="0 0 100 100"
        width={size}
        height={size}
        className="relative z-10"
        style={{ filter: `drop-shadow(0 0 8px ${c.glow})` }}
      >
        <defs>
          <radialGradient id={`bg-${agentId}`} cx="50%" cy="50%" r="50%">
            <stop offset="0%" stopColor={c.hex} stopOpacity="0.18" />
            <stop offset="100%" stopColor={c.hex} stopOpacity="0.02" />
          </radialGradient>
          <linearGradient id={`stroke-${agentId}`} x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" stopColor={c.hex} stopOpacity="1" />
            <stop offset="100%" stopColor={c.hex} stopOpacity="0.4" />
          </linearGradient>
        </defs>

        {/* shared base: hexagonal container */}
        <polygon
          points="50,4 87,25 87,75 50,96 13,75 13,25"
          fill={`url(#bg-${agentId})`}
          stroke={c.hex}
          strokeOpacity="0.4"
          strokeWidth="1"
        />

        {/* rotating outer ring */}
        {animated && (
          <motion.g
            animate={{ rotate: 360 }}
            transition={{ duration: 24, repeat: Infinity, ease: "linear" }}
            style={{ transformOrigin: "50px 50px" }}
          >
            <circle cx="50" cy="50" r="44" fill="none" stroke={c.hex} strokeOpacity="0.15" strokeWidth="0.5" strokeDasharray="2 3" />
          </motion.g>
        )}

        {/* unique glyph per agent */}
        {config.glyph(c.hex, agentId, animated)}
      </svg>
    </div>
  );
}

const SIGILS: Record<string, { color: AgentColor; glyph: (hex: string, id: string, animated: boolean) => JSX.Element }> = {
  // PRIME: neural web — central node + connected satellites
  "claude-prime": {
    color: "amber",
    glyph: (hex, id, animated) => (
      <g stroke={hex} strokeWidth="1.2" fill="none" strokeLinecap="round">
        {/* connecting lines */}
        <line x1="50" y1="50" x2="30" y2="32" strokeOpacity="0.55" />
        <line x1="50" y1="50" x2="70" y2="32" strokeOpacity="0.55" />
        <line x1="50" y1="50" x2="30" y2="68" strokeOpacity="0.55" />
        <line x1="50" y1="50" x2="70" y2="68" strokeOpacity="0.55" />
        <line x1="50" y1="50" x2="50" y2="26" strokeOpacity="0.55" />
        <line x1="50" y1="50" x2="50" y2="74" strokeOpacity="0.55" />
        {/* satellite nodes */}
        <circle cx="30" cy="32" r="2.4" fill={hex} stroke="none" />
        <circle cx="70" cy="32" r="2.4" fill={hex} stroke="none" />
        <circle cx="30" cy="68" r="2.4" fill={hex} stroke="none" />
        <circle cx="70" cy="68" r="2.4" fill={hex} stroke="none" />
        <circle cx="50" cy="26" r="2.4" fill={hex} stroke="none" />
        <circle cx="50" cy="74" r="2.4" fill={hex} stroke="none" />
        {/* center core with pulse */}
        <circle cx="50" cy="50" r="6" fill={hex} fillOpacity="0.2" />
        {animated ? (
          <motion.circle cx="50" cy="50" r="4" fill={hex}
            animate={{ scale: [1, 1.2, 1] }}
            transition={{ duration: 2, repeat: Infinity }}
            style={{ transformOrigin: "50px 50px" }} />
        ) : (
          <circle cx="50" cy="50" r="4" fill={hex} />
        )}
      </g>
    ),
  },

  // SCOUT: radar scanner — concentric arcs with rotating sweep
  "scout-01": {
    color: "cyan",
    glyph: (hex, id, animated) => (
      <g>
        {/* concentric arcs */}
        <circle cx="50" cy="50" r="10" fill="none" stroke={hex} strokeOpacity="0.7" strokeWidth="1" />
        <circle cx="50" cy="50" r="18" fill="none" stroke={hex} strokeOpacity="0.45" strokeWidth="1" />
        <circle cx="50" cy="50" r="26" fill="none" stroke={hex} strokeOpacity="0.25" strokeWidth="1" />
        {/* cross-hair */}
        <line x1="50" y1="22" x2="50" y2="32" stroke={hex} strokeOpacity="0.6" strokeWidth="1" />
        <line x1="50" y1="68" x2="50" y2="78" stroke={hex} strokeOpacity="0.6" strokeWidth="1" />
        <line x1="22" y1="50" x2="32" y2="50" stroke={hex} strokeOpacity="0.6" strokeWidth="1" />
        <line x1="68" y1="50" x2="78" y2="50" stroke={hex} strokeOpacity="0.6" strokeWidth="1" />
        {/* sweep */}
        {animated && (
          <motion.g
            animate={{ rotate: 360 }}
            transition={{ duration: 3, repeat: Infinity, ease: "linear" }}
            style={{ transformOrigin: "50px 50px" }}
          >
            <path d="M 50 50 L 78 50 A 28 28 0 0 0 70 30 Z" fill={hex} fillOpacity="0.2" />
          </motion.g>
        )}
        {/* core dot */}
        <circle cx="50" cy="50" r="3" fill={hex} />
      </g>
    ),
  },

  // FORGE: nested code brackets / chevrons
  "forge-02": {
    color: "violet",
    glyph: (hex, id, animated) => (
      <g stroke={hex} fill="none" strokeLinecap="round" strokeLinejoin="round">
        {/* outer chevrons */}
        <path d="M 28 32 L 18 50 L 28 68" strokeWidth="2" strokeOpacity="0.5" />
        <path d="M 72 32 L 82 50 L 72 68" strokeWidth="2" strokeOpacity="0.5" />
        {/* inner chevrons */}
        <path d="M 38 38 L 30 50 L 38 62" strokeWidth="1.5" strokeOpacity="0.8" />
        <path d="M 62 38 L 70 50 L 62 62" strokeWidth="1.5" strokeOpacity="0.8" />
        {/* diagonal slash */}
        <line x1="56" y1="34" x2="44" y2="66" stroke={hex} strokeWidth="1.5" />
        {/* center pulse */}
        {animated ? (
          <motion.circle cx="50" cy="50" r="2" fill={hex}
            animate={{ opacity: [0.4, 1, 0.4] }}
            transition={{ duration: 1.5, repeat: Infinity }} />
        ) : (
          <circle cx="50" cy="50" r="2" fill={hex} />
        )}
      </g>
    ),
  },

  // ARCHIVE: stacked horizontal layers (storage / database)
  "archive-03": {
    color: "emerald",
    glyph: (hex, id, animated) => (
      <g stroke={hex} fill="none" strokeLinecap="round">
        {/* db cylinders / stacked layers */}
        <ellipse cx="50" cy="28" rx="20" ry="5" strokeWidth="1.2" strokeOpacity="0.9" />
        <path d="M 30 28 L 30 42 A 20 5 0 0 0 70 42 L 70 28" strokeWidth="1.2" strokeOpacity="0.9" />
        <ellipse cx="50" cy="42" rx="20" ry="5" strokeWidth="1.2" strokeOpacity="0.55" />
        <path d="M 30 42 L 30 56 A 20 5 0 0 0 70 56 L 70 42" strokeWidth="1.2" strokeOpacity="0.55" />
        <ellipse cx="50" cy="56" rx="20" ry="5" strokeWidth="1.2" strokeOpacity="0.35" />
        <path d="M 30 56 L 30 70 A 20 5 0 0 0 70 70 L 70 56" strokeWidth="1.2" strokeOpacity="0.35" />
        <ellipse cx="50" cy="70" rx="20" ry="5" strokeWidth="1.2" strokeOpacity="0.2" />
        {/* indicator dots */}
        {animated ? (
          <>
            <motion.circle cx="62" cy="28" r="1.5" fill={hex}
              animate={{ opacity: [1, 0.3, 1] }} transition={{ duration: 2, repeat: Infinity }} />
            <motion.circle cx="62" cy="42" r="1.5" fill={hex}
              animate={{ opacity: [0.3, 1, 0.3] }} transition={{ duration: 2, repeat: Infinity, delay: 0.5 }} />
            <motion.circle cx="62" cy="56" r="1.5" fill={hex}
              animate={{ opacity: [1, 0.3, 1] }} transition={{ duration: 2, repeat: Infinity, delay: 1 }} />
          </>
        ) : (
          <>
            <circle cx="62" cy="28" r="1.5" fill={hex} />
            <circle cx="62" cy="42" r="1.5" fill={hex} />
            <circle cx="62" cy="56" r="1.5" fill={hex} />
          </>
        )}
      </g>
    ),
  },

  // WEAVER: interlocking flow lines (workflow / orchestration)
  "weaver-04": {
    color: "rose",
    glyph: (hex, id, animated) => (
      <g stroke={hex} fill="none" strokeWidth="1.4" strokeLinecap="round">
        {/* three flow lines that interlock */}
        <path d="M 26 32 Q 38 38, 38 50 Q 38 62, 50 62 Q 62 62, 62 50 Q 62 38, 74 32"
          strokeOpacity="0.85" />
        <path d="M 26 50 Q 38 50, 38 50" strokeOpacity="0" />
        <path d="M 26 68 Q 38 62, 38 50 Q 38 38, 50 38 Q 62 38, 62 50 Q 62 62, 74 68"
          strokeOpacity="0.55" />
        {/* junction nodes */}
        <circle cx="38" cy="50" r="2.2" fill={hex} stroke="none" />
        <circle cx="50" cy="50" r="2.6" fill={hex} stroke="none" />
        <circle cx="62" cy="50" r="2.2" fill={hex} stroke="none" />
        {/* endpoints */}
        <circle cx="26" cy="32" r="1.5" fill={hex} stroke="none" />
        <circle cx="74" cy="32" r="1.5" fill={hex} stroke="none" />
        <circle cx="26" cy="68" r="1.5" fill={hex} stroke="none" />
        <circle cx="74" cy="68" r="1.5" fill={hex} stroke="none" />
        {animated && (
          <motion.circle cx="50" cy="50" r="1.5" fill="white"
            animate={{
              offsetDistance: ["0%", "100%"],
              opacity: [0, 1, 0],
            }}
            transition={{ duration: 3, repeat: Infinity }} />
        )}
      </g>
    ),
  },

  // SENTRY: shield with crosshatch + corner ticks
  "sentry-05": {
    color: "sky",
    glyph: (hex, id, animated) => (
      <g stroke={hex} fill="none" strokeLinecap="round">
        {/* shield outline */}
        <path d="M 50 24 L 70 32 L 70 50 Q 70 66, 50 76 Q 30 66, 30 50 L 30 32 Z"
          strokeWidth="1.4" strokeOpacity="0.85" fill={hex} fillOpacity="0.05" />
        {/* inner detail */}
        <path d="M 50 32 L 62 38 L 62 50 Q 62 60, 50 68 Q 38 60, 38 50 L 38 38 Z"
          strokeWidth="1" strokeOpacity="0.4" />
        {/* checkmark */}
        {animated ? (
          <motion.path d="M 42 50 L 48 56 L 58 44"
            stroke={hex} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"
            initial={{ pathLength: 0 }}
            animate={{ pathLength: [0, 1, 1, 0] }}
            transition={{ duration: 3, repeat: Infinity, times: [0, 0.4, 0.85, 1] }} />
        ) : (
          <path d="M 42 50 L 48 56 L 58 44" stroke={hex} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
        )}
      </g>
    ),
  },

  // HERMES: winged caduceus — twin serpents around a staff with wings
  "hermes-07": {
    color: "gold",
    glyph: (hex, id, animated) => (
      <g stroke={hex} fill="none" strokeLinecap="round" strokeLinejoin="round">
        <line x1="50" y1="22" x2="50" y2="78" strokeWidth="1.5" strokeOpacity="0.9" />
        <path d="M 50 30 Q 38 28, 32 34 Q 30 36, 32 38 Q 38 36, 50 36"
          strokeWidth="1.3" strokeOpacity="0.85" />
        <path d="M 50 30 Q 62 28, 68 34 Q 70 36, 68 38 Q 62 36, 50 36"
          strokeWidth="1.3" strokeOpacity="0.85" />
        <path d="M 50 34 Q 40 33, 36 38 M 50 34 Q 60 33, 64 38"
          strokeWidth="0.8" strokeOpacity="0.55" />
        <path d="M 50 42 Q 42 46, 50 52 Q 58 58, 50 64 Q 44 68, 48 72"
          strokeWidth="1.3" strokeOpacity="0.75" />
        <path d="M 50 42 Q 58 46, 50 52 Q 42 58, 50 64 Q 56 68, 52 72"
          strokeWidth="1.3" strokeOpacity="0.55" />
        <circle cx="48" cy="72" r="1.6" fill={hex} stroke="none" />
        <circle cx="52" cy="72" r="1.6" fill={hex} stroke="none" />
        {animated ? (
          <motion.circle cx="50" cy="22" r="2.4" fill={hex}
            animate={{ scale: [1, 1.25, 1], opacity: [0.85, 1, 0.85] }}
            transition={{ duration: 2.2, repeat: Infinity }}
            style={{ transformOrigin: "50px 22px" }} />
        ) : (
          <circle cx="50" cy="22" r="2.4" fill={hex} />
        )}
      </g>
    ),
  },
};
