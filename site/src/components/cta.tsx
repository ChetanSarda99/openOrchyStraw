"use client";

import { motion } from "framer-motion";
import { Github, ArrowRight } from "lucide-react";

export function CTA() {
  return (
    <section className="px-4 py-16 sm:px-6 sm:py-24">
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        whileInView={{ opacity: 1, y: 0 }}
        viewport={{ once: true }}
        transition={{ duration: 0.5 }}
        className="mx-auto max-w-3xl rounded-2xl border border-accent/20 bg-gradient-to-b from-accent/5 to-transparent p-8 text-center sm:p-12"
      >
        <h2 className="text-3xl font-bold tracking-tight sm:text-4xl">
          Try it on your codebase
        </h2>
        <p className="mx-auto mt-4 max-w-xl text-lg text-muted">
          Clone, edit agents.conf, run the script. First cycle in under 2 minutes.
        </p>

        <div className="mt-8 flex flex-col items-center gap-3 sm:flex-row sm:justify-center sm:gap-4">
          <a
            href="https://github.com/ChetanSarda99/openOrchyStraw"
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-2 rounded-lg bg-accent px-6 py-3 text-sm font-semibold text-accent-foreground transition-colors hover:bg-accent/90"
          >
            <Github className="h-4 w-4" />
            Get Started
            <ArrowRight className="h-4 w-4" />
          </a>
          <a
            href="#demo"
            className="inline-flex items-center gap-2 rounded-lg border border-card-border bg-card px-6 py-3 text-sm font-semibold text-foreground transition-colors hover:bg-card-border/30"
          >
            See the Demo
          </a>
        </div>

        <p className="mt-6 text-xs text-muted/50">
          Free and open source. MIT License.
        </p>
      </motion.div>
    </section>
  );
}
