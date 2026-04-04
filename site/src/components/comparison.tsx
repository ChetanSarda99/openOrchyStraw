"use client";

import { motion } from "framer-motion";
import { Check, X, Minus } from "lucide-react";

type Support = "yes" | "no" | "partial";

interface Row {
  feature: string;
  orchystraw: Support;
  autogen: Support;
  crewai: Support;
  ralph: Support;
}

const rows: Row[] = [
  { feature: "Zero dependencies (bash only)", orchystraw: "yes", autogen: "no", crewai: "no", ralph: "no" },
  { feature: "Works with any AI CLI", orchystraw: "yes", autogen: "no", crewai: "no", ralph: "partial" },
  { feature: "File ownership enforcement", orchystraw: "yes", autogen: "no", crewai: "no", ralph: "no" },
  { feature: "Git-native (commits per agent)", orchystraw: "yes", autogen: "no", crewai: "no", ralph: "yes" },
  { feature: "Worktree isolation", orchystraw: "yes", autogen: "no", crewai: "no", ralph: "no" },
  { feature: "Auto-cycle with PM review", orchystraw: "yes", autogen: "partial", crewai: "partial", ralph: "no" },
  { feature: "Token optimization", orchystraw: "yes", autogen: "no", crewai: "no", ralph: "no" },
  { feature: "Human-readable prompts (markdown)", orchystraw: "yes", autogen: "no", crewai: "no", ralph: "yes" },
  { feature: "No Python/Node runtime needed", orchystraw: "yes", autogen: "no", crewai: "no", ralph: "partial" },
  { feature: "Open source (MIT)", orchystraw: "yes", autogen: "yes", crewai: "yes", ralph: "yes" },
];

function CellIcon({ value }: { value: Support }) {
  if (value === "yes") return <Check className="h-4 w-4 text-green-400" />;
  if (value === "no") return <X className="h-4 w-4 text-red-400/60" />;
  return <Minus className="h-4 w-4 text-yellow-400/60" />;
}

export function Comparison() {
  return (
    <section id="comparison" className="px-4 py-16 sm:px-6 sm:py-24">
      <div className="mx-auto max-w-5xl">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.5 }}
          className="text-center"
        >
          <h2 className="text-3xl font-bold tracking-tight sm:text-4xl">
            How it compares
          </h2>
          <p className="mt-4 text-lg text-muted">
            OrchyStraw vs. other multi-agent frameworks
          </p>
        </motion.div>

        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.5, delay: 0.1 }}
          className="mt-10 overflow-x-auto sm:mt-16"
        >
          <table className="w-full min-w-[640px] border-collapse text-sm">
            <thead>
              <tr className="border-b border-card-border">
                <th className="py-3 pr-4 text-left font-medium text-muted">Feature</th>
                <th className="px-4 py-3 text-center font-semibold text-accent">OrchyStraw</th>
                <th className="px-4 py-3 text-center font-medium text-muted">AutoGen</th>
                <th className="px-4 py-3 text-center font-medium text-muted">CrewAI</th>
                <th className="px-4 py-3 text-center font-medium text-muted">Ralph</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((row, i) => (
                <tr key={row.feature} className="border-b border-card-border/50 last:border-0">
                  <td className="py-3 pr-4 text-muted">{row.feature}</td>
                  <td className="px-4 py-3">
                    <div className="flex justify-center"><CellIcon value={row.orchystraw} /></div>
                  </td>
                  <td className="px-4 py-3">
                    <div className="flex justify-center"><CellIcon value={row.autogen} /></div>
                  </td>
                  <td className="px-4 py-3">
                    <div className="flex justify-center"><CellIcon value={row.crewai} /></div>
                  </td>
                  <td className="px-4 py-3">
                    <div className="flex justify-center"><CellIcon value={row.ralph} /></div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </motion.div>

        <p className="mt-6 text-center text-xs text-muted/50">
          Comparison based on publicly available documentation as of April 2026. AutoGen and CrewAI are Python chat-agent frameworks. Ralph is a bash-based coding agent.
        </p>
      </div>
    </section>
  );
}
