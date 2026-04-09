"use client";

import { motion } from "framer-motion";

const fadeUp = {
  hidden: { opacity: 0, y: 24 },
  visible: { opacity: 1, y: 0 },
};

interface Row {
  feature: string;
  orchystraw: string;
  crewai: string;
  autogen: string;
  langgraph: string;
}

const rows: Row[] = [
  {
    feature: "Language",
    orchystraw: "Bash",
    crewai: "Python",
    autogen: "Python",
    langgraph: "Python",
  },
  {
    feature: "Dependencies",
    orchystraw: "0",
    crewai: "pip install",
    autogen: "pip install",
    langgraph: "pip install",
  },
  {
    feature: "Works with any AI CLI",
    orchystraw: "Yes",
    crewai: "No",
    autogen: "No",
    langgraph: "No",
  },
  {
    feature: "File ownership",
    orchystraw: "Built-in",
    crewai: "--",
    autogen: "--",
    langgraph: "--",
  },
  {
    feature: "Git worktree isolation",
    orchystraw: "Built-in",
    crewai: "--",
    autogen: "--",
    langgraph: "--",
  },
  {
    feature: "Quality gates (QA + Security)",
    orchystraw: "Built-in",
    crewai: "Custom",
    autogen: "Custom",
    langgraph: "Custom",
  },
  {
    feature: "Cost tracking",
    orchystraw: "Per-agent",
    crewai: "--",
    autogen: "Global",
    langgraph: "--",
  },
  {
    feature: "Human-readable prompts",
    orchystraw: "Markdown",
    crewai: "Python str",
    autogen: "Python str",
    langgraph: "Python str",
  },
  {
    feature: "Setup time",
    orchystraw: "2 min",
    crewai: "30 min",
    autogen: "30 min",
    langgraph: "45 min",
  },
  {
    feature: "License",
    orchystraw: "MIT",
    crewai: "MIT",
    autogen: "MIT",
    langgraph: "MIT",
  },
];

function CellValue({ value, isOrchy }: { value: string; isOrchy?: boolean }) {
  const isDash = value === "--";
  return (
    <span
      className={
        isDash
          ? "text-text-quaternary"
          : isOrchy
            ? "text-accent font-medium"
            : "text-text-secondary"
      }
    >
      {value}
    </span>
  );
}

export function Comparison() {
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
            How it stacks up
          </h2>
          <p
            className="mt-4 max-w-lg text-text-secondary"
            style={{ fontSize: "var(--font-size-body)", lineHeight: 1.6 }}
          >
            They&apos;re Python frameworks. This is a shell script.
            Different category, same problem space.
          </p>
        </motion.div>

        <motion.div
          variants={fadeUp}
          initial="hidden"
          whileInView="visible"
          viewport={{ once: true, margin: "-50px" }}
          transition={{ duration: 0.5, delay: 0.1, ease: [0.21, 0.47, 0.32, 0.98] }}
          className="mt-12 overflow-x-auto sm:mt-16"
        >
          <table
            className="w-full min-w-[640px] border-collapse font-mono"
            style={{ fontSize: "var(--font-size-small)" }}
          >
            <thead>
              <tr className="border-b border-card-border">
                <th
                  className="py-3 pr-6 text-left font-medium text-text-tertiary"
                  style={{ fontSize: "var(--font-size-micro)" }}
                >
                  Feature
                </th>
                <th
                  className="px-4 py-3 text-left font-medium text-accent"
                  style={{ fontSize: "var(--font-size-micro)" }}
                >
                  OrchyStraw
                </th>
                <th
                  className="px-4 py-3 text-left font-medium text-text-tertiary"
                  style={{ fontSize: "var(--font-size-micro)" }}
                >
                  CrewAI
                </th>
                <th
                  className="px-4 py-3 text-left font-medium text-text-tertiary"
                  style={{ fontSize: "var(--font-size-micro)" }}
                >
                  AutoGen
                </th>
                <th
                  className="px-4 py-3 text-left font-medium text-text-tertiary"
                  style={{ fontSize: "var(--font-size-micro)" }}
                >
                  LangGraph
                </th>
              </tr>
            </thead>
            <tbody>
              {rows.map((row) => (
                <tr
                  key={row.feature}
                  className="border-b border-card-border/40 last:border-0"
                >
                  <td className="py-3 pr-6 text-text-secondary">{row.feature}</td>
                  <td className="px-4 py-3">
                    <CellValue value={row.orchystraw} isOrchy />
                  </td>
                  <td className="px-4 py-3">
                    <CellValue value={row.crewai} />
                  </td>
                  <td className="px-4 py-3">
                    <CellValue value={row.autogen} />
                  </td>
                  <td className="px-4 py-3">
                    <CellValue value={row.langgraph} />
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </motion.div>
      </div>
    </section>
  );
}
