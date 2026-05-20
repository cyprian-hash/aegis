export type ProjectStatus = "live" | "building" | "idea" | "archived";
export type HostingProvider = "vercel" | "netlify" | "supabase" | "other";

export interface IosInfo {
  bundleId: string;
  verified: boolean;
}

export interface Project {
  id: string;
  name: string;
  description: string;
  website?: string;
  repos: string[];
  hosting: HostingProvider[];
  ios?: IosInfo;
  status: ProjectStatus;
  /** Hex color including the leading # — e.g. "#285ED2" */
  color: string;
  /** Optional secondary brand color, e.g. for paper / accent variants */
  colorAlt?: string;
  /** Absolute path on local filesystem if the code lives on this Mac */
  localPath?: string;
  /** Primary contact email for the project */
  email?: string;
  /** Where that email is hosted */
  emailProvider?: "hostinger" | "google-workspace" | "forwarder" | "none";
  tags: string[];
  notes?: string;
  createdAt?: string;
  updatedAt?: string;
}

/** Derive a glow + soft-fill from a base hex. */
export function colorTokens(hex: string): { hex: string; glow: string; soft: string } {
  const m = hex.replace("#", "").match(/^([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})$/i);
  if (!m) return { hex, glow: hex + "88", soft: hex + "14" };
  const [r, g, b] = [m[1], m[2], m[3]].map((v) => parseInt(v, 16));
  return {
    hex,
    glow: `rgba(${r},${g},${b},0.55)`,
    soft: `rgba(${r},${g},${b},0.08)`,
  };
}

export const STATUS_COLOR: Record<ProjectStatus, string> = {
  live: "#34d399",
  building: "#f5b400",
  idea: "#94a3b8",
  archived: "#64748b",
};

// Privé Systems portfolio with exact brand colors
export const SEED_PROJECTS: Project[] = [
  {
    id: "prive-systems",
    name: "Privé Systems Group",
    description: "Privately held multi-product technology group building scalable AI-driven platforms.",
    website: "https://privesystems.com",
    repos: ["cyprian-hash/prive-systems"],
    hosting: ["vercel"],
    status: "live",
    color: "#A8A29E", // stone-gray umbrella accent (derived from #0A0A0A ink / #F5F5F4 paper)
    colorAlt: "#F5F5F4",
    tags: ["umbrella", "holding"],
    email: "hub@privesystems.com",
    emailProvider: "hostinger",
    notes: "Brand: Ink (#0A0A0A) on Paper (#F5F5F4). Stone-gray used in AEGIS for visibility on dark background.",
  },
  {
    id: "my-central-domains",
    name: "My Central Domains",
    description: "Unified domain portfolio infrastructure across Web2 and Web3 environments.",
    website: "https://mycentral.domains",
    repos: ["cyprian-hash/v0-mycentral-domains-app", "cyprian-hash/mycentraldomains-ios"],
    hosting: ["vercel"],
    ios: { bundleId: "com.mycentraldomains.app", verified: true },
    status: "live",
    color: "#285ED2", // --color-central-blue
    tags: ["domains", "web3", "ios"],
    email: "hello@mycentral.domains",
    emailProvider: "hostinger",
  },
  {
    id: "aura",
    name: "Aura",
    description: "AI-driven automation and intelligent concierge systems.",
    website: "https://auraos.vip/",
    repos: ["cyprian-hash/aura-prive", "cyprian-hash/gravityclaw"],
    hosting: ["vercel"],
    status: "live",
    color: "#EDBB2F", // --color-aura-accent
    tags: ["ai", "concierge", "automation"],
    email: "hello@auraos.vip",
    emailProvider: "hostinger",
  },
  {
    id: "vault-legacy",
    name: "Vault Legacy",
    description: "Secure digital asset and legacy management platform.",
    website: "https://vaultlegacy.io/",
    repos: ["cyprian-hash/vault-legacy"],
    hosting: ["vercel"],
    status: "live",
    color: "#10B981", // --color-vault-green
    tags: ["legacy", "estate", "security"],
  },
  {
    id: "jetvan-vip",
    name: "Jet Van VIP",
    description: "Exclusive ground transportation network and bespoke logistics.",
    website: "https://jetvan.vip/",
    repos: ["cyprian-hash/jetvan-vip-luxury-transport"],
    hosting: ["vercel"],
    status: "live",
    color: "#F59E0B", // --color-jetvan-accent
    tags: ["luxury", "transport"],
    email: "hello@jetvan.vip",
    emailProvider: "google-workspace",
  },
  {
    id: "api-monitor",
    name: "API Monitor",
    description: "Real-time aggregation and cost-analysis for AI and Cloud APIs.",
    website: "https://apimonitor.ai/",
    repos: [],
    hosting: ["vercel", "supabase"],
    status: "live",
    color: "#00E888", // --color-apimonitor-accent
    tags: ["devops", "monitoring", "cost"],
    email: "ping@apimonitor.ai",
    emailProvider: "hostinger",
    notes: "GitHub repo not yet created.",
  },
  {
    id: "netty-banks",
    name: "Netty Banks",
    description: "AI personal assistant engineered for dynamic task delegation.",
    website: "http://netty.pro/",
    repos: [],
    hosting: ["vercel"],
    status: "live",
    color: "#A855F7", // --color-netty-accent
    tags: ["ai", "assistant"],
    email: "hello@netty.pro",
    emailProvider: "hostinger",
    notes: "GitHub repo not yet created.",
  },
  {
    id: "jetpedia",
    name: "Jetpedia",
    description: "Private aviation intelligence and dynamic fleet forecasting.",
    website: "https://jetpedia.io/",
    repos: ["cyprian-hash/jetpedia-app", "cyprian-hash/jetpedia-ios"],
    hosting: ["vercel"],
    ios: { bundleId: "io.jetpedia.app", verified: true },
    status: "live",
    color: "#3B82F6", // --color-jetpedia-accent
    tags: ["aviation", "intelligence", "ios"],
    email: "fly@jetpedia.io",
    emailProvider: "hostinger",
  },
  {
    id: "yachtpedia",
    name: "Yachtpedia",
    description: "Transparency and tracking for the global superyacht market.",
    website: "https://yachtpedia.io/",
    repos: [],
    hosting: ["vercel"],
    status: "building",
    color: "#0088CC", // --color-yachtpedia-accent
    tags: ["yachts", "intelligence"],
    email: "helm@yachtpedia.io",
    emailProvider: "hostinger",
    notes: "Deploying May 2026.",
  },
  {
    id: "autopedia",
    name: "Autopedia",
    description: "System of record for provenance and hypercar asset integrity.",
    website: "https://autopedia.io/",
    repos: [],
    hosting: ["vercel"],
    status: "idea",
    color: "#15803D", // --color-autopedia-accent
    tags: ["automotive", "provenance"],
    emailProvider: "none",
    notes: "Target deploy: July 2026.",
  },
  {
    id: "memory-soundx",
    name: "Memory SoundX",
    description: "Cognitive audio enhancement and personalized algorithmic soundscapes.",
    website: "https://memorysoundx.com/",
    repos: ["cyprian-hash/memory-soundx"],
    hosting: ["vercel"],
    ios: { bundleId: "com.memorysoundx.app", verified: false },
    status: "live",
    color: "#A855F7", // single anchor color (purple) from the multi-stop brand gradient
    tags: ["audio", "cognitive", "ios"],
    email: "play@memorysoundx.com",
    emailProvider: "hostinger",
    notes: "Brand uses a multi-stop gradient (#285ED2 → #10B981 → #EDBB2F → #A855F7 → #F59E0B). Anchor purple chosen for UI fidelity. iOS bundle ID inferred — verify before relying on it.",
  },
  {
    id: "netty-banks-agent",
    name: "Netty",
    description: "AI personal assistant — GravityClaw agent on Telegram, edited in Antigravity, auto-deployed to Hostinger VPS.",
    website: "https://t.me/nettybanks",
    repos: ["cyprian-hash/gravityclaw"],
    hosting: ["other"],
    status: "live",
    color: "#C084FC", // lighter purple than Netty Banks (the app, #A855F7) to differentiate
    tags: ["agent", "telegram", "personal", "gravityclaw"],
    notes: "Telegram: @nettybanks (chat id 8035083053). Runs on Hostinger VPS with auto-deploy from main branch of cyprian-hash/gravityclaw. Edit via Antigravity, push to GitHub, VPS pulls automatically.\n\nNetty observes the AEGIS Obsidian vault and can act on what other agents wrote. Chat happens in Telegram, not AEGIS.",
  },
];

export function slugify(s: string): string {
  return s.toLowerCase().replace(/[^a-z0-9-]+/g, "-").replace(/^-+|-+$/g, "");
}
