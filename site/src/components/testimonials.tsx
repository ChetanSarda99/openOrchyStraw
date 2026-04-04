"use client";

import { motion } from "framer-motion";
import { Quote } from "lucide-react";

const testimonials = [
  {
    quote: "We went from 1 AI agent to 6 agents on the same monorepo. File ownership prevents the chaos we expected.",
    author: "Early Adopter",
    role: "Engineering Lead",
    company: "SaaS Startup",
  },
  {
    quote: "The zero-dependency approach is brilliant. We cloned the repo and had agents running in 10 minutes.",
    author: "Early Adopter",
    role: "Solo Developer",
    company: "Indie Project",
  },
  {
    quote: "Auto-cycle mode with PM review is like having a project manager that never sleeps. Our agents self-coordinate.",
    author: "Early Adopter",
    role: "CTO",
    company: "Dev Agency",
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
            What early users say
          </h2>
          <p className="mt-4 text-lg text-muted">
            Real feedback from teams using OrchyStraw in production
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
