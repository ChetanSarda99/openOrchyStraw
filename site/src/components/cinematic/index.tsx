"use client";

/**
 * Cinematic  -  shared React animation primitives.
 *
 * No deps beyond React 18+. Uses IntersectionObserver + CSS transitions
 * for ~2kb of code instead of pulling in Framer Motion / GSAP.
 *
 * Cross-project home: ~/Projects/shared/components/cinematic/
 * Consumers: AIVA, Klaro, openOrchyStraw, companion-platform
 */

import * as React from "react";
import {
  CSSProperties,
  PropsWithChildren,
  ReactNode,
  useEffect,
  useRef,
  useState,
} from "react";

// ─────────────────────────────────────────────────────────────────
// useInView  -  single observer, fires once
// ─────────────────────────────────────────────────────────────────

export function useInView<T extends Element = HTMLDivElement>(
  options: IntersectionObserverInit = { threshold: 0.05, rootMargin: "200px 0px" }
): [React.RefObject<T | null>, boolean] {
  const ref = useRef<T>(null);
  const [inView, setInView] = useState(false);

  useEffect(() => {
    if (typeof IntersectionObserver === "undefined") {
      setInView(true);
      return;
    }
    const el = ref.current;
    if (!el) return;
    const obs = new IntersectionObserver(([entry]) => {
      if (entry.isIntersecting) {
        setInView(true);
        obs.disconnect();
      }
    }, options);
    obs.observe(el);
    // Belt-and-braces: if for any reason the observer hasn't fired after
    // 1.5s (slow scrollers, mobile Safari quirks, prerender for OG/SEO
    // bots, screenshot tools), reveal anyway. Avoids the "huge dead zone
    // mid-page" bug where content sits at opacity:0 forever.
    const fallback = window.setTimeout(() => setInView(true), 1500);
    return () => {
      obs.disconnect();
      window.clearTimeout(fallback);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return [ref, inView];
}

// ─────────────────────────────────────────────────────────────────
// ScrollReveal  -  fade/slide/scale on first visibility
// ─────────────────────────────────────────────────────────────────

type Direction = "up" | "down" | "left" | "right" | "scale" | "none";

export function ScrollReveal({
  children,
  direction = "up",
  delay = 0,
  duration = 600,
  distance = 24,
  className = "",
  as: Tag = "div",
}: PropsWithChildren<{
  direction?: Direction;
  delay?: number;
  duration?: number;
  distance?: number;
  className?: string;
  as?: keyof React.JSX.IntrinsicElements;
}>) {
  const [ref, inView] = useInView<HTMLDivElement>();

  const transforms: Record<Direction, string> = {
    up: `translate3d(0, ${distance}px, 0)`,
    down: `translate3d(0, -${distance}px, 0)`,
    left: `translate3d(${distance}px, 0, 0)`,
    right: `translate3d(-${distance}px, 0, 0)`,
    scale: "scale(0.92)",
    none: "none",
  };

  const style: CSSProperties = {
    opacity: inView ? 1 : 0,
    transform: inView ? "none" : transforms[direction],
    transition: `opacity ${duration}ms ease-out ${delay}ms, transform ${duration}ms cubic-bezier(0.2, 0.8, 0.2, 1) ${delay}ms`,
    willChange: "opacity, transform",
  };

  return React.createElement(
    Tag,
    { ref, className, style },
    children
  );
}

// ─────────────────────────────────────────────────────────────────
// StaggerGrid  -  reveal children in sequence
// ─────────────────────────────────────────────────────────────────

export function StaggerGrid({
  children,
  stagger = 80,
  direction = "up",
  className = "",
}: PropsWithChildren<{
  stagger?: number;
  direction?: Direction;
  className?: string;
}>) {
  const items = React.Children.toArray(children);
  return (
    <div className={className}>
      {items.map((child, i) => (
        <ScrollReveal key={i} direction={direction} delay={i * stagger}>
          {child as ReactNode}
        </ScrollReveal>
      ))}
    </div>
  );
}

// ─────────────────────────────────────────────────────────────────
// FloatingElements  -  orbit/float items around a center
// ─────────────────────────────────────────────────────────────────

export function FloatingElements({
  items,
  radius = 140,
  duration = 24,
  size = 320,
  className = "",
}: {
  items: ReactNode[];
  radius?: number;
  duration?: number;
  size?: number;
  className?: string;
}) {
  return (
    <div
      className={`relative ${className}`}
      style={{ width: size, height: size }}
    >
      <style>{`
        @keyframes cinematic-orbit {
          from { transform: rotate(0deg) translateX(var(--r)) rotate(0deg); }
          to   { transform: rotate(360deg) translateX(var(--r)) rotate(-360deg); }
        }
        @keyframes cinematic-float {
          0%, 100% { transform: translateY(0); }
          50% { transform: translateY(-8px); }
        }
      `}</style>
      {items.map((item, i) => {
        const angle = (i / items.length) * 360;
        const offset = (i * 1.3) % duration;
        return (
          <div
            key={i}
            style={{
              position: "absolute",
              top: "50%",
              left: "50%",
              marginLeft: -16,
              marginTop: -16,
              ["--r" as string]: `${radius}px`,
              animation: `cinematic-orbit ${duration}s linear infinite`,
              animationDelay: `-${offset}s`,
              transform: `rotate(${angle}deg) translateX(${radius}px)`,
            }}
          >
            <div style={{ animation: "cinematic-float 4s ease-in-out infinite" }}>
              {item}
            </div>
          </div>
        );
      })}
    </div>
  );
}

// ─────────────────────────────────────────────────────────────────
// GlowCard  -  radial glow follows the cursor
// ─────────────────────────────────────────────────────────────────

export function GlowCard({
  children,
  className = "",
  glowColor = "rgba(139, 92, 246, 0.18)",
  ...rest
}: PropsWithChildren<{
  className?: string;
  glowColor?: string;
}> &
  React.HTMLAttributes<HTMLDivElement>) {
  const ref = useRef<HTMLDivElement>(null);
  function onMove(e: React.MouseEvent<HTMLDivElement>) {
    const el = ref.current;
    if (!el) return;
    const rect = el.getBoundingClientRect();
    el.style.setProperty("--mx", `${e.clientX - rect.left}px`);
    el.style.setProperty("--my", `${e.clientY - rect.top}px`);
  }
  return (
    <div
      ref={ref}
      onMouseMove={onMove}
      className={className}
      style={{
        position: "relative",
        background: `radial-gradient(600px circle at var(--mx, 50%) var(--my, 50%), ${glowColor}, transparent 40%)`,
        ...((rest.style as CSSProperties) || {}),
      }}
      {...rest}
    >
      {children}
    </div>
  );
}

// ─────────────────────────────────────────────────────────────────
// MagneticButton  -  pulls toward the cursor when hovered
// ─────────────────────────────────────────────────────────────────

export function MagneticButton({
  children,
  strength = 0.3,
  className = "",
  ...rest
}: PropsWithChildren<{ strength?: number; className?: string }> &
  React.ButtonHTMLAttributes<HTMLButtonElement>) {
  const ref = useRef<HTMLButtonElement>(null);
  function onMove(e: React.MouseEvent<HTMLButtonElement>) {
    const el = ref.current;
    if (!el) return;
    const rect = el.getBoundingClientRect();
    const x = (e.clientX - rect.left - rect.width / 2) * strength;
    const y = (e.clientY - rect.top - rect.height / 2) * strength;
    el.style.transform = `translate(${x}px, ${y}px)`;
  }
  function onLeave() {
    if (ref.current) ref.current.style.transform = "translate(0,0)";
  }
  return (
    <button
      ref={ref}
      onMouseMove={onMove}
      onMouseLeave={onLeave}
      className={className}
      style={{ transition: "transform 200ms cubic-bezier(0.2, 0.8, 0.2, 1)" }}
      {...rest}
    >
      {children}
    </button>
  );
}

// ─────────────────────────────────────────────────────────────────
// TextReveal  -  animate words or characters in sequence
// ─────────────────────────────────────────────────────────────────

export function TextReveal({
  text,
  by = "word",
  stagger = 40,
  className = "",
}: {
  text: string;
  by?: "word" | "char";
  stagger?: number;
  className?: string;
}) {
  const [ref, inView] = useInView<HTMLSpanElement>();
  const parts = by === "word" ? text.split(/(\s+)/) : Array.from(text);

  return (
    <span ref={ref} className={className}>
      {parts.map((p, i) => {
        if (p.match(/^\s+$/)) return p;
        return (
          <span
            key={i}
            style={{
              display: "inline-block",
              opacity: inView ? 1 : 0,
              transform: inView ? "translateY(0)" : "translateY(0.4em)",
              transition: `opacity 600ms ease-out ${i * stagger}ms, transform 600ms cubic-bezier(0.2, 0.8, 0.2, 1) ${i * stagger}ms`,
              willChange: "opacity, transform",
            }}
          >
            {p}
          </span>
        );
      })}
    </span>
  );
}

// ─────────────────────────────────────────────────────────────────
// CountUp  -  animate from 0 to `to` once visible
// ─────────────────────────────────────────────────────────────────

export function CountUp({
  to,
  duration = 1600,
  prefix = "",
  suffix = "",
  className = "",
}: {
  to: number;
  duration?: number;
  prefix?: string;
  suffix?: string;
  className?: string;
}) {
  const [ref, inView] = useInView<HTMLSpanElement>();
  const [val, setVal] = useState(0);

  useEffect(() => {
    if (!inView) return;
    let raf = 0;
    const start = performance.now();
    const tick = (now: number) => {
      const t = Math.min(1, (now - start) / duration);
      // ease-out cubic
      const eased = 1 - Math.pow(1 - t, 3);
      setVal(Math.round(to * eased));
      if (t < 1) raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [inView, to, duration]);

  return (
    <span ref={ref} className={className}>
      {prefix}
      {val.toLocaleString()}
      {suffix}
    </span>
  );
}

// ─────────────────────────────────────────────────────────────────
// ProgressScroll  -  top-of-page scroll progress bar
// ─────────────────────────────────────────────────────────────────

export function ProgressScroll({
  height = 3,
  color = "rgb(139, 92, 246)",
  className = "",
}: {
  height?: number;
  color?: string;
  className?: string;
}) {
  const [pct, setPct] = useState(0);
  useEffect(() => {
    function onScroll() {
      const doc = document.documentElement;
      const total = doc.scrollHeight - doc.clientHeight;
      setPct(total > 0 ? (doc.scrollTop / total) * 100 : 0);
    }
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  return (
    <div
      className={className}
      style={{
        position: "fixed",
        top: 0,
        left: 0,
        right: 0,
        height,
        background: "transparent",
        zIndex: 60,
        pointerEvents: "none",
      }}
    >
      <div
        style={{
          height: "100%",
          width: `${pct}%`,
          background: color,
          transition: "width 80ms linear",
        }}
      />
    </div>
  );
}

// ─────────────────────────────────────────────────────────────────
// ParallaxHero  -  layered parallax full-screen hero
// ─────────────────────────────────────────────────────────────────

export function ParallaxHero({
  layers,
  className = "",
  minHeight = "100vh",
}: {
  layers: { content: ReactNode; speed?: number; className?: string }[];
  className?: string;
  minHeight?: string;
}) {
  const ref = useRef<HTMLDivElement>(null);
  const [y, setY] = useState(0);
  useEffect(() => {
    function onScroll() {
      if (!ref.current) return;
      const rect = ref.current.getBoundingClientRect();
      setY(-rect.top);
    }
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  return (
    <div
      ref={ref}
      className={className}
      style={{ position: "relative", overflow: "hidden", minHeight }}
    >
      {layers.map((layer, i) => (
        <div
          key={i}
          className={layer.className}
          style={{
            position: "absolute",
            inset: 0,
            transform: `translate3d(0, ${y * (layer.speed ?? 0.2)}px, 0)`,
            willChange: "transform",
          }}
        >
          {layer.content}
        </div>
      ))}
    </div>
  );
}

// ─────────────────────────────────────────────────────────────────
// HorizontalScroll  -  pin section, translate horizontally on scroll
// ─────────────────────────────────────────────────────────────────

export function HorizontalScroll({
  children,
  className = "",
}: PropsWithChildren<{ className?: string }>) {
  const wrapRef = useRef<HTMLDivElement>(null);
  const innerRef = useRef<HTMLDivElement>(null);
  const [translate, setTranslate] = useState(0);

  useEffect(() => {
    function onScroll() {
      const wrap = wrapRef.current;
      const inner = innerRef.current;
      if (!wrap || !inner) return;
      const rect = wrap.getBoundingClientRect();
      const total = wrap.offsetHeight - window.innerHeight;
      const progress = Math.min(1, Math.max(0, -rect.top / Math.max(1, total)));
      const max = inner.scrollWidth - window.innerWidth;
      setTranslate(-progress * Math.max(0, max));
    }
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  return (
    <div ref={wrapRef} className={className} style={{ height: "300vh", position: "relative" }}>
      <div
        style={{
          position: "sticky",
          top: 0,
          height: "100vh",
          overflow: "hidden",
          display: "flex",
          alignItems: "center",
        }}
      >
        <div
          ref={innerRef}
          style={{
            display: "flex",
            transform: `translate3d(${translate}px, 0, 0)`,
            willChange: "transform",
          }}
        >
          {children}
        </div>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────────
// SmoothScroll  -  opt-in smoother scrolling without Lenis
// ─────────────────────────────────────────────────────────────────
// Just toggles `scroll-behavior: smooth` on <html>. For physics-based
// inertia (Lenis-style), consumers can wrap with their own.

export function SmoothScroll({ children }: PropsWithChildren<{}>) {
  useEffect(() => {
    const prev = document.documentElement.style.scrollBehavior;
    document.documentElement.style.scrollBehavior = "smooth";
    return () => {
      document.documentElement.style.scrollBehavior = prev;
    };
  }, []);
  return <>{children}</>;
}
