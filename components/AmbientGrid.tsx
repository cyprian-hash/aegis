"use client";
import { motion } from "framer-motion";

export default function AmbientGrid() {
  return (
    <div className="pointer-events-none fixed inset-0 overflow-hidden z-0">
      {/* base radial glow */}
      <div className="absolute inset-0" style={{
        background:
          "radial-gradient(ellipse 90% 70% at 50% -10%, rgba(245,180,0,0.10), transparent 55%), radial-gradient(ellipse 70% 60% at 90% 110%, rgba(34,211,238,0.07), transparent 60%), radial-gradient(ellipse 60% 50% at 10% 100%, rgba(167,139,250,0.05), transparent 60%)",
      }} />

      {/* soft grid */}
      <div className="absolute inset-0 opacity-[0.07]" style={{
        backgroundImage:
          "linear-gradient(rgba(255,255,255,0.4) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.4) 1px, transparent 1px)",
        backgroundSize: "64px 64px",
        maskImage: "radial-gradient(ellipse 90% 80% at 50% 40%, black 30%, transparent 80%)",
      }} />

      {/* slow scanline */}
      <motion.div
        className="absolute left-0 right-0 h-px"
        style={{ background: "linear-gradient(90deg, transparent, rgba(245,180,0,0.4), transparent)" }}
        initial={{ top: "-2%" }}
        animate={{ top: "102%" }}
        transition={{ duration: 14, repeat: Infinity, ease: "linear" }}
      />

      {/* floating orbs */}
      <motion.div
        className="absolute h-[400px] w-[400px] rounded-full opacity-[0.06]"
        style={{ background: "radial-gradient(circle, #f5b400, transparent 70%)", filter: "blur(60px)" }}
        animate={{ x: ["10%", "60%", "10%"], y: ["20%", "70%", "20%"] }}
        transition={{ duration: 30, repeat: Infinity, ease: "easeInOut" }}
      />
      <motion.div
        className="absolute h-[300px] w-[300px] rounded-full opacity-[0.05]"
        style={{ background: "radial-gradient(circle, #22d3ee, transparent 70%)", filter: "blur(60px)" }}
        animate={{ x: ["70%", "20%", "70%"], y: ["60%", "20%", "60%"] }}
        transition={{ duration: 26, repeat: Infinity, ease: "easeInOut" }}
      />

      {/* film grain */}
      <div className="absolute inset-0 opacity-[0.035] mix-blend-overlay" style={{
        backgroundImage:
          "url(\"data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='160' height='160'><filter id='n'><feTurbulence type='fractalNoise' baseFrequency='0.9' numOctaves='2'/></filter><rect width='100%25' height='100%25' filter='url(%23n)' opacity='0.6'/></svg>\")",
      }} />
    </div>
  );
}
