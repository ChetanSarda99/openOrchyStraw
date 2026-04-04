"use client";

import { motion } from "framer-motion";
import { Copy, Check } from "lucide-react";
import { useState } from "react";

const configExample = `# agents.conf
03-pm      | prompts/03-pm/03-pm.txt     | prompts/ docs/ | 0 | PM
06-backend | prompts/06-backend/06-backend.txt | src/ scripts/  | 1 | Backend Dev
09-qa      | prompts/09-qa/09-qa.txt     | tests/         | 3 | QA Engineer`;

const promptExample = `# Backend Developer

You are the backend developer for this project.

## Current Sprint
- Build the REST API endpoints
- Add input validation
- Write unit tests

## File Ownership
You own: src/ scripts/
You never touch: site/ prompts/`;

const runExample = `$ bash scripts/auto-agent.sh orchestrate 3
── OrchyStraw v0.2.0 ──────────────────
✓ Loaded 3 agents from agents.conf
✓ Cycle 1/3 starting...
→ 06-backend  building REST endpoints...     ✓ 12 files changed
→ 09-qa       running test suite...           ✓ 4 tests added
→ 03-pm       reviewing cycle, updating prompts...  ✓ done
── Cycle 1 complete ─────────────────────
✓ 3 agents ran, 16 files changed, 0 conflicts`;

function CodeBlock({ title, code, language }: { title: string; code: string; language: string }) {
  const [copied, setCopied] = useState(false);

  const handleCopy = () => {
    navigator.clipboard.writeText(code);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <div className="overflow-hidden rounded-xl border border-card-border bg-card">
      <div className="flex items-center justify-between border-b border-card-border px-4 py-2.5">
        <span className="text-xs font-medium text-muted">{title}</span>
        <button
          onClick={handleCopy}
          className="flex items-center gap-1 text-xs text-muted transition-colors hover:text-foreground"
        >
          {copied ? <Check className="h-3 w-3" /> : <Copy className="h-3 w-3" />}
          {copied ? "Copied" : "Copy"}
        </button>
      </div>
      <pre className="overflow-x-auto p-4 font-mono text-xs leading-relaxed text-muted sm:text-sm">
        <code>{code}</code>
      </pre>
    </div>
  );
}

export function Demo() {
  return (
    <section id="demo" className="px-4 py-16 sm:px-6 sm:py-24">
      <div className="mx-auto max-w-5xl">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.5 }}
          className="text-center"
        >
          <h2 className="text-3xl font-bold tracking-tight sm:text-4xl">
            See it in action
          </h2>
          <p className="mt-4 text-lg text-muted">
            Three files. One command. A team of AI agents working on your codebase.
          </p>
        </motion.div>

        <div className="mt-10 grid gap-6 sm:mt-16 lg:grid-cols-2">
          <motion.div
            initial={{ opacity: 0, x: -20 }}
            whileInView={{ opacity: 1, x: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.5 }}
            className="space-y-6"
          >
            <div>
              <p className="mb-3 text-sm font-medium text-accent">Step 1 — Define your team</p>
              <CodeBlock title="agents.conf" code={configExample} language="bash" />
            </div>
            <div>
              <p className="mb-3 text-sm font-medium text-accent">Step 2 — Write prompts</p>
              <CodeBlock title="prompts/06-backend/06-backend.txt" code={promptExample} language="markdown" />
            </div>
          </motion.div>

          <motion.div
            initial={{ opacity: 0, x: 20 }}
            whileInView={{ opacity: 1, x: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.5, delay: 0.2 }}
          >
            <p className="mb-3 text-sm font-medium text-accent">Step 3 — Run it</p>
            <CodeBlock title="terminal" code={runExample} language="bash" />

            <div className="mt-6 rounded-xl border border-accent/20 bg-accent/5 p-5">
              <h3 className="text-sm font-semibold text-accent">What just happened?</h3>
              <ul className="mt-3 space-y-2 text-sm text-muted">
                <li className="flex gap-2">
                  <span className="text-accent">1.</span>
                  Backend agent read its prompt and built REST endpoints
                </li>
                <li className="flex gap-2">
                  <span className="text-accent">2.</span>
                  QA agent tested the new code and added tests
                </li>
                <li className="flex gap-2">
                  <span className="text-accent">3.</span>
                  PM reviewed everything and updated prompts for cycle 2
                </li>
                <li className="flex gap-2">
                  <span className="text-accent">4.</span>
                  Each agent committed separately — clean git history
                </li>
              </ul>
            </div>
          </motion.div>
        </div>
      </div>
    </section>
  );
}
