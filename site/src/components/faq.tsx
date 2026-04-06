"use client";

import { useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { ChevronDown } from "lucide-react";

const faqs = [
  {
    question: "What is OrchyStraw?",
    answer:
      "It runs multiple AI coding agents on one codebase without them stepping on each other. You write prompts in markdown, set who owns which files in agents.conf, and run a single bash script. That's the whole thing.",
  },
  {
    question: "Do I need to install anything?",
    answer:
      "Nope. Just bash 5+ and whatever AI coding tool you already use. No Python, no npm, no Docker. Clone and run.",
  },
  {
    question: "How much does it cost?",
    answer:
      "OrchyStraw is free, MIT licensed. You pay for your AI tool (Claude Code, Codex, whatever) — that's it. A typical 5-cycle run costs me about $1.23 in API calls.",
  },
  {
    question: "Which AI models work?",
    answer:
      "Anything that takes a text prompt. Claude Code, Codex, Gemini CLI, Aider, Cursor, local models — OrchyStraw doesn't care. It orchestrates the tool, it doesn't replace it.",
  },
  {
    question: "How is this different from AutoGen or CrewAI?",
    answer:
      "AutoGen and CrewAI are Python frameworks for chat-style agents. OrchyStraw orchestrates real coding agents — Claude Code, Cursor, etc. — that directly edit your files. Completely different approach. No runtime, no message passing. Just prompts and bash.",
  },
  {
    question: "Can I add custom agents?",
    answer:
      "Add one line to agents.conf, write a markdown prompt, done. It picks up the new agent on the next cycle. Takes about 30 seconds.",
  },
];

export function FAQ() {
  const [openIndex, setOpenIndex] = useState<number | null>(null);

  return (
    <section id="faq" className="px-4 py-16 sm:px-6 sm:py-24">
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
                className="flex w-full items-center justify-between py-5 text-left"
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
