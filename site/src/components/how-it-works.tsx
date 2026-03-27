"use client";

import { motion } from "framer-motion";
import { Settings, Play, CheckCircle } from "lucide-react";

const steps = [
  {
    number: "01",
    icon: Settings,
    title: "Configure your agents",
    description:
      "Define roles in agents.conf. Backend, frontend, QA, security — whatever your project needs. Each agent gets a markdown prompt with their tasks and file ownership.",
  },
  {
    number: "02",
    icon: Play,
    title: "Run the orchestrator",
    description:
      "One command. Agents read their prompts, do their work, and write to shared context. No conflicts — file ownership keeps everyone in their lane.",
  },
  {
    number: "03",
    icon: CheckCircle,
    title: "Review and ship",
    description:
      "PM agent coordinates. QA reviews. You check the diff and merge. Run multiple cycles unattended with auto-cycle mode.",
  },
];

export function HowItWorks() {
  return (
    <section className="px-6 py-24">
      <div className="mx-auto max-w-5xl">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.5 }}
          className="text-center"
        >
          <h2 className="text-3xl font-bold tracking-tight sm:text-4xl">
            How it works
          </h2>
          <p className="mt-4 text-lg text-muted">
            Three steps. Zero setup overhead.
          </p>
        </motion.div>

        <div className="mt-16 grid gap-8 md:grid-cols-3">
          {steps.map((step, i) => (
            <motion.div
              key={step.number}
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ duration: 0.5, delay: i * 0.15 }}
              className="relative rounded-xl border border-card-border bg-card p-8"
            >
              <span className="font-mono text-5xl font-bold text-card-border">
                {step.number}
              </span>
              <div className="mt-4 flex items-center gap-3">
                <step.icon className="h-5 w-5 text-accent" />
                <h3 className="text-lg font-semibold">{step.title}</h3>
              </div>
              <p className="mt-3 text-sm leading-relaxed text-muted">
                {step.description}
              </p>
            </motion.div>
          ))}
        </div>
      </div>
    </section>
  );
}
