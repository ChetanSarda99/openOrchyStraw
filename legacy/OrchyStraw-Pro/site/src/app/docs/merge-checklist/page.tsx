import type { Metadata } from "next";
import { ArrowLeft, ShieldCheck, FolderLock, TestTube, FileCheck, Ban, AlertTriangle } from "lucide-react";

export const metadata: Metadata = {
  title: "Merge Checklist — OrchyStraw Docs",
  description:
    "OrchyStraw enforces quality gates before merging: syntax checks, test suites, file ownership validation, and code reviews.",
};

export default function MergeChecklistPage() {
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
          Merge Checklist
        </h1>
        <p className="mt-3 text-muted">
          Every cycle passes through quality gates before changes reach main.
          Blocking gates must pass — no exceptions, no overrides.
        </p>

        <div className="mt-10 space-y-8">
          {/* Overview */}
          <section>
            <h2 className="flex items-center gap-2 text-xl font-semibold">
              <ShieldCheck className="h-5 w-5 text-accent" />
              How quality gates work
            </h2>
            <div className="mt-4 space-y-4 text-sm leading-relaxed text-foreground/80">
              <p>
                After agents finish their work, the orchestrator runs a series of{" "}
                <strong>quality gates</strong> before committing. Each gate is either{" "}
                <span className="text-status-error font-semibold">blocking</span> (must
                pass) or <span className="text-status-warning font-semibold">warning</span>{" "}
                (logged but non-blocking).
              </p>
              <p>
                If any blocking gate fails, the cycle&apos;s changes are not merged.
                The orchestrator logs the failure and moves on.
              </p>
            </div>
          </section>

          {/* Gate table */}
          <section>
            <h2 className="text-xl font-semibold">Built-in gates</h2>
            <div className="mt-4 overflow-x-auto rounded-xl border border-card-border">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-card-border bg-card">
                    <th className="px-4 py-3 text-left font-medium text-muted">Gate</th>
                    <th className="px-4 py-3 text-left font-medium text-muted">What it checks</th>
                    <th className="px-4 py-3 text-center font-medium text-muted">Severity</th>
                  </tr>
                </thead>
                <tbody>
                  {[
                    { gate: "syntax", desc: "bash -n on all .sh files", severity: "blocking" },
                    { gate: "shellcheck", desc: "Lint .sh files for common issues", severity: "warning" },
                    { gate: "test", desc: "Run test suite (tests/core/run-tests.sh)", severity: "blocking" },
                    { gate: "ownership", desc: "Validate writes stay within agent boundaries", severity: "blocking" },
                  ].map((row, i) => (
                    <tr
                      key={row.gate}
                      className={`border-b border-card-border/50 ${i % 2 === 0 ? "bg-card/50" : ""}`}
                    >
                      <td className="px-4 py-3 font-mono text-xs text-accent">{row.gate}</td>
                      <td className="px-4 py-3 text-foreground/90">{row.desc}</td>
                      <td className="px-4 py-3 text-center">
                        <span
                          className={`inline-block rounded-full px-2.5 py-0.5 text-xs font-medium ${
                            row.severity === "blocking"
                              ? "bg-status-error/10 text-status-error"
                              : "bg-status-warning/10 text-status-warning"
                          }`}
                        >
                          {row.severity}
                        </span>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </section>

          {/* File ownership */}
          <section>
            <h2 className="flex items-center gap-2 text-xl font-semibold">
              <FolderLock className="h-5 w-5 text-accent" />
              File ownership enforcement
            </h2>
            <div className="mt-4 space-y-4 text-sm leading-relaxed text-foreground/80">
              <p>
                Each agent owns specific paths defined in{" "}
                <code className="rounded bg-card px-1.5 py-0.5 font-mono text-xs text-accent">agents.conf</code>.
                The file access system enforces four zones:
              </p>
              <div className="space-y-2">
                {[
                  { zone: "Protected", desc: "Never modifiable — auto-agent.sh, agents.conf, CLAUDE.md", icon: <Ban className="h-4 w-4 text-status-error" /> },
                  { zone: "Owned", desc: "Agent's assigned paths — full read-write access", icon: <FileCheck className="h-4 w-4 text-status-success" /> },
                  { zone: "Shared", desc: "Cross-agent communication — prompts/00-shared-context/", icon: <AlertTriangle className="h-4 w-4 text-status-warning" /> },
                  { zone: "Unowned", desc: "Another agent's paths — read-only", icon: <FolderLock className="h-4 w-4 text-muted" /> },
                ].map((z) => (
                  <div key={z.zone} className="flex items-start gap-3 rounded-lg border border-card-border bg-card p-3">
                    {z.icon}
                    <div>
                      <span className="font-semibold text-foreground">{z.zone}</span>
                      <span className="ml-2 text-muted">{z.desc}</span>
                    </div>
                  </div>
                ))}
              </div>
              <p>
                If an agent writes outside its ownership, the orchestrator detects
                the rogue write and discards it before committing. Protected files
                are automatically restored if modified.
              </p>
            </div>
          </section>

          {/* Tests */}
          <section>
            <h2 className="flex items-center gap-2 text-xl font-semibold">
              <TestTube className="h-5 w-5 text-accent" />
              Test gate
            </h2>
            <div className="mt-4 space-y-4 text-sm leading-relaxed text-foreground/80">
              <p>
                The test gate runs the full test suite. All tests must pass
                before changes are committed:
              </p>
              <div className="rounded-lg border border-card-border bg-card p-4 font-mono text-xs">
                <p className="text-muted"># What the orchestrator runs</p>
                orch_gate_run test
                <br /><br />
                <p className="text-muted"># This executes tests/core/run-tests.sh</p>
                <p className="text-muted"># Which runs all unit + integration tests</p>
                <p className="text-muted"># Current suite: 32 unit + 42 integration assertions</p>
              </div>
              <p>
                Gates run with a 60-second timeout. If a gate hangs, it&apos;s
                automatically killed and marked as failed.
              </p>
            </div>
          </section>

          {/* Code review */}
          <section>
            <h2 className="flex items-center gap-2 text-xl font-semibold">
              <ShieldCheck className="h-5 w-5 text-accent" />
              Code review phase
            </h2>
            <div className="mt-4 space-y-4 text-sm leading-relaxed text-foreground/80">
              <p>
                After gates pass, assigned reviewers critique agent diffs. Reviews
                are read-only — reviewers cannot modify code, only issue verdicts:
              </p>
              <div className="mt-3 grid gap-2 sm:grid-cols-3">
                {[
                  { verdict: "approve", color: "text-status-success bg-status-success/10" },
                  { verdict: "request-changes", color: "text-status-error bg-status-error/10" },
                  { verdict: "comment", color: "text-status-warning bg-status-warning/10" },
                ].map((v) => (
                  <div key={v.verdict} className={`rounded-lg px-3 py-2 text-center font-mono text-xs ${v.color}`}>
                    {v.verdict}
                  </div>
                ))}
              </div>
              <p>
                Trivial changes (under 5 lines, prompts/docs only) can be
                auto-approved to save reviewer tokens.
              </p>
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
