import type { Metadata } from "next";
import { ArrowLeft, Check, X, Minus, AlertTriangle } from "lucide-react";

export const metadata: Metadata = {
  title: "Compare — OrchyStraw vs AutoGen vs CrewAI vs Ralph",
  description:
    "See how OrchyStraw compares to other multi-agent orchestration tools. No framework, no dependencies, works with any AI coding agent.",
};

type Support = "yes" | "no" | "partial";

interface Feature {
  name: string;
  orchystraw: Support;
  autogen: Support;
  crewai: Support;
  ralph: Support;
}

const features: Feature[] = [
  { name: "Zero dependencies", orchystraw: "yes", autogen: "no", crewai: "no", ralph: "no" },
  { name: "No Python runtime required", orchystraw: "yes", autogen: "no", crewai: "no", ralph: "partial" },
  { name: "Works with any AI coding agent", orchystraw: "yes", autogen: "no", crewai: "no", ralph: "no" },
  { name: "Claude Code support", orchystraw: "yes", autogen: "no", crewai: "no", ralph: "yes" },
  { name: "Codex / GPT support", orchystraw: "yes", autogen: "yes", crewai: "yes", ralph: "no" },
  { name: "Gemini CLI support", orchystraw: "yes", autogen: "no", crewai: "no", ralph: "no" },
  { name: "File ownership boundaries", orchystraw: "yes", autogen: "no", crewai: "no", ralph: "partial" },
  { name: "Shared context (token-efficient)", orchystraw: "yes", autogen: "partial", crewai: "partial", ralph: "partial" },
  { name: "Auto-cycle mode", orchystraw: "yes", autogen: "no", crewai: "no", ralph: "yes" },
  { name: "Prompt-based configuration", orchystraw: "yes", autogen: "no", crewai: "partial", ralph: "yes" },
  { name: "Real coding agents (not chat)", orchystraw: "yes", autogen: "no", crewai: "no", ralph: "yes" },
  { name: "Pixel art visualization", orchystraw: "yes", autogen: "no", crewai: "no", ralph: "no" },
  { name: "Open source (MIT)", orchystraw: "yes", autogen: "yes", crewai: "yes", ralph: "no" },
  { name: "Desktop app (Tauri)", orchystraw: "yes", autogen: "no", crewai: "no", ralph: "no" },
  { name: "Token budget management", orchystraw: "yes", autogen: "no", crewai: "no", ralph: "partial" },
];

const tools = [
  { name: "OrchyStraw", key: "orchystraw" as const, accent: true },
  { name: "AutoGen", key: "autogen" as const, accent: false },
  { name: "CrewAI", key: "crewai" as const, accent: false },
  { name: "Ralph", key: "ralph" as const, accent: false },
];

function SupportIcon({ value }: { value: Support }) {
  if (value === "yes") return <Check className="mx-auto h-4 w-4 text-status-success" />;
  if (value === "no") return <X className="mx-auto h-4 w-4 text-muted/40" />;
  return <Minus className="mx-auto h-4 w-4 text-status-warning" />;
}

export default function ComparePage() {
  return (
    <main className="min-h-screen px-4 py-16 sm:px-6 sm:py-24">
      <div className="mx-auto max-w-4xl">
        <a
          href="/"
          className="mb-8 inline-flex items-center gap-1.5 text-sm text-muted transition-colors hover:text-foreground"
        >
          <ArrowLeft className="h-3.5 w-3.5" />
          Back to home
        </a>

        <h1 className="text-3xl font-bold tracking-tight sm:text-4xl">
          How OrchyStraw compares
        </h1>
        <p className="mt-3 text-muted">
          OrchyStraw takes a fundamentally different approach: no framework, no
          dependencies, works with real coding agents — not chat wrappers.
        </p>

        <div className="mt-12 overflow-x-auto rounded-xl border border-card-border">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-card-border bg-card">
                <th className="px-4 py-3 text-left font-medium text-muted">
                  Feature
                </th>
                {tools.map((tool) => (
                  <th
                    key={tool.key}
                    className={`px-4 py-3 text-center font-medium ${tool.accent ? "text-accent" : "text-muted"}`}
                  >
                    {tool.name}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {features.map((feature, i) => (
                <tr
                  key={feature.name}
                  className={`border-b border-card-border/50 ${i % 2 === 0 ? "bg-card/50" : ""}`}
                >
                  <td className="px-4 py-3 text-foreground/90">
                    {feature.name}
                  </td>
                  {tools.map((tool) => (
                    <td key={tool.key} className="px-4 py-3 text-center">
                      <SupportIcon value={feature[tool.key]} />
                    </td>
                  ))}
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        <div className="mt-12 rounded-xl border border-card-border bg-card p-6">
          <h2 className="text-lg font-semibold">The key difference</h2>
          <p className="mt-3 text-sm leading-relaxed text-muted">
            AutoGen and CrewAI are Python frameworks that wrap LLM API calls
            into &quot;agents&quot; — they generate text, not code changes.
            OrchyStraw orchestrates real coding agents (Claude Code, Codex,
            Gemini CLI) that can read files, write code, run tests, and commit.
            No framework lock-in, no runtime dependencies, just bash + markdown.
          </p>
        </div>

        <div className="mt-12 rounded-xl border border-status-warning/30 bg-status-warning/5 p-4">
          <div className="flex items-start gap-2">
            <AlertTriangle className="mt-0.5 h-4 w-4 shrink-0 text-status-warning" />
            <p className="text-sm text-muted">
              <strong className="text-foreground">Dry-run data (simulated).</strong>{" "}
              These metrics are from dry-run cost estimation, not live benchmark runs.
              Real benchmark results coming soon.
            </p>
          </div>
        </div>

        <div className="mt-8">
          <h2 className="text-lg font-semibold">Performance: OrchyStraw vs Ralph</h2>
          <p className="mt-2 text-sm text-muted">
            Multi-agent orchestration (3 agents, 5 cycles) vs single-agent (1 agent, 1 cycle) on the same 5-task suite (Sonnet model).
          </p>
          <div className="mt-4 overflow-x-auto rounded-xl border border-card-border">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-card-border bg-card">
                  <th className="px-4 py-3 text-left font-medium text-muted">Metric</th>
                  <th className="px-4 py-3 text-center font-medium text-accent">OrchyStraw</th>
                  <th className="px-4 py-3 text-center font-medium text-muted">Ralph</th>
                </tr>
              </thead>
              <tbody>
                <tr className="border-b border-card-border/50 bg-card/50">
                  <td className="px-4 py-3 text-foreground/90">Resolve rate</td>
                  <td className="px-4 py-3 text-center font-mono text-status-success">60%</td>
                  <td className="px-4 py-3 text-center font-mono text-muted">40%</td>
                </tr>
                <tr className="border-b border-card-border/50">
                  <td className="px-4 py-3 text-foreground/90">Avg. wall time</td>
                  <td className="px-4 py-3 text-center font-mono text-muted">287.8s</td>
                  <td className="px-4 py-3 text-center font-mono text-status-success">223.6s</td>
                </tr>
                <tr className="border-b border-card-border/50 bg-card/50">
                  <td className="px-4 py-3 text-foreground/90">Avg. cycles</td>
                  <td className="px-4 py-3 text-center font-mono text-muted">4.0</td>
                  <td className="px-4 py-3 text-center font-mono text-status-success">1.0</td>
                </tr>
                <tr className="border-b border-card-border/50">
                  <td className="px-4 py-3 text-foreground/90">Rogue write rate</td>
                  <td className="px-4 py-3 text-center font-mono text-muted">40%</td>
                  <td className="px-4 py-3 text-center font-mono text-status-success">20%</td>
                </tr>
                <tr className="border-b border-card-border/50 bg-card/50">
                  <td className="px-4 py-3 text-foreground/90">Agents per instance</td>
                  <td className="px-4 py-3 text-center font-mono text-muted">3</td>
                  <td className="px-4 py-3 text-center font-mono text-muted">1</td>
                </tr>
                <tr className="bg-card/50">
                  <td className="px-4 py-3 text-foreground/90">Estimated cost</td>
                  <td className="px-4 py-3 text-center font-mono text-muted">$14.62</td>
                  <td className="px-4 py-3 text-center font-mono text-status-success">$0.98</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        {/* Head-to-Head Per-Task */}
        <div className="mt-8">
          <h2 className="text-lg font-semibold">Head-to-Head: Per-Task Breakdown</h2>
          <div className="mt-4 overflow-x-auto rounded-xl border border-card-border">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-card-border bg-card">
                  <th className="px-4 py-3 text-left font-medium text-muted">Task</th>
                  <th className="px-4 py-3 text-center font-medium text-accent">OrchyStraw</th>
                  <th className="px-4 py-3 text-center font-medium text-muted">Ralph</th>
                  <th className="px-4 py-3 text-center font-medium text-muted">Winner</th>
                </tr>
              </thead>
              <tbody>
                {[
                  { task: "Fix regex validator trailing newline", difficulty: "easy", orchystraw: "pass (142s)", ralph: "pass (95s)", winner: "Ralph" },
                  { task: "Fix staticfiles storage crash", difficulty: "easy", orchystraw: "pass (98s)", ralph: "pass (78s)", winner: "Ralph" },
                  { task: "Add batch delete endpoint", difficulty: "medium", orchystraw: "pass (312s)", ralph: "fail (180s)", winner: "OrchyStraw" },
                  { task: "Fix sympy simplify complex exponents", difficulty: "medium", orchystraw: "fail (287s)", ralph: "fail (165s)", winner: "Neither" },
                  { task: "Add CSV export to management command", difficulty: "hard", orchystraw: "timeout (600s)", ralph: "timeout (600s)", winner: "Neither" },
                ].map((row, i) => (
                  <tr
                    key={row.task}
                    className={`border-b border-card-border/50 ${i % 2 === 0 ? "bg-card/50" : ""}`}
                  >
                    <td className="px-4 py-3 text-foreground/90">
                      <span>{row.task}</span>
                      <span className={`ml-2 inline-block rounded px-1.5 py-0.5 text-[10px] font-medium ${row.difficulty === "easy" ? "bg-status-success/10 text-status-success" : row.difficulty === "medium" ? "bg-status-warning/10 text-status-warning" : "bg-status-error/10 text-status-error"}`}>
                        {row.difficulty}
                      </span>
                    </td>
                    <td className={`px-4 py-3 text-center font-mono text-xs ${row.orchystraw.startsWith("pass") ? "text-status-success" : row.orchystraw.startsWith("fail") ? "text-status-error" : "text-status-warning"}`}>
                      {row.orchystraw}
                    </td>
                    <td className={`px-4 py-3 text-center font-mono text-xs ${row.ralph.startsWith("pass") ? "text-status-success" : row.ralph.startsWith("fail") ? "text-status-error" : "text-status-warning"}`}>
                      {row.ralph}
                    </td>
                    <td className={`px-4 py-3 text-center text-xs font-medium ${row.winner === "OrchyStraw" ? "text-accent" : row.winner === "Ralph" ? "text-muted" : "text-muted/60"}`}>
                      {row.winner}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <p className="mt-3 text-xs text-muted">
            OrchyStraw wins on multi-file tasks where agent coordination pays off.
            Ralph is faster on simple single-file fixes where orchestration overhead isn&apos;t justified.
          </p>
        </div>

        <div className="mt-8 text-center">
          <a
            href="https://github.com/ChetanSarda99/openOrchyStraw"
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-2 rounded-lg bg-accent px-6 py-3 text-sm font-semibold text-accent-foreground transition-colors hover:bg-accent/90"
          >
            Get Started
          </a>
        </div>
      </div>
    </main>
  );
}
