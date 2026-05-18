"use client";
import { useEffect, useState } from "react";
import { motion } from "framer-motion";

export default function Waveform() {
  const bars = 56;
  const [seeds, setSeeds] = useState<number[]>([]);
  useEffect(() => {
    setSeeds(Array.from({ length: bars }, () => Math.random()));
  }, []);
  return (
    <div className="flex items-end gap-[3px] h-12">
      {Array.from({ length: bars }).map((_, i) => {
        const s = seeds[i] ?? 0.5;
        return (
          <motion.span key={i}
            className="w-[3px] rounded-full bg-amber-400/70"
            animate={{
              height: [
                `${10 + s * 60}%`,
                `${10 + ((s * 7) % 1) * 90}%`,
                `${10 + ((s * 13) % 1) * 40}%`,
              ],
            }}
            transition={{ duration: 1 + (i % 6) * 0.15, repeat: Infinity, ease: "easeInOut", delay: i * 0.02 }}
          />
        );
      })}
    </div>
  );
}
