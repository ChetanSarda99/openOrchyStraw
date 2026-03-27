import type { Metadata } from "next";
import { ArrowLeft, BarChart3, Clock, DollarSign, Trophy, Users, Zap, AlertTriangle, ShieldAlert } from "lucide-react";

export const metadata: Metadata = {
  title: "Benchmarks — OrchyStraw Performance Results",
  description:
    "SWE-bench and FeatureBench dry-run results for OrchyStraw multi-agent orchestration. See how coordinated AI agents compare to single-agent workflows.",
};

interface SuiteResult {
  suite: string;
  tasks: number;
  model: string;
  agents: number;
  maxCycles: number;
  resolveRate: string;
  avgTime: string;
  rogueWriteRate: string;
  cost: string;
}

const suiteResults: SuiteResult[] = [
  { suite: "Custom Suite", tasks: 5, model: "Sonnet", agents: 1, maxCycles: 5, resolveRate: "60%", avgTime: "287.8s", rogueWriteRate: "40%", cost: "$4.88" },
  { suite: "Custom Suite", tasks: 5, model: "Opus", agents: 1, maxCycles: 5, resolveRate: "60%", avgTime: "287.8s", rogueWriteRate: "40%", cost: "$24.38" },
  { suite: "SWE-bench Lite", tasks: 40, model: "Sonnet", agents: 1, maxCycles: 5, resolveRate: "—", avgTime: "—", rogueWriteRate: "—", cost: "$39.00" },
  { suite: "FeatureBench", tasks: 5, model: "Sonnet", agents: 3, maxCycles: 5, resolveRate: "60%", avgTime: "275.2s", rogueWriteRate: "40%", cost: "$14.62" },
  { suite: "FeatureBench", tasks: 5, model: "Opus", agents: 3, maxCycles: 5, resolveRate: "60%", avgTime: "275.2s", rogueWriteRate: "40%", cost: "$73.12" },
];

interface CompareRow {
  metric: string;
  orchystraw: string;
  ralph: string;
  winner: "orchystraw" | "ralph" | "tie";
}

const compareRows: CompareRow[] = [
  { metric: "Resolve rate", orchystraw: "60%", ralph: "40%", winner: "orchystraw" },
  { metric: "Avg. wall time", orchystraw: "287.8s", ralph: "223.6s", winner: "ralph" },
  { metric: "Avg. cycles", orchystraw: "4.0", ralph: "1.0", winner: "ralph" },
  { metric: "Rogue write rate", orchystraw: "40%", ralph: "20%", winner: "ralph" },
  { metric: "Agents per instance", orchystraw: "3", ralph: "1", winner: "tie" },
  { metric: "Estimated cost", orchystraw: "$14.62", ralph: "$0.98", winner: "ralph" },
];

interface HeadToHead {
  task: string;
  orchystraw: string;
  ralph: string;
  winner: string;
}

const headToHead: HeadToHead[] = [
  { task: "custom-001 — Fix regex validator trailing newline", orchystraw: "pass (142s)", ralph: "pass (95s)", winner: "Ralph" },
  { task: "custom-002 — Fix staticfiles storage crash", orchystraw: "pass (98s)", ralph: "pass (78s)", winner: "Ralph" },
  { task: "custom-003 — Add batch delete endpoint", orchystraw: "pass (312s)", ralph: "fail (180s)", winner: "OrchyStraw" },
  { task: "custom-004 — Fix sympy simplify complex exponents", orchystraw: "fail (287s)", ralph: "fail (165s)", winner: "Neither" },
  { task: "custom-005 — Add CSV export to management command", orchystraw: "timeout (600s)", ralph: "timeout (600s)", winner: "Neither" },
];

interface StatCard {
  label: string;
  value: string;
  icon: React.ElementType;
  note: string;
}

const stats: StatCard[] = [
  { label: "Resolve Rate", value: "60%", icon: Trophy, note: "Custom + FeatureBench (dry-run)" },
  { label: "Avg. Cycle Time", value: "287.8s", icon: Clock, note: "~4.8 min per task (dry-run)" },
  { label: "vs Single Agent", value: "+50%", icon: Zap, note: "60% vs 40% resolve rate" },
  { label: "Rogue Write Rate", value: "40%", icon: ShieldAlert, note: "Writes outside owned files" },
];

export default function BenchmarksPage() {
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
          Benchmarks
        </h1>
        <p className="mt-3 text-muted">
          How does multi-agent orchestration compare to single-agent workflows?
          Dry-run results from our benchmark suites.
        </p>

        {/* Dry-run disclaimer */}
        <div className="mt-8 rounded-xl border border-status-warning/30 bg-status-warning/5 p-4">
          <div className="flex items-start gap-2">
            <AlertTriangle className="mt-0.5 h-4 w-4 shrink-0 text-status-warning" />
            <p className="text-sm text-muted">
              <strong className="text-foreground">Dry-run data (simulated).</strong>{" "}
              These metrics are from dry-run cost estimation and simulated benchmarks,
              not live runs. Real benchmark results coming soon.
            </p>
          </div>
        </div>

        {/* Stat cards */}
        <div className="mt-8 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          {stats.map((stat) => (
            <div
              key={stat.label}
              className="rounded-xl border border-card-border bg-card p-5"
            >
              <div className="flex items-center gap-2 text-sm text-muted">
                <stat.icon className="h-4 w-4" />
                {stat.label}
              </div>
              <div className="mt-2 text-2xl font-bold">{stat.value}</div>
              <div className="mt-1 text-xs text-muted">{stat.note}</div>
            </div>
          ))}
        </div>

        {/* Suite Results Table */}
        <div className="mt-12">
          <h2 className="text-lg font-semibold">Suite Results</h2>
          <div className="mt-4 overflow-x-auto rounded-xl border border-card-border">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-card-border bg-card">
                  <th className="px-4 py-3 text-left font-medium text-muted">Suite</th>
                  <th className="px-4 py-3 text-center font-medium text-muted">Tasks</th>
                  <th className="px-4 py-3 text-center font-medium text-muted">Model</th>
                  <th className="px-4 py-3 text-center font-medium text-muted">Agents</th>
                  <th className="px-4 py-3 text-center font-medium text-accent">Resolve</th>
                  <th className="px-4 py-3 text-center font-medium text-muted">Avg. Time</th>
                  <th className="px-4 py-3 text-center font-medium text-muted">Rogue Writes</th>
                  <th className="px-4 py-3 text-center font-medium text-muted">Est. Cost</th>
                </tr>
              </thead>
              <tbody>
                {suiteResults.map((row, i) => (
                  <tr
                    key={`${row.suite}-${row.model}`}
                    className={`border-b border-card-border/50 ${i % 2 === 0 ? "bg-card/50" : ""}`}
                  >
                    <td className="px-4 py-3 text-foreground/90">{row.suite}</td>
                    <td className="px-4 py-3 text-center font-mono text-muted">{row.tasks}</td>
                    <td className="px-4 py-3 text-center text-muted">{row.model}</td>
                    <td className="px-4 py-3 text-center font-mono text-muted">{row.agents}</td>
                    <td className="px-4 py-3 text-center font-mono text-accent">{row.resolveRate}</td>
                    <td className="px-4 py-3 text-center font-mono text-muted">{row.avgTime}</td>
                    <td className="px-4 py-3 text-center font-mono text-muted">{row.rogueWriteRate}</td>
                    <td className="px-4 py-3 text-center font-mono text-muted">{row.cost}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>

        {/* OrchyStraw vs Ralph */}
        <div className="mt-12">
          <h2 className="text-lg font-semibold">OrchyStraw vs Ralph</h2>
          <p className="mt-2 text-sm text-muted">
            Multi-agent orchestration (3 agents, 5 cycles) vs single-agent (1 agent, 1 cycle) on the same 5-task suite.
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
                {compareRows.map((row, i) => (
                  <tr
                    key={row.metric}
                    className={`border-b border-card-border/50 ${i % 2 === 0 ? "bg-card/50" : ""}`}
                  >
                    <td className="px-4 py-3 text-foreground/90">{row.metric}</td>
                    <td className={`px-4 py-3 text-center font-mono ${row.winner === "orchystraw" ? "text-status-success" : "text-muted"}`}>
                      {row.orchystraw}
                    </td>
                    <td className={`px-4 py-3 text-center font-mono ${row.winner === "ralph" ? "text-status-success" : "text-muted"}`}>
                      {row.ralph}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <p className="mt-3 text-xs text-muted">
            OrchyStraw resolves 60% vs Ralph 40% — multi-agent wins on harder multi-file tasks.
            Ralph is faster and cheaper on simple single-file fixes.
          </p>
        </div>

        {/* Head-to-Head Task Results */}
        <div className="mt-12">
          <h2 className="text-lg font-semibold">Head-to-Head: Per-Task Results</h2>
          <p className="mt-2 text-sm text-muted">
            Task-level breakdown of OrchyStraw (3 agents) vs Ralph (single agent) on 5 custom tasks.
          </p>
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
                {headToHead.map((row, i) => (
                  <tr
                    key={row.task}
                    className={`border-b border-card-border/50 ${i % 2 === 0 ? "bg-card/50" : ""}`}
                  >
                    <td className="px-4 py-3 text-foreground/90 text-xs">{row.task}</td>
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
            OrchyStraw wins on multi-file tasks (custom-003) where agent coordination pays off.
            Ralph wins on simple single-file fixes where overhead is minimal.
          </p>
        </div>

        {/* Cost Breakdown */}
        <div className="mt-12">
          <h2 className="text-lg font-semibold">Cost Estimates</h2>
          <div className="mt-4 grid gap-4 sm:grid-cols-2">
            <div className="rounded-xl border border-card-border bg-card p-5">
              <div className="flex items-center gap-2 text-sm text-muted">
                <DollarSign className="h-4 w-4" />
                Sonnet (budget)
              </div>
              <div className="mt-3 space-y-2 text-sm">
                <div className="flex justify-between"><span className="text-muted">Custom Suite (5 tasks)</span><span className="font-mono">$4.88</span></div>
                <div className="flex justify-between"><span className="text-muted">FeatureBench (5 tasks)</span><span className="font-mono">$14.62</span></div>
                <div className="flex justify-between"><span className="text-muted">SWE-bench Lite (40 tasks)</span><span className="font-mono">$39.00</span></div>
              </div>
            </div>
            <div className="rounded-xl border border-card-border bg-card p-5">
              <div className="flex items-center gap-2 text-sm text-muted">
                <DollarSign className="h-4 w-4" />
                Opus (premium)
              </div>
              <div className="mt-3 space-y-2 text-sm">
                <div className="flex justify-between"><span className="text-muted">Custom Suite (5 tasks)</span><span className="font-mono">$24.38</span></div>
                <div className="flex justify-between"><span className="text-muted">FeatureBench (5 tasks)</span><span className="font-mono">$73.12</span></div>
                <div className="flex justify-between"><span className="text-muted">SWE-bench Lite (40 tasks)</span><span className="font-mono text-muted/60">TBD</span></div>
              </div>
            </div>
          </div>
        </div>

        {/* Methodology */}
        <div className="mt-12 rounded-xl border border-card-border bg-card p-6">
          <h2 className="text-lg font-semibold">Methodology</h2>
          <div className="mt-3 space-y-3 text-sm leading-relaxed text-muted">
            <p>
              <strong className="text-foreground">Custom Suite:</strong> 5
              curated tasks covering bug fixes, feature additions, and
              multi-file refactors. Single-agent baseline with up to 5 cycles.
            </p>
            <p>
              <strong className="text-foreground">SWE-bench Lite:</strong> 40
              real-world GitHub issues from the standard SWE-bench evaluation.
              OrchyStraw orchestrates a team of agents (backend, QA, PM).
            </p>
            <p>
              <strong className="text-foreground">FeatureBench:</strong> Our
              internal benchmark for multi-file feature implementation. 3 agents
              per instance, coordinated changes across frontend, backend, and tests.
            </p>
            <p>
              <strong className="text-foreground">Fair comparison:</strong> Same
              model, same token budget, same codebase. The only variable is
              orchestration strategy (multi-agent vs single-agent).
            </p>
          </div>
        </div>

        <div className="mt-12 rounded-xl border border-dashed border-accent/30 bg-accent/5 p-6 text-center">
          <p className="text-sm text-muted">
            Live benchmark results coming soon. Star the repo to get notified.
          </p>
          <a
            href="https://github.com/ChetanSarda99/OrchyStraw-Pro"
            target="_blank"
            rel="noopener noreferrer"
            className="mt-4 inline-flex items-center gap-2 rounded-lg bg-accent px-6 py-3 text-sm font-semibold text-accent-foreground transition-colors hover:bg-accent/90"
          >
            Star on GitHub
          </a>
        </div>
      </div>
    </main>
  );
}
