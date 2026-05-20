"use client";

import { useEffect, useRef } from "react";

/**
 * Page-level cursor-follow radial spotlight.
 * Spring-smoothed (lerp) so it lags slightly behind the cursor  -  that's
 * the "premium feel" trick eden.so uses.
 */
export function CursorSpotlight({
  size = 520,
  color = "rgba(139, 92, 246, 0.18)",
  lerp = 0.12,
}: {
  size?: number;
  color?: string;
  lerp?: number;
}) {
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (typeof window === "undefined") return;
    if (window.matchMedia("(pointer: coarse)").matches) return;
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;

    const el = ref.current;
    if (!el) return;

    let tx = window.innerWidth / 2;
    let ty = window.innerHeight / 2;
    let x = tx;
    let y = ty;
    let raf = 0;

    function onMove(e: MouseEvent) {
      tx = e.clientX;
      ty = e.clientY;
    }

    function tick() {
      x += (tx - x) * lerp;
      y += (ty - y) * lerp;
      if (el) el.style.transform = `translate3d(${x - size / 2}px, ${y - size / 2}px, 0)`;
      raf = requestAnimationFrame(tick);
    }

    window.addEventListener("mousemove", onMove, { passive: true });
    raf = requestAnimationFrame(tick);

    return () => {
      window.removeEventListener("mousemove", onMove);
      cancelAnimationFrame(raf);
    };
  }, [size, lerp]);

  return (
    <div
      ref={ref}
      aria-hidden
      style={{
        position: "fixed",
        top: 0,
        left: 0,
        width: size,
        height: size,
        borderRadius: "50%",
        background: `radial-gradient(circle, ${color} 0%, transparent 60%)`,
        pointerEvents: "none",
        zIndex: 1,
        mixBlendMode: "screen",
        willChange: "transform",
      }}
    />
  );
}
