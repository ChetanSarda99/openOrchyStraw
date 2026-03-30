"use client";

import { motion } from "framer-motion";

const tools = [
  { name: "Claude Code", abbr: "CC" },
  { name: "Codex", abbr: "CX" },
  { name: "Gemini CLI", abbr: "GC" },
  { name: "Aider", abbr: "AI" },
  { name: "Windsurf", abbr: "WS" },
  { name: "Cursor", abbr: "CR" },
  { name: "ChatGPT", abbr: "GP" },
];

export function SupportedTools() {
  return (
    <section className="px-4 py-16 sm:px-6 sm:py-24">
      <div className="mx-auto max-w-4xl text-center">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.5 }}
        >
          <p className="text-sm font-medium uppercase tracking-widest text-muted">
            Works with anything that takes a prompt
          </p>

          <div className="mt-8 flex flex-wrap items-center justify-center gap-4 sm:mt-10 sm:gap-6">
            {tools.map((tool, i) => (
              <motion.div
                key={tool.name}
                initial={{ opacity: 0, scale: 0.9 }}
                whileInView={{ opacity: 1, scale: 1 }}
                viewport={{ once: true }}
                transition={{ duration: 0.3, delay: i * 0.05 }}
                className="flex flex-col items-center gap-2"
              >
                <div className="flex h-14 w-14 items-center justify-center rounded-xl border border-card-border bg-card font-mono text-sm font-bold text-muted transition-colors hover:border-accent/40 hover:text-accent">
                  {tool.abbr}
                </div>
                <span className="text-xs text-muted/60">{tool.name}</span>
              </motion.div>
            ))}
          </div>
        </motion.div>
      </div>
    </section>
  );
}
