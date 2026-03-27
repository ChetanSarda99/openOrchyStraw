"use client";

import { useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { ChevronDown } from "lucide-react";

const faqs = [
  {
    question: "What is OrchyStraw?",
    answer:
      "Multi-agent AI coding orchestration. You define agents with markdown prompts, configure their file ownership in agents.conf, and run them with a single bash script. Agents work on the same codebase without conflicts.",
  },
  {
    question: "Do I need to install anything?",
    answer:
      "Just bash 5.0+ and your AI coding tool of choice. No Python, no npm, no Docker. Clone the repo and run ./auto-agent.sh.",
  },
  {
    question: "How much does it cost?",
    answer:
      "OrchyStraw itself is free and open source (MIT). You only pay for the AI tool you use — Claude Code, Codex, etc. OrchyStraw adds zero overhead.",
  },
  {
    question: "Which AI models work?",
    answer:
      "Any model that accepts a text prompt. Claude, GPT, Gemini, local models, anything. OrchyStraw doesn't call APIs — it orchestrates whichever tool you're already using.",
  },
  {
    question: "How is this different from AutoGen or CrewAI?",
    answer:
      "Those are Python frameworks for chat agents. OrchyStraw orchestrates real coding agents (Claude Code, Cursor, etc.) that edit files directly. No runtime, no message passing, no dependencies. Just markdown prompts and bash.",
  },
  {
    question: "Can I add custom agents?",
    answer:
      "Yes. Add a line to agents.conf and create a markdown prompt file. Define the agent's role, file ownership, and tasks. It runs in the next cycle.",
  },
];

export function FAQ() {
  const [openIndex, setOpenIndex] = useState<number | null>(null);

  return (
    <section className="px-4 py-16 sm:px-6 sm:py-24">
      <div className="mx-auto max-w-2xl">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.5 }}
          className="text-center"
        >
          <h2 className="text-3xl font-bold tracking-tight sm:text-4xl">
            FAQ
          </h2>
        </motion.div>

        <div className="mt-12 divide-y divide-card-border">
          {faqs.map((faq, i) => (
            <motion.div
              key={i}
              initial={{ opacity: 0 }}
              whileInView={{ opacity: 1 }}
              viewport={{ once: true }}
              transition={{ duration: 0.3, delay: i * 0.05 }}
            >
              <button
                onClick={() => setOpenIndex(openIndex === i ? null : i)}
                aria-expanded={openIndex === i}
                className="flex w-full items-center justify-between py-5 text-left focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent focus-visible:ring-offset-2 focus-visible:ring-offset-background rounded-sm"
              >
                <span className="font-medium">{faq.question}</span>
                <ChevronDown
                  className={`h-4 w-4 shrink-0 text-muted transition-transform duration-200 ${
                    openIndex === i ? "rotate-180" : ""
                  }`}
                />
              </button>
              <AnimatePresence>
                {openIndex === i && (
                  <motion.div
                    initial={{ height: 0, opacity: 0 }}
                    animate={{ height: "auto", opacity: 1 }}
                    exit={{ height: 0, opacity: 0 }}
                    transition={{ duration: 0.2 }}
                    className="overflow-hidden"
                  >
                    <p className="pb-5 text-sm leading-relaxed text-muted">
                      {faq.answer}
                    </p>
                  </motion.div>
                )}
              </AnimatePresence>
            </motion.div>
          ))}
        </div>
      </div>
    </section>
  );
}
