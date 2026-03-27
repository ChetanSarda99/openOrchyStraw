"use client";

import { useRef, useEffect, useState } from "react";
import { motion } from "framer-motion";

export function PixelDemo() {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const cleanupRef = useRef<(() => void) | null>(null);
  const [loaded, setLoaded] = useState(false);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const script = document.createElement("script");
    script.src = "/demo-embed.js";
    script.onload = () => {
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const PixelDemo = (window as any).PixelDemo;
      if (PixelDemo && canvas) {
        cleanupRef.current = PixelDemo.start(canvas);
        setLoaded(true);
      }
    };
    document.head.appendChild(script);

    return () => {
      cleanupRef.current?.();
      script.remove();
    };
  }, []);

  return (
    <section className="px-4 py-16 sm:px-6 sm:py-24">
      <div className="mx-auto max-w-5xl">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.5 }}
          className="text-center"
        >
          <h2 className="text-3xl font-bold tracking-tight sm:text-4xl">
            Watch your agents work
          </h2>
          <p className="mt-4 text-lg text-muted">
            Real-time pixel art visualization of your agent team in action.
          </p>
        </motion.div>

        <motion.div
          initial={{ opacity: 0, y: 30 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.5, delay: 0.2 }}
          className="mt-12 flex justify-center"
        >
          <div className="overflow-hidden rounded-xl border border-card-border bg-card shadow-2xl">
            <div className="flex items-center gap-2 border-b border-card-border px-4 py-3">
              <div className="h-3 w-3 rounded-full bg-mac-red" />
              <div className="h-3 w-3 rounded-full bg-mac-yellow" />
              <div className="h-3 w-3 rounded-full bg-mac-green" />
              <span className="ml-2 text-xs text-muted font-mono">
                pixel-agents
              </span>
            </div>
            <canvas
              ref={canvasRef}
              width={800}
              height={480}
              className={`block max-w-full transition-opacity duration-500 ${loaded ? "opacity-100" : "opacity-0"}`}
              style={{ imageRendering: "pixelated" }}
            />
          </div>
        </motion.div>
      </div>
    </section>
  );
}
