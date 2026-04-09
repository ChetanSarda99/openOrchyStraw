"use client";

import { motion } from "framer-motion";
import { Quote } from "lucide-react";

const testimonials = [
  {
    quote: "I was running Claude Code on one file at a time like a caveman. Now I have 12 agents on the same monorepo and they haven't stepped on each other once.",
    author: "CS",
    role: "The person who built this",
    company: "OrchyStraw",
  },
  {
    quote: "The setup is: clone, edit agents.conf, run the script. No pip install, no Docker, no YAML hell. First cycle ran in under 2 minutes.",
    author: "CS",
    role: "Testing on 8 repos",
    company: "OrchyStraw",
  },
  {
    quote: "I set it to auto-cycle overnight. Woke up to 47 files changed, all tests passing, zero conflicts. The PM agent even updated the prompts for the next run.",
    author: "CS",
    role: "Dog-fooding my own tool",
    company: "OrchyStraw",
  },
];

export function Testimonials() {
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
            From the trenches
          </h2>
          <p className="mt-4 text-lg text-muted">
            Mostly me dog-fooding this on my own projects. But honestly, that&apos;s the best test.
          </p>
        </motion.div>

        <div className="mt-10 grid gap-6 sm:mt-16 md:grid-cols-3">
          {testimonials.map((t, i) => (
            <motion.div
              key={i}
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ duration: 0.4, delay: i * 0.1 }}
              className="rounded-xl border border-card-border bg-card p-6"
            >
              <Quote className="h-5 w-5 text-accent/40" />
              <p className="mt-4 text-sm leading-relaxed text-muted">
                &ldquo;{t.quote}&rdquo;
              </p>
              <div className="mt-5 border-t border-card-border pt-4">
                <p className="text-sm font-medium text-foreground">{t.author}</p>
                <p className="text-xs text-muted">
                  {t.role} &middot; {t.company}
                </p>
              </div>
            </motion.div>
          ))}
        </div>
      </div>
    </section>
  );
}
