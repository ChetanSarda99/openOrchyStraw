"use client";

import { useInView } from "./index";

/**
 * Wraps a word with a hand-drawn underline SVG that strokes-on-view.
 * Uses Inter italic + a wavy SVG path so we don't need a separate font.
 */
export function ScribbleAccent({
  children,
  color = "rgb(139, 92, 246)",
  className = "",
}: {
  children: React.ReactNode;
  color?: string;
  className?: string;
}) {
  const [ref, inView] = useInView<HTMLSpanElement>();
  return (
    <span
      ref={ref}
      className={className}
      style={{
        position: "relative",
        display: "inline-block",
        fontStyle: "italic",
        whiteSpace: "nowrap",
      }}
    >
      {children}
      <svg
        aria-hidden
        viewBox="0 0 200 12"
        preserveAspectRatio="none"
        style={{
          position: "absolute",
          left: 0,
          right: 0,
          bottom: "-0.15em",
          width: "100%",
          height: "0.5em",
          overflow: "visible",
        }}
      >
        <path
          d="M2 6 Q 50 1, 100 6 T 198 6"
          fill="none"
          stroke={color}
          strokeWidth="3"
          strokeLinecap="round"
          style={{
            strokeDasharray: 220,
            strokeDashoffset: inView ? 0 : 220,
            transition: "stroke-dashoffset 1100ms cubic-bezier(0.2,0.8,0.2,1) 200ms",
          }}
        />
      </svg>
    </span>
  );
}
