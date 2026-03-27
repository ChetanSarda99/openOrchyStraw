"use client";

import { useState, useEffect } from "react";
import { motion } from "framer-motion";
import { Github, Terminal } from "lucide-react";

export function Hero() {
  return (
    <section className="relative flex flex-col items-center justify-center px-4 pt-20 pb-16 text-center sm:px-6 sm:pt-32 sm:pb-24">
      {/* Subtle grid background */}
      <div
        className="pointer-events-none absolute inset-0 opacity-[0.03]"
        style={{
          backgroundImage:
            "linear-gradient(rgba(255,255,255,0.1) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.1) 1px, transparent 1px)",
          backgroundSize: "64px 64px",
        }}
      />

      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.6 }}
        className="relative z-10 max-w-4xl"
      >
        {/* Badge */}
        <div className="mb-8 inline-flex items-center gap-2 rounded-full border border-card-border bg-card px-4 py-1.5 text-sm text-muted">
          <Terminal className="h-3.5 w-3.5" />
          <span className="font-mono">v0.1.0</span>
          <span className="text-card-border">|</span>
          <span>Open Source</span>
        </div>

        {/* Headline */}
        <h1 className="text-3xl font-bold leading-tight tracking-tight sm:text-4xl md:text-5xl lg:text-7xl">
          Run a team of AI coding agents{" "}
          <span className="text-accent">on any codebase</span>
        </h1>

        {/* Subhead */}
        <p className="mx-auto mt-4 max-w-2xl text-base text-muted sm:mt-6 sm:text-lg md:text-xl">
          Markdown prompts + bash script. No framework. No dependencies.
          <br className="hidden sm:block" />
          Works with Claude Code, Codex, Gemini, Aider, Windsurf, Cursor.
        </p>

        {/* CTAs */}
        <div className="mt-10 flex flex-col items-center gap-4 sm:flex-row sm:justify-center">
          <a
            href="https://github.com/ChetanSarda99/openOrchyStraw"
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-2 rounded-lg bg-accent px-6 py-3 text-sm font-semibold text-accent-foreground transition-colors hover:bg-accent/90"
          >
            Get Started
          </a>
          <a
            href="https://github.com/ChetanSarda99/OrchyStraw-Pro"
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-2 rounded-lg border border-card-border bg-card px-6 py-3 text-sm font-semibold text-foreground transition-colors hover:bg-card-border/30"
          >
            <Github className="h-4 w-4" />
            Star on GitHub
          </a>
        </div>
      </motion.div>

      {/* Terminal demo */}
      <motion.div
        initial={{ opacity: 0, y: 30 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.6, delay: 0.3 }}
        className="relative z-10 mt-16 w-full max-w-2xl"
      >
        <TerminalDemo />
      </motion.div>
    </section>
  );
}

const terminalLines = [
  { text: "$ ./auto-agent.sh", type: "command" as const },
  { text: "── OrchyStraw v0.1.0 ──────────────────", type: "divider" as const },
  { text: "✓ Loaded 11 agents from agents.conf", type: "success" as const },
  { text: "✓ Cycle 1 starting...", type: "success" as const },
  { text: "── Running agents ──────────────────────", type: "divider" as const },
  { text: "→ 04-tauri-rust", detail: "building IPC commands...", type: "agent" as const },
  { text: "→ 05-tauri-ui", detail: "scaffolding dashboard...", type: "agent" as const },
  { text: "→ 06-backend", detail: "hardening orchestrator...", type: "agent" as const },
  { text: "→ 07-ios", detail: "building companion app...", type: "agent" as const },
  { text: "── Cycle 1 complete ─────────────────────", type: "divider" as const },
  { text: "✓ 4 agents ran, 12 files changed, 0 conflicts", type: "success" as const },
];

function TerminalDemo() {
  const [visibleLines, setVisibleLines] = useState(0);

  useEffect(() => {
    if (visibleLines >= terminalLines.length) return;

    const line = terminalLines[visibleLines];
    // Command line types slower, dividers fast, agents staggered
    const delay =
      line.type === "command" ? 600 :
      line.type === "divider" ? 200 :
      line.type === "agent" ? 350 : 300;

    const timer = setTimeout(() => setVisibleLines((v) => v + 1), delay);
    return () => clearTimeout(timer);
  }, [visibleLines]);

  return (
    <div className="overflow-hidden rounded-xl border border-card-border bg-card shadow-2xl">
      {/* Title bar */}
      <div className="flex items-center gap-2 border-b border-card-border px-4 py-3">
        <div className="h-3 w-3 rounded-full bg-mac-red" />
        <div className="h-3 w-3 rounded-full bg-mac-yellow" />
        <div className="h-3 w-3 rounded-full bg-mac-green" />
        <span className="ml-2 text-xs text-muted font-mono">terminal</span>
      </div>
      {/* Content */}
      <div className="p-5 font-mono text-sm leading-relaxed">
        {terminalLines.slice(0, visibleLines).map((line, i) => {
          if (line.type === "command") {
            return (
              <div key={i} className="text-muted">
                <span className="text-accent">$</span> ./auto-agent.sh
              </div>
            );
          }
          if (line.type === "divider") {
            return (
              <div key={i} className="mt-2 text-muted/70">{line.text}</div>
            );
          }
          if (line.type === "success") {
            return (
              <div key={i}>
                <span className="text-status-success">✓</span> {line.text.slice(2)}
              </div>
            );
          }
          if (line.type === "agent") {
            return (
              <div key={i}>
                <span className="text-status-info">→</span>{" "}
                <span className="text-foreground">{line.text.slice(2)}</span>{" "}
                <span className="text-muted/50">{line.detail}</span>
              </div>
            );
          }
          return null;
        })}

        {/* Cursor */}
        <div className="mt-2 text-muted">
          <span className="text-accent">$</span>{" "}
          <span className="animate-pulse">▌</span>
        </div>
      </div>
    </div>
  );
}
