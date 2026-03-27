import type { Metadata } from "next";
import { ArrowLeft, Terminal, Play, List, Settings, RotateCcw } from "lucide-react";

export const metadata: Metadata = {
  title: "CLI Reference — OrchyStraw Docs",
  description:
    "Full command reference for auto-agent.sh — orchestrate cycles, run single agents, list configuration, and more.",
};

function CommandBlock({
  name,
  usage,
  description,
  flags,
  example,
}: {
  name: string;
  usage: string;
  description: string;
  flags?: { flag: string; desc: string }[];
  example: string;
}) {
  return (
    <div className="rounded-xl border border-card-border bg-card/50 p-5">
      <h3 className="font-mono text-base font-semibold text-accent">{name}</h3>
      <p className="mt-1.5 text-sm text-foreground/80">{description}</p>
      <div className="mt-3 rounded-lg border border-card-border bg-card p-3 font-mono text-xs">
        <span className="text-muted">$</span> {usage}
      </div>
      {flags && flags.length > 0 && (
        <div className="mt-3 space-y-1">
          {flags.map((f) => (
            <div key={f.flag} className="flex gap-3 text-sm">
              <code className="shrink-0 rounded bg-card px-1.5 py-0.5 font-mono text-xs text-accent">
                {f.flag}
              </code>
              <span className="text-muted">{f.desc}</span>
            </div>
          ))}
        </div>
      )}
      <div className="mt-3">
        <p className="mb-1.5 text-xs font-medium text-muted">Example</p>
        <div className="rounded-lg border border-card-border bg-card p-3 font-mono text-xs whitespace-pre-wrap">
          {example}
        </div>
      </div>
    </div>
  );
}

export default function CliReferencePage() {
  return (
    <main className="min-h-screen px-4 py-16 sm:px-6 sm:py-24">
      <div className="mx-auto max-w-2xl">
        <a
          href="/"
          className="mb-8 inline-flex items-center gap-1.5 text-sm text-muted transition-colors hover:text-foreground"
        >
          <ArrowLeft className="h-3.5 w-3.5" />
          Back to home
        </a>

        <h1 className="text-3xl font-bold tracking-tight sm:text-4xl">
          CLI Reference
        </h1>
        <p className="mt-3 text-muted">
          Everything runs through one script:{" "}
          <code className="rounded bg-card px-1.5 py-0.5 font-mono text-xs text-accent">
            ./scripts/auto-agent.sh
          </code>
        </p>

        <div className="mt-10 space-y-6">
          {/* Quick start */}
          <section>
            <h2 className="flex items-center gap-2 text-xl font-semibold">
              <Terminal className="h-5 w-5 text-accent" />
              Quick start
            </h2>
            <div className="mt-4 rounded-lg border border-card-border bg-card p-4 font-mono text-xs">
              <p className="text-muted"># Clone and run your first cycle</p>
              git clone https://github.com/ChetanSarda99/openOrchyStraw.git
              <br />
              cd openOrchyStraw
              <br />
              ./scripts/auto-agent.sh orchestrate 1
            </div>
          </section>

          {/* Commands */}
          <section>
            <h2 className="flex items-center gap-2 text-xl font-semibold">
              <Play className="h-5 w-5 text-accent" />
              Commands
            </h2>
            <div className="mt-4 space-y-4">
              <CommandBlock
                name="orchestrate"
                usage="./scripts/auto-agent.sh orchestrate [max-cycles]"
                description="Run the full orchestration loop. Spawns all agents in parallel per cycle, commits by ownership, runs PM last, merges to main."
                flags={[
                  { flag: "max-cycles", desc: "Number of cycles to run (default: 1). Use 0 for unlimited." },
                ]}
                example={`# Run 5 cycles\n./scripts/auto-agent.sh orchestrate 5\n\n# Run until manually stopped\n./scripts/auto-agent.sh orchestrate 0`}
              />

              <CommandBlock
                name="run"
                usage="./scripts/auto-agent.sh run <agent-id>"
                description="Execute a single agent once. Useful for testing a specific agent's prompt without running the full cycle."
                flags={[
                  { flag: "agent-id", desc: "Agent identifier from agents.conf (e.g., 06-backend, 11-web)." },
                ]}
                example={`# Run just the backend agent\n./scripts/auto-agent.sh run 06-backend\n\n# Run the QA agent\n./scripts/auto-agent.sh run 09-qa`}
              />

              <CommandBlock
                name="list"
                usage="./scripts/auto-agent.sh list"
                description="Show all configured agents with their IDs, prompt paths, ownership boundaries, intervals, and model routing."
                example={`$ ./scripts/auto-agent.sh list\n\nID           INTERVAL  MODEL   OWNERSHIP\n03-pm        0 (coord) claude  prompts/ docs/\n06-backend   1         claude  scripts/ src/core/\n11-web       1         gemini  site/\n09-qa        5         claude  tests/ reports/`}
              />
            </div>
          </section>

          {/* Cycle lifecycle */}
          <section>
            <h2 className="flex items-center gap-2 text-xl font-semibold">
              <RotateCcw className="h-5 w-5 text-accent" />
              Cycle lifecycle
            </h2>
            <div className="mt-4 space-y-3 text-sm leading-relaxed text-foreground/80">
              <p>Each cycle follows this sequence:</p>
              <ol className="list-inside space-y-2">
                {[
                  "Create feature branch (auto/cycle-N-MMDD-HHMM)",
                  "Check rate limits — pause if Claude > 90%",
                  "Back up all agent prompts",
                  "Inject shared context into each agent's prompt",
                  "Spawn worker agents in parallel (respect intervals)",
                  "Wait for all agents to finish",
                  "Run quality gates (syntax, tests, ownership)",
                  "Commit changes by ownership — one commit per agent",
                  "Detect and discard rogue writes",
                  "Run PM agent last (coordinator)",
                  "Merge feature branch to main",
                  "Validate prompts — restore from backup if corrupted",
                  "Update cycle state for resume support",
                ].map((step, i) => (
                  <li key={i} className="flex gap-3">
                    <span className="shrink-0 font-mono text-xs text-accent">
                      {String(i + 1).padStart(2, "0")}
                    </span>
                    {step}
                  </li>
                ))}
              </ol>
            </div>
          </section>

          {/* Configuration */}
          <section>
            <h2 className="flex items-center gap-2 text-xl font-semibold">
              <Settings className="h-5 w-5 text-accent" />
              Configuration
            </h2>
            <div className="mt-4 space-y-4 text-sm leading-relaxed text-foreground/80">
              <p>
                Agents are configured in{" "}
                <code className="rounded bg-card px-1.5 py-0.5 font-mono text-xs text-accent">scripts/agents.conf</code>.
                Each line defines one agent with pipe-delimited fields:
              </p>
              <div className="rounded-lg border border-card-border bg-card p-4 font-mono text-xs whitespace-pre-wrap">
                <p className="text-muted"># id | prompt_path | ownership | interval | label | model</p>
                {`06-backend | prompts/06-backend/06-backend.txt | scripts/ src/core/ src/lib/ | 1 | Backend | claude\n11-web     | prompts/11-web/11-web.txt         | site/                   | 1 | Web    | gemini\n09-qa      | prompts/09-qa/09-qa.txt           | tests/ reports/         | 5 | QA     | claude`}
              </div>
              <div className="space-y-2">
                {[
                  { field: "id", desc: "Unique identifier (e.g., 06-backend)" },
                  { field: "prompt_path", desc: "Path to agent instruction file" },
                  { field: "ownership", desc: "Space-separated paths the agent can write to" },
                  { field: "interval", desc: "0 = coordinator (runs last), 1 = every cycle, N = every Nth cycle" },
                  { field: "label", desc: "Human-readable name" },
                  { field: "model", desc: "LLM routing: claude, codex, or gemini" },
                ].map((f) => (
                  <div key={f.field} className="flex gap-3">
                    <code className="shrink-0 rounded bg-card px-1.5 py-0.5 font-mono text-xs text-accent">
                      {f.field}
                    </code>
                    <span className="text-muted">{f.desc}</span>
                  </div>
                ))}
              </div>
            </div>
          </section>

          {/* List of agents */}
          <section>
            <h2 className="flex items-center gap-2 text-xl font-semibold">
              <List className="h-5 w-5 text-accent" />
              Model routing
            </h2>
            <div className="mt-4 overflow-x-auto rounded-xl border border-card-border">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-card-border bg-card">
                    <th className="px-4 py-3 text-left font-medium text-muted">CLI</th>
                    <th className="px-4 py-3 text-left font-medium text-muted">Model</th>
                    <th className="px-4 py-3 text-left font-medium text-muted">Best for</th>
                  </tr>
                </thead>
                <tbody>
                  {[
                    { cli: "claude", model: "Opus 4.6", use: "Architecture, logic, complex decisions" },
                    { cli: "codex", model: "GPT-5.4", use: "Code review, research" },
                    { cli: "gemini", model: "Gemini 3.1 Pro", use: "UI, layouts, frontend" },
                  ].map((row, i) => (
                    <tr
                      key={row.cli}
                      className={`border-b border-card-border/50 ${i % 2 === 0 ? "bg-card/50" : ""}`}
                    >
                      <td className="px-4 py-3 font-mono text-xs text-accent">{row.cli}</td>
                      <td className="px-4 py-3 text-foreground/90">{row.model}</td>
                      <td className="px-4 py-3 text-muted">{row.use}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </section>
        </div>

        <div className="mt-12 border-t border-card-border pt-8">
          <a
            href="https://github.com/ChetanSarda99/openOrchyStraw"
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-2 rounded-lg bg-accent px-6 py-3 text-sm font-semibold text-accent-foreground transition-colors hover:bg-accent/90"
          >
            Get Started with OrchyStraw
          </a>
        </div>
      </div>
    </main>
  );
}
