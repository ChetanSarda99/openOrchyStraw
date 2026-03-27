"use client";

import { motion } from "framer-motion";
import { Users, GitBranch, FileCode, Zap } from "lucide-react";

const stats = [
  {
    icon: Users,
    value: "11",
    label: "Specialized agents",
  },
  {
    icon: GitBranch,
    value: "0",
    label: "Dependencies",
  },
  {
    icon: FileCode,
    value: "21+",
    label: "Core modules",
  },
  {
    icon: Zap,
    value: "30-70%",
    label: "Token savings",
  },
];

const builtWith = [
  "Bash 5.0+",
  "Markdown prompts",
  "Git",
  "Any AI coding tool",
];

export function SocialProof() {
  return (
    <section className="px-4 py-16 sm:px-6 sm:py-24">
      <div className="mx-auto max-w-5xl">
        {/* Stats grid */}
        <div className="grid grid-cols-2 gap-6 sm:gap-8 lg:grid-cols-4">
          {stats.map((stat, i) => (
            <motion.div
              key={stat.label}
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ duration: 0.4, delay: i * 0.1 }}
              className="flex flex-col items-center gap-2 rounded-xl border border-card-border bg-card p-6 text-center"
            >
              <stat.icon className="h-5 w-5 text-accent" />
              <span className="font-mono text-3xl font-bold tracking-tight">
                {stat.value}
              </span>
              <span className="text-sm text-muted">{stat.label}</span>
            </motion.div>
          ))}
        </div>

        {/* Built with strip */}
        <motion.div
          initial={{ opacity: 0 }}
          whileInView={{ opacity: 1 }}
          viewport={{ once: true }}
          transition={{ duration: 0.5, delay: 0.3 }}
          className="mt-12 text-center"
        >
          <p className="text-sm font-medium uppercase tracking-widest text-muted/60">
            The entire stack
          </p>
          <div className="mt-4 flex flex-wrap items-center justify-center gap-3">
            {builtWith.map((item) => (
              <span
                key={item}
                className="rounded-full border border-card-border bg-card px-4 py-1.5 font-mono text-xs text-muted"
              >
                {item}
              </span>
            ))}
          </div>
        </motion.div>
      </div>
    </section>
  );
}
