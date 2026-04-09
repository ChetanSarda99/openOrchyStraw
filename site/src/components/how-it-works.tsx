"use client";

import { motion } from "framer-motion";

const fadeUp = {
  hidden: { opacity: 0, y: 24 },
  visible: { opacity: 1, y: 0 },
};

const steps = [
  {
    number: "01",
    title: "Configure your agents",
    description: "One config file. Define who does what, which files they own, and how often they run. Prompts are just markdown.",
    code: `# agents.conf — who does what
#
# id        owns              interval  model
01-ceo      docs/strategy/    3         claude
02-cto      docs/architecture/ 2        claude
06-backend  scripts/ src/     1         claude
09-qa       tests/            3         sonnet
11-web      site/             1         sonnet`,
  },
  {
    number: "02",
    title: "Run the orchestrator",
    description: "One command. Each agent reads its prompt, works in its own git worktree, and drops updates into shared context.",
    code: `$ ./auto-agent.sh --cycles 5

── Cycle 1 / 5 ──────────────────────
→ 06-backend   hardening core modules...
→ 09-qa        running test suite...
→ 11-web       building landing page...

✓ 3 agents ran  · 14 files changed
✓ All quality gates passed`,
  },
  {
    number: "03",
    title: "Review and merge",
    description: "QA runs tests, Security scans for leaks, PM updates prompts. You check the diff and merge. Or let it auto-cycle overnight.",
    code: `── Quality Report ───────────────────
Tests:     45/45 passed
Security:  0 vulnerabilities
Conflicts: 0 (file ownership enforced)
Cost:      $1.23 across 5 cycles

✓ Ready to merge → main`,
  },
];

export function HowItWorks() {
  return (
    <section className="px-4 py-24 sm:px-6 sm:py-32">
      <div className="mx-auto max-w-5xl">
        <motion.div
          variants={fadeUp}
          initial="hidden"
          whileInView="visible"
          viewport={{ once: true, margin: "-100px" }}
          transition={{ duration: 0.5, ease: [0.21, 0.47, 0.32, 0.98] }}
        >
          <h2
            className="font-medium text-foreground"
            style={{
              fontSize: "var(--font-size-h2)",
              lineHeight: 1.3,
              letterSpacing: "-0.01em",
              textWrap: "balance",
            }}
          >
            Three steps, zero setup
          </h2>
          <p
            className="mt-4 max-w-lg text-text-secondary"
            style={{ fontSize: "var(--font-size-body)", lineHeight: 1.6 }}
          >
            Clone the repo. Edit agents.conf. Run the script.
            First cycle finishes in under 2 minutes.
          </p>
        </motion.div>

        <div className="mt-12 flex flex-col gap-6 sm:mt-16 sm:gap-8">
          {steps.map((step, i) => (
            <motion.div
              key={step.number}
              variants={fadeUp}
              initial="hidden"
              whileInView="visible"
              viewport={{ once: true, margin: "-80px" }}
              transition={{
                duration: 0.5,
                delay: i * 0.1,
                ease: [0.21, 0.47, 0.32, 0.98],
              }}
              className="grid gap-6 sm:grid-cols-5 sm:gap-8"
            >
              <div className="sm:col-span-2 flex flex-col justify-center">
                <span
                  className="font-mono text-text-quaternary"
                  style={{ fontSize: "3rem", lineHeight: 1, fontWeight: 600 }}
                >
                  {step.number}
                </span>
                <h3
                  className="mt-3 font-medium text-foreground"
                  style={{ fontSize: "var(--font-size-h3)", lineHeight: 1.3, letterSpacing: "-0.01em" }}
                >
                  {step.title}
                </h3>
                <p
                  className="mt-2 text-text-secondary"
                  style={{ fontSize: "var(--font-size-small)", lineHeight: 1.6 }}
                >
                  {step.description}
                </p>
              </div>
              <div className="sm:col-span-3">
                <pre
                  className="overflow-x-auto rounded-xl border border-card-border p-5 font-mono text-text-secondary"
                  style={{
                    fontSize: "var(--font-size-micro)",
                    background: "var(--card)",
                    lineHeight: 1.8,
                  }}
                >
                  {step.code}
                </pre>
              </div>
            </motion.div>
          ))}
        </div>
      </div>
    </section>
  );
}
