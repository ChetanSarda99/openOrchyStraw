"use client";

import { motion } from "framer-motion";
import { Github, Terminal } from "lucide-react";

export function Hero() {
  return (
    <section className="relative flex flex-col items-center justify-center px-6 pt-32 pb-24 text-center">
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
        <h1 className="text-4xl font-bold leading-tight tracking-tight sm:text-5xl md:text-6xl lg:text-7xl">
          Run a team of AI coding agents{" "}
          <span className="text-accent">on any codebase</span>
        </h1>

        {/* Subhead */}
        <p className="mx-auto mt-6 max-w-2xl text-lg text-muted sm:text-xl">
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
            href="https://github.com/ChetanSarda99/openOrchyStraw"
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
  { text: <><span className="text-accent">$</span> ./auto-agent.sh</>, className: "text-muted", delay: 0 },
  { text: "── OrchyStraw v0.1.0 ──────────────────", className: "mt-2 text-muted/70", delay: 0.4 },
  { text: <><span className="text-green-400">✓</span> Loaded 11 agents from agents.conf</>, className: "mt-1", delay: 0.8 },
  { text: <><span className="text-green-400">✓</span> Cycle 1 starting...</>, className: "", delay: 1.1 },
  { text: "── Running agents ──────────────────────", className: "mt-1 text-muted/70", delay: 1.5 },
  { text: <><span className="text-blue-400">→</span> <span className="text-foreground">04-tauri-rust</span> <span className="text-muted/50">building IPC commands...</span></>, className: "", delay: 1.9 },
  { text: <><span className="text-blue-400">→</span> <span className="text-foreground">05-tauri-ui</span> <span className="text-muted/50">scaffolding dashboard...</span></>, className: "", delay: 2.3 },
  { text: <><span className="text-blue-400">→</span> <span className="text-foreground">06-backend</span> <span className="text-muted/50">hardening orchestrator...</span></>, className: "", delay: 2.7 },
  { text: <><span className="text-blue-400">→</span> <span className="text-foreground">07-ios</span> <span className="text-muted/50">building companion app...</span></>, className: "", delay: 3.1 },
  { text: "── Cycle 1 complete ─────────────────────", className: "mt-1 text-muted/70", delay: 3.8 },
  { text: <><span className="text-green-400">✓</span> 4 agents ran, 12 files changed, 0 conflicts</>, className: "", delay: 4.2 },
  { text: <><span className="text-accent">$</span> <span className="animate-pulse">▌</span></>, className: "mt-2 text-muted", delay: 4.6 },
];

function TerminalDemo() {
  return (
    <div className="overflow-hidden rounded-xl border border-card-border bg-card shadow-2xl">
      {/* Title bar */}
      <div className="flex items-center gap-2 border-b border-card-border px-4 py-3">
        <div className="h-3 w-3 rounded-full bg-[#ff5f57]" />
        <div className="h-3 w-3 rounded-full bg-[#febc2e]" />
        <div className="h-3 w-3 rounded-full bg-[#28c840]" />
        <span className="ml-2 text-xs text-muted font-mono">terminal</span>
      </div>
      {/* Content */}
      <div className="p-5 font-mono text-sm leading-relaxed">
        {terminalLines.map((line, i) => (
          <motion.div
            key={i}
            initial={{ opacity: 0, x: -8 }}
            whileInView={{ opacity: 1, x: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.3, delay: line.delay }}
            className={line.className}
          >
            {line.text}
          </motion.div>
        ))}
      </div>
    </div>
  );
}
