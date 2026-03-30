"use client";

import { motion } from "framer-motion";
import {
  Blocks,
  Bot,
  Shield,
  MessageSquare,
  RotateCcw,
  Sparkles,
} from "lucide-react";

const features = [
  {
    icon: Blocks,
    title: "Zero dependencies",
    description:
      "Bash + markdown. That's it. No Python runtime, no npm packages, no Docker containers. Works on any machine with a shell.",
  },
  {
    icon: Bot,
    title: "Agent-agnostic",
    description:
      "Works with Claude Code, Codex, Gemini CLI, Aider, Windsurf, Cursor — anything that takes a prompt.",
  },
  {
    icon: Shield,
    title: "File ownership boundaries",
    description:
      "Each agent owns specific files. No cross-agent conflicts. Backend can't touch frontend, frontend can't touch scripts.",
  },
  {
    icon: MessageSquare,
    title: "Shared context",
    description:
      "Agents communicate through a shared markdown file. Token-efficient, human-readable, no message buses or APIs.",
  },
  {
    icon: RotateCcw,
    title: "Auto-cycle mode",
    description:
      "Run N cycles unattended. The orchestrator handles agent scheduling, context rotation, and usage monitoring.",
  },
  {
    icon: Sparkles,
    title: "Pixel Agents",
    description:
      "Watch your agents work in a pixel art office. Real-time visualization of who's building what.",
  },
];

export function Features() {
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
            Built for real codebases
          </h2>
          <p className="mt-4 text-lg text-muted">
            Not a toy. Not a framework. Just orchestration that works.
          </p>
        </motion.div>

        <div className="mt-10 grid gap-4 sm:mt-16 sm:grid-cols-2 sm:gap-6 lg:grid-cols-3">
          {features.map((feature, i) => (
            <motion.div
              key={feature.title}
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ duration: 0.4, delay: i * 0.1 }}
              className="rounded-xl border border-card-border bg-card p-6 transition-colors hover:border-accent/30"
            >
              <feature.icon className="h-5 w-5 text-accent" />
              <h3 className="mt-4 font-semibold">{feature.title}</h3>
              <p className="mt-2 text-sm leading-relaxed text-muted">
                {feature.description}
              </p>
            </motion.div>
          ))}
        </div>
      </div>
    </section>
  );
}
