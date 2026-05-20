"use client";

import { ReactNode, useEffect, useRef, useState } from "react";

/**
 * Sticky 100vh section. Total scroll height = steps * 100vh.
 * Active step is driven by the section's progress through the viewport,
 * matching eden.so's canvas-reveal pattern.
 */
export function PinnedSequence({
  steps,
  className = "",
}: {
  steps: { title: string; body: string; visual: ReactNode }[];
  className?: string;
}) {
  const wrapRef = useRef<HTMLDivElement>(null);
  const [active, setActive] = useState(0);
  const [progress, setProgress] = useState(0);

  useEffect(() => {
    function onScroll() {
      const wrap = wrapRef.current;
      if (!wrap) return;
      const rect = wrap.getBoundingClientRect();
      const total = wrap.offsetHeight - window.innerHeight;
      const p = Math.min(1, Math.max(0, -rect.top / Math.max(1, total)));
      setProgress(p);
      const idx = Math.min(steps.length - 1, Math.floor(p * steps.length));
      setActive(idx);
    }
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, [steps.length]);

  return (
    <div
      ref={wrapRef}
      className={className}
      style={{ height: `${steps.length * 100}vh`, position: "relative" }}
    >
      <div
        style={{
          position: "sticky",
          top: 0,
          height: "100vh",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          overflow: "hidden",
        }}
      >
        <div className="grid grid-cols-1 md:grid-cols-2 gap-12 max-w-6xl w-full px-6">
          <div className="flex flex-col justify-center gap-6">
            {steps.map((s, i) => {
              const isActive = i === active;
              return (
                <div
                  key={i}
                  style={{
                    opacity: isActive ? 1 : 0.3,
                    transform: `translateY(${isActive ? 0 : 8}px)`,
                    transition: "opacity 500ms ease, transform 500ms cubic-bezier(0.2,0.8,0.2,1)",
                    borderLeft: `2px solid ${isActive ? "rgb(139,92,246)" : "rgba(255,255,255,0.1)"}`,
                    paddingLeft: "1.25rem",
                  }}
                >
                  <div className="text-xs uppercase tracking-[0.2em] text-foreground/50 mb-2">
                    Step {i + 1}
                  </div>
                  <h3 className="text-2xl md:text-3xl font-semibold mb-2">{s.title}</h3>
                  <p className="text-foreground/70 max-w-md">{s.body}</p>
                </div>
              );
            })}
          </div>
          <div className="relative h-[60vh] md:h-[70vh]">
            {steps.map((s, i) => (
              <div
                key={i}
                style={{
                  position: "absolute",
                  inset: 0,
                  opacity: i === active ? 1 : 0,
                  transform: `scale(${i === active ? 1 : 0.96}) translateY(${i === active ? 0 : 16}px)`,
                  transition:
                    "opacity 600ms ease, transform 600ms cubic-bezier(0.2,0.8,0.2,1)",
                  pointerEvents: i === active ? "auto" : "none",
                }}
              >
                {s.visual}
              </div>
            ))}
          </div>
        </div>
        {/* progress dots */}
        <div
          aria-hidden
          style={{
            position: "absolute",
            right: "1.5rem",
            top: "50%",
            transform: "translateY(-50%)",
            display: "flex",
            flexDirection: "column",
            gap: "0.5rem",
          }}
        >
          {steps.map((_, i) => (
            <div
              key={i}
              style={{
                width: 6,
                height: i === active ? 24 : 6,
                borderRadius: 3,
                background:
                  i === active ? "rgb(139,92,246)" : "rgba(255,255,255,0.18)",
                transition: "all 300ms ease",
              }}
            />
          ))}
        </div>
        {/* hidden progress var for any consumer that wants it */}
        <span style={{ display: "none" }} data-progress={progress} />
      </div>
    </div>
  );
}
