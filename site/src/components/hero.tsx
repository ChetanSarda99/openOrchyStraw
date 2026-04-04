"use client";

import { motion, useScroll, useTransform, useSpring } from "framer-motion";
import { useRef, useState, useEffect } from "react";
import { Github } from "lucide-react";

const terminalLines = [
  { text: "$ ./auto-agent.sh --cycles 3", type: "command" as const },
  { text: "", type: "blank" as const },
  { text: "── OrchyStraw v0.2.0 ──────────────────────", type: "dim" as const },
  { text: "✓ Loaded 9 agents from agents.conf", type: "success" as const },
  { text: "✓ Worktree isolation enabled", type: "success" as const },
  { text: "✓ Smart routing: Claude Opus → backend, Sonnet → docs", type: "success" as const },
  { text: "", type: "blank" as const },
  { text: "── Cycle 1 / 3 ────────────────────────────", type: "dim" as const },
  { text: "→ 02-cto          reviewing architecture decisions...", type: "agent" as const },
  { text: "→ 06-backend      hardening orchestrator modules...", type: "agent" as const },
  { text: "→ 09-qa           running 278 tests across 26 suites...", type: "agent" as const },
  { text: "→ 10-security     scanning for credential leaks...", type: "agent" as const },
  { text: "→ 11-web          building landing page...", type: "agent" as const },
  { text: "", type: "blank" as const },
  { text: "── Cycle 1 complete ────────────────────────", type: "dim" as const },
  { text: "✓ 5 agents ran  · 23 files changed  · 0 conflicts", type: "result" as const },
  { text: "✓ QA gate passed · Security gate passed", type: "result" as const },
  { text: "  Cost: $0.42  · Tokens: 84k in / 12k out", type: "cost" as const },
];

function useTypewriter(lines: typeof terminalLines, speed = 35) {
  const [visibleLines, setVisibleLines] = useState<{ text: string; type: string }[]>([]);
  const [started, setStarted] = useState(false);

  useEffect(() => {
    if (!started) return;

    let lineIdx = 0;
    let charIdx = 0;
    let currentLines: { text: string; type: string }[] = [];

    const interval = setInterval(() => {
      if (lineIdx >= lines.length) {
        clearInterval(interval);
        return;
      }

      const currentLine = lines[lineIdx];

      if (currentLine.type === "blank") {
        currentLines = [...currentLines, { text: "", type: "blank" }];
        setVisibleLines([...currentLines]);
        lineIdx++;
        charIdx = 0;
        return;
      }

      if (charIdx === 0) {
        currentLines = [...currentLines, { text: "", type: currentLine.type }];
      }

      charIdx++;
      const partialText = currentLine.text.slice(0, charIdx);
      currentLines[currentLines.length - 1] = { text: partialText, type: currentLine.type };
      setVisibleLines([...currentLines]);

      if (charIdx >= currentLine.text.length) {
        lineIdx++;
        charIdx = 0;
      }
    }, speed);

    return () => clearInterval(interval);
  }, [started, lines, speed]);

  return { visibleLines, start: () => setStarted(true), started };
}

function TerminalDemo() {
  const { visibleLines, start, started } = useTypewriter(terminalLines, 18);
  const ref = useRef<HTMLDivElement>(null);

  return (
    <motion.div
      ref={ref}
      variants={{
        hidden: { opacity: 0, y: 24 },
        visible: { opacity: 1, y: 0 },
      }}
      initial="hidden"
      whileInView="visible"
      viewport={{ once: true, margin: "-50px" }}
      transition={{
        duration: 0.5,
        ease: [0.21, 0.47, 0.32, 0.98],
      }}
      onAnimationComplete={() => {
        if (!started) start();
      }}
      className="w-full max-w-2xl"
    >
      <div className="overflow-hidden rounded-xl border border-card-border" style={{ background: "hsl(0 0% 6%)" }}>
        <div className="flex items-center gap-2 border-b border-card-border px-4 py-3">
          <div className="h-3 w-3 rounded-full" style={{ background: "#ff5f57" }} />
          <div className="h-3 w-3 rounded-full" style={{ background: "#febc2e" }} />
          <div className="h-3 w-3 rounded-full" style={{ background: "#28c840" }} />
          <span className="ml-2 font-mono text-text-tertiary" style={{ fontSize: "var(--font-size-micro)" }}>
            ~/project
          </span>
        </div>
        <div className="overflow-x-auto p-4 font-mono leading-relaxed sm:p-5" style={{ fontSize: "var(--font-size-micro)", minHeight: "360px" }}>
          {visibleLines.map((line, i) => (
            <div key={i} className={
              line.type === "blank" ? "h-4" :
              line.type === "command" ? "text-foreground font-medium" :
              line.type === "dim" ? "text-text-quaternary" :
              line.type === "success" ? "text-accent" :
              line.type === "agent" ? "text-text-secondary" :
              line.type === "result" ? "text-accent" :
              line.type === "cost" ? "text-text-tertiary" :
              "text-text-secondary"
            }>
              {line.text}
            </div>
          ))}
          {visibleLines.length > 0 && visibleLines.length < terminalLines.length && (
            <span className="inline-block w-2 h-4 bg-accent/80 animate-pulse" />
          )}
          {visibleLines.length >= terminalLines.length && (
            <div className="mt-2 text-foreground font-medium">
              $ <span className="inline-block w-2 h-4 bg-text-tertiary/60" />
            </div>
          )}
        </div>
      </div>
    </motion.div>
  );
}

export function Hero() {
  const ref = useRef(null);
  const { scrollYProgress } = useScroll({
    target: ref,
    offset: ["start start", "end start"],
  });

  const rawY = useTransform(scrollYProgress, [0, 1], [0, -120]);
  const y = useSpring(rawY, { stiffness: 400, damping: 90 });
  const opacity = useTransform(scrollYProgress, [0, 0.5], [1, 0]);

  return (
    <section ref={ref} className="relative overflow-hidden" style={{ minHeight: "100vh" }}>
      <div className="hero-glow pointer-events-none absolute inset-0 -z-10" />

      <motion.div
        style={{ y, opacity }}
        className="relative z-10 flex flex-col items-center px-4 pt-24 pb-20 sm:px-6 sm:pt-36 sm:pb-28"
      >
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ duration: 0.8, delay: 0.1 }}
          className="mb-8 inline-flex items-center gap-2 rounded-full border border-card-border px-4 py-1.5 font-mono text-text-tertiary"
          style={{ fontSize: "var(--font-size-micro)" }}
        >
          <span className="inline-block h-1.5 w-1.5 rounded-full bg-accent" />
          v0.2.0 — 22 modules, 278 tests passing
        </motion.div>

        <h1
          className="hero-gradient max-w-4xl text-center font-medium"
          style={{
            fontSize: "var(--font-size-hero)",
            lineHeight: 1.1,
            letterSpacing: "-0.02em",
            textWrap: "balance",
          }}
        >
          Multi-agent orchestration in&nbsp;pure&nbsp;bash
        </h1>

        <p
          className="mx-auto mt-6 max-w-xl text-center text-text-secondary"
          style={{
            fontSize: "var(--font-size-body)",
            lineHeight: 1.6,
          }}
        >
          Run 9 AI coding agents on your codebase with file ownership,
          quality gates, and cost tracking. No framework. No dependencies.
          Just a shell script.
        </p>

        <div className="mt-10 flex items-center gap-4">
          <a
            href="https://github.com/ChetanSarda99/openOrchyStraw"
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-2 rounded-lg bg-accent px-5 py-2.5 font-medium tracking-tight text-accent-foreground transition-colors hover:bg-accent/90"
            style={{ fontSize: "var(--font-size-small)" }}
          >
            Start building
          </a>
          <a
            href="https://github.com/ChetanSarda99/openOrchyStraw"
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-2 rounded-lg border border-card-border px-5 py-2.5 font-medium tracking-tight text-text-secondary transition-colors hover:border-card-border-hover hover:text-foreground"
            style={{ fontSize: "var(--font-size-small)" }}
          >
            <Github className="h-4 w-4" />
            View source
          </a>
        </div>

        <div className="mt-14 sm:mt-20">
          <TerminalDemo />
        </div>
      </motion.div>
    </section>
  );
}
