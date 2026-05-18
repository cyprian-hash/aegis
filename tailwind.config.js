/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./app/**/*.{js,ts,jsx,tsx,mdx}",
    "./components/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      fontFamily: {
        mono: ["JetBrains Mono", "ui-monospace", "SFMono-Regular", "monospace"],
        display: ["Space Grotesk", "ui-sans-serif", "system-ui"],
      },
      colors: {
        phosphor: {
          50:  "#fff7d6",
          100: "#ffeba3",
          200: "#ffdc70",
          300: "#f5b400",
          400: "#e0a300",
          500: "#b78400",
        },
      },
      keyframes: {
        scan: { "0%": { top: "-2%" }, "100%": { top: "102%" } },
        pulse2: { "0%,100%": { opacity: 1 }, "50%": { opacity: 0.3 } },
      },
      animation: {
        scan: "scan 8s linear infinite",
        pulse2: "pulse2 1.6s ease-in-out infinite",
      },
    },
  },
  plugins: [],
};
