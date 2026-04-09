"use client";

import { motion } from "framer-motion";

const staggerContainer = {
  hidden: {},
  visible: {
    transition: { staggerChildren: 0.08, delayChildren: 0.1 },
  },
};

const staggerItem = {
  hidden: { opacity: 0, y: 20 },
  visible: {
    opacity: 1,
    y: 0,
    transition: { duration: 0.4, ease: [0.21, 0.47, 0.32, 0.98] as const },
  },
};

const features = [
  {
    title: "Multi-agent teams",
    label: "12 AGENTS",
    description: "CEO, CTO, PM, Backend, QA, Security, Web, Designer — each gets a role, a markdown prompt, and files they own. They talk through a shared context file. That's it.",
    code: `# agents.conf
01-ceo    docs/strategy/    3  claude
02-cto    docs/architecture/ 2  claude
06-backend scripts/ src/    1  claude
09-qa     tests/            3  sonnet`,
    span: "col-span-6 sm:col-span-4 row-span-2",
  },
  {
    title: "Zero dependencies",
    label: "BASH ONLY",
    description: "No Python. No Node. No Docker. Literally one shell script. If your machine has bash 5, you're good.",
    code: `$ file auto-agent.sh
auto-agent.sh: Bourne-Again shell script
$ wc -l src/core/*.sh
  3,100+ total`,
    span: "col-span-6 sm:col-span-2",
  },
  {
    title: "Any AI tool",
    label: "AGENT AGNOSTIC",
    description: "Claude Code, Codex, Gemini, Aider, Cursor, Windsurf — if it accepts a text prompt, it works.",
    code: null,
    tools: ["Claude Code", "Codex", "Gemini CLI", "Aider", "Cursor", "Windsurf"],
    span: "col-span-6 sm:col-span-2",
  },
  {
    title: "File ownership",
    label: "NO CONFLICTS",
    description: "Backend can't touch frontend. QA can't modify scripts. Agents stay in their lane. I've run 300+ cycles with zero merge conflicts.",
    code: `# 06-backend owns:
scripts/**  src/core/**

# 11-web owns:
site/**

# 09-qa owns (read-only on others):
tests/**`,
    span: "col-span-6 sm:col-span-3",
  },
  {
    title: "Quality gates",
    label: "AUTOMATED",
    description: "QA runs tests after every cycle. Security scans for credential leaks. PM reviews and updates prompts. Nothing merges until the gates pass.",
    code: `── Quality gates ──────────────
✓ 45/45 tests passed
✓ 0 credential leaks found
✓ PM review: approved
✓ Ready to merge`,
    span: "col-span-6 sm:col-span-3",
  },
];

function FeatureCard({ feature }: { feature: typeof features[number] }) {
  return (
    <motion.div
      variants={staggerItem}
      className="group flex flex-col rounded-xl border border-card-border p-6 transition-colors hover:border-card-border-hover"
      style={{ background: "var(--card)" }}
    >
      <span
        className="font-mono text-accent tracking-wider"
        style={{ fontSize: "var(--font-size-micro)" }}
      >
        {feature.label}
      </span>
      <h3
        className="mt-3 font-medium text-foreground"
        style={{ fontSize: "var(--font-size-h3)", lineHeight: 1.3, letterSpacing: "-0.01em" }}
      >
        {feature.title}
      </h3>
      <p
        className="mt-2 text-text-secondary"
        style={{ fontSize: "var(--font-size-small)", lineHeight: 1.6 }}
      >
        {feature.description}
      </p>
      {feature.code && (
        <pre
          className="mt-4 flex-1 overflow-x-auto rounded-lg border border-card-border p-3 font-mono text-text-tertiary"
          style={{ fontSize: "var(--font-size-micro)", background: "var(--background)", lineHeight: 1.7 }}
        >
          {feature.code}
        </pre>
      )}
      {"tools" in feature && feature.tools && (
        <div className="mt-4 flex flex-wrap gap-2">
          {feature.tools.map((tool) => (
            <span
              key={tool}
              className="inline-block rounded-md border border-card-border px-2.5 py-1 font-mono text-text-tertiary"
              style={{ fontSize: "var(--font-size-micro)" }}
            >
              {tool}
            </span>
          ))}
        </div>
      )}
    </motion.div>
  );
}

export function Features() {
  return (
    <section className="px-4 py-24 sm:px-6 sm:py-32">
      <div className="mx-auto max-w-5xl">
        <motion.div
          initial={{ opacity: 0, y: 24 }}
          whileInView={{ opacity: 1, y: 0 }}
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
            Built for real codebases
          </h2>
          <p
            className="mt-4 max-w-lg text-text-secondary"
            style={{ fontSize: "var(--font-size-body)", lineHeight: 1.6 }}
          >
            I built this for my own projects first. It runs 8 repos
            with 12 agents each. Here&apos;s what it actually does.
          </p>
        </motion.div>

        <motion.div
          variants={staggerContainer}
          initial="hidden"
          whileInView="visible"
          viewport={{ once: true, margin: "-50px" }}
          className="mt-12 grid grid-cols-6 gap-4 sm:mt-16"
        >
          {features.map((feature) => (
            <div key={feature.title} className={feature.span}>
              <FeatureCard feature={feature} />
            </div>
          ))}
        </motion.div>
      </div>
    </section>
  );
}
