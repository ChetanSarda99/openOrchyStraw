"use client";

import { ReactNode } from "react";

/**
 * Infinite logo strip with edge-fade mask. Pure CSS.
 */
export function LogoMarquee({
  items,
  speed = 30,
  className = "",
}: {
  items: ReactNode[];
  speed?: number;
  className?: string;
}) {
  const doubled = [...items, ...items];
  return (
    <div
      className={className}
      style={{
        position: "relative",
        overflow: "hidden",
        maskImage:
          "linear-gradient(to right, transparent, black 12%, black 88%, transparent)",
        WebkitMaskImage:
          "linear-gradient(to right, transparent, black 12%, black 88%, transparent)",
      }}
    >
      <style>{`
        @keyframes logo-marquee {
          from { transform: translate3d(0, 0, 0); }
          to   { transform: translate3d(-50%, 0, 0); }
        }
      `}</style>
      <div
        style={{
          display: "flex",
          gap: "3rem",
          width: "max-content",
          animation: `logo-marquee ${speed}s linear infinite`,
          willChange: "transform",
        }}
      >
        {doubled.map((it, i) => (
          <div
            key={i}
            style={{
              flexShrink: 0,
              opacity: 0.65,
              display: "flex",
              alignItems: "center",
              gap: "0.5rem",
            }}
          >
            {it}
          </div>
        ))}
      </div>
    </div>
  );
}
