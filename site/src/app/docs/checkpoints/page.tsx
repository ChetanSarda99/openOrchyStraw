import type { Metadata } from "next";
import { ArrowLeft, Check, X, Minus, GitCommit, RotateCcw, History } from "lucide-react";

export const metadata: Metadata = {
  title: "Checkpoints — OrchyStraw Docs",
  description:
    "OrchyStraw uses git commits as automatic checkpoints. Every cycle creates a snapshot you can inspect, revert, or diff.",
};

const comparison = [
  { feature: "Automatic snapshots", orchystraw: "yes", conductor: "yes" },
  { feature: "Per-agent diffs", orchystraw: "yes", conductor: "partial" },
  { feature: "Revert to any cycle", orchystraw: "yes", conductor: "yes" },
  { feature: "No proprietary format", orchystraw: "yes", conductor: "no" },
  { feature: "Works with any git host", orchystraw: "yes", conductor: "partial" },
  { feature: "Branch-per-cycle option", orchystraw: "yes", conductor: "no" },
  { feature: "Zero config required", orchystraw: "yes", conductor: "no" },
  { feature: "Standard git tooling", orchystraw: "yes", conductor: "no" },
] as const;

type Support = "yes" | "no" | "partial";

function SupportIcon({ value }: { value: Support }) {
  if (value === "yes") return <Check className="mx-auto h-4 w-4 text-green-400" />;
  if (value === "no") return <X className="mx-auto h-4 w-4 text-muted/40" />;
  return <Minus className="mx-auto h-4 w-4 text-yellow-400" />;
}

export default function CheckpointsPage() {
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
          Checkpoints
        </h1>
        <p className="mt-3 text-muted">
          Every orchestration cycle automatically creates a git commit — a
          checkpoint you can inspect, compare, or roll back to at any time.
        </p>

        <div className="mt-10 space-y-8">
          {/* How it works */}
          <section>
            <h2 className="flex items-center gap-2 text-xl font-semibold">
              <GitCommit className="h-5 w-5 text-accent" />
              How checkpoints work
            </h2>
            <div className="mt-4 space-y-4 text-sm leading-relaxed text-foreground/80">
              <p>
                When <code className="rounded bg-card px-1.5 py-0.5 font-mono text-xs text-accent">auto-agent.sh</code> finishes
                a cycle, it commits all agent changes with a structured message:
              </p>
              <div className="rounded-lg border border-card-border bg-card p-4 font-mono text-xs">
                <span className="text-muted">$</span> git log --oneline
                <br />
                <span className="text-accent">a3f1c2d</span> chore: auto-update all prompts — cycle 5 (12 files, 3 components)
                <br />
                <span className="text-accent">b7e4d1a</span> chore: auto-update all prompts — cycle 4 (8 files, 2 components)
                <br />
                <span className="text-accent">c9a2f3e</span> chore: auto-update all prompts — cycle 3 (15 files, 4 components)
              </div>
              <p>
                Each commit message includes the cycle number, file count, and
                component count — so you can scan the log and know exactly what
                changed per cycle without opening a diff.
              </p>
            </div>
          </section>

          {/* Viewing checkpoints */}
          <section>
            <h2 className="flex items-center gap-2 text-xl font-semibold">
              <History className="h-5 w-5 text-accent" />
              Viewing checkpoints
            </h2>
            <div className="mt-4 space-y-4 text-sm leading-relaxed text-foreground/80">
              <p>Use standard git commands to inspect any checkpoint:</p>
              <div className="space-y-3">
                <div className="rounded-lg border border-card-border bg-card p-4 font-mono text-xs">
                  <p className="text-muted"># List all cycle checkpoints</p>
                  git log --oneline --grep=&quot;auto-update&quot;
                </div>
                <div className="rounded-lg border border-card-border bg-card p-4 font-mono text-xs">
                  <p className="text-muted"># See what changed in a specific cycle</p>
                  git show &lt;commit-hash&gt; --stat
                </div>
                <div className="rounded-lg border border-card-border bg-card p-4 font-mono text-xs">
                  <p className="text-muted"># Diff between two cycles</p>
                  git diff &lt;cycle-3-hash&gt;..&lt;cycle-5-hash&gt;
                </div>
              </div>
            </div>
          </section>

          {/* Reverting */}
          <section>
            <h2 className="flex items-center gap-2 text-xl font-semibold">
              <RotateCcw className="h-5 w-5 text-accent" />
              Reverting to a checkpoint
            </h2>
            <div className="mt-4 space-y-4 text-sm leading-relaxed text-foreground/80">
              <p>
                If an agent introduces a regression or you want to undo a
                cycle&apos;s changes, use{" "}
                <code className="rounded bg-card px-1.5 py-0.5 font-mono text-xs text-accent">git revert</code>:
              </p>
              <div className="rounded-lg border border-card-border bg-card p-4 font-mono text-xs">
                <p className="text-muted"># Revert a single cycle (creates a new commit)</p>
                git revert &lt;cycle-commit-hash&gt;
                <br /><br />
                <p className="text-muted"># Revert multiple cycles</p>
                git revert &lt;oldest-hash&gt;..&lt;newest-hash&gt;
              </div>
              <p>
                Because checkpoints are standard git commits, you get the full
                power of git: cherry-pick individual agent changes, bisect to
                find which cycle broke something, or branch off from any
                checkpoint to try a different approach.
              </p>
            </div>
          </section>

          {/* Comparison table */}
          <section>
            <h2 className="text-xl font-semibold">
              OrchyStraw vs Conductor checkpoints
            </h2>
            <p className="mt-2 text-sm text-muted">
              Conductor uses a proprietary checkpoint format. OrchyStraw uses
              plain git — no lock-in, no special tooling.
            </p>
            <div className="mt-4 overflow-x-auto rounded-xl border border-card-border">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-card-border bg-card">
                    <th className="px-4 py-3 text-left font-medium text-muted">
                      Feature
                    </th>
                    <th className="px-4 py-3 text-center font-medium text-accent">
                      OrchyStraw
                    </th>
                    <th className="px-4 py-3 text-center font-medium text-muted">
                      Conductor
                    </th>
                  </tr>
                </thead>
                <tbody>
                  {comparison.map((row, i) => (
                    <tr
                      key={row.feature}
                      className={`border-b border-card-border/50 ${i % 2 === 0 ? "bg-card/50" : ""}`}
                    >
                      <td className="px-4 py-3 text-foreground/90">
                        {row.feature}
                      </td>
                      <td className="px-4 py-3 text-center">
                        <SupportIcon value={row.orchystraw} />
                      </td>
                      <td className="px-4 py-3 text-center">
                        <SupportIcon value={row.conductor} />
                      </td>
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
