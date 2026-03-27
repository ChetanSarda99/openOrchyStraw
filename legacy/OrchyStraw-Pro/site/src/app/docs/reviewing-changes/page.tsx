import type { Metadata } from "next";
import { ArrowLeft, GitBranch, User, Layers } from "lucide-react";

export const metadata: Metadata = {
  title: "Reviewing Changes — OrchyStraw Docs",
  description:
    "How to review agent changes per cycle, per agent, or cumulatively using standard git diff workflows.",
};

const steps = [
  {
    icon: Layers,
    title: "1. Review the full cycle",
    description:
      "See everything that changed in a single orchestration cycle — all agents combined.",
    commands: [
      { label: "Diff the latest cycle commit against its parent", cmd: "git diff HEAD~1" },
      { label: "See file-level summary", cmd: "git show HEAD --stat" },
    ],
  },
  {
    icon: User,
    title: "2. Review per agent",
    description:
      "Each agent's changes are scoped to their owned files. Filter the diff to see what a specific agent touched.",
    commands: [
      { label: "Backend agent changes (src/core/)", cmd: "git diff HEAD~1 -- src/core/" },
      { label: "Web agent changes (site/)", cmd: "git diff HEAD~1 -- site/" },
      { label: "iOS agent changes (ios/)", cmd: "git diff HEAD~1 -- ios/" },
    ],
  },
  {
    icon: GitBranch,
    title: "3. Review cumulative progress",
    description:
      "Compare across multiple cycles to see how the codebase evolved over a session.",
    commands: [
      { label: "Diff from cycle 1 to cycle 5", cmd: "git diff <cycle-1-hash>..<cycle-5-hash>" },
      { label: "List all files changed across cycles", cmd: "git diff <start>..<end> --stat" },
      { label: "Show only added/deleted files", cmd: "git diff <start>..<end> --diff-filter=AD --name-only" },
    ],
  },
];

export default function ReviewingChangesPage() {
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
          Reviewing Changes
        </h1>
        <p className="mt-3 text-muted">
          OrchyStraw uses git as its diff viewer. Review agent changes per
          cycle, per agent, or cumulatively — no proprietary UI required.
        </p>

        <div className="mt-10 space-y-10">
          {/* Workflow diagram */}
          <section className="rounded-xl border border-card-border bg-card p-6">
            <h2 className="text-lg font-semibold">Review workflow</h2>
            <div className="mt-4 flex flex-col items-center gap-2 font-mono text-xs text-muted sm:flex-row sm:gap-4">
              <span className="rounded border border-card-border bg-background px-3 py-1.5">
                Cycle runs
              </span>
              <span className="text-accent">&rarr;</span>
              <span className="rounded border border-card-border bg-background px-3 py-1.5">
                Auto-commit
              </span>
              <span className="text-accent">&rarr;</span>
              <span className="rounded border border-card-border bg-background px-3 py-1.5">
                git diff
              </span>
              <span className="text-accent">&rarr;</span>
              <span className="rounded border border-accent/30 bg-accent/10 px-3 py-1.5 text-accent">
                You review
              </span>
            </div>
          </section>

          {/* Steps */}
          {steps.map((step) => (
            <section key={step.title}>
              <h2 className="flex items-center gap-2 text-xl font-semibold">
                <step.icon className="h-5 w-5 text-accent" />
                {step.title}
              </h2>
              <p className="mt-2 text-sm text-foreground/80">
                {step.description}
              </p>
              <div className="mt-4 space-y-3">
                {step.commands.map((c) => (
                  <div
                    key={c.cmd}
                    className="rounded-lg border border-card-border bg-card p-4 font-mono text-xs"
                  >
                    <p className="text-muted"># {c.label}</p>
                    {c.cmd}
                  </div>
                ))}
              </div>
            </section>
          ))}

          {/* Tips */}
          <section className="rounded-xl border border-card-border bg-card p-6">
            <h2 className="text-lg font-semibold">Tips</h2>
            <ul className="mt-3 list-inside list-disc space-y-2 text-sm text-muted">
              <li>
                Use <code className="rounded bg-background px-1.5 py-0.5 font-mono text-xs text-accent">git log --oneline --grep=&quot;auto-update&quot;</code> to
                list only cycle commits
              </li>
              <li>
                Pipe diffs to your favorite tool:{" "}
                <code className="rounded bg-background px-1.5 py-0.5 font-mono text-xs text-accent">git diff HEAD~1 | delta</code>
              </li>
              <li>
                Use <code className="rounded bg-background px-1.5 py-0.5 font-mono text-xs text-accent">git bisect</code> to
                find which cycle introduced a regression
              </li>
              <li>
                VS Code, GitHub, and GitLab all render these diffs natively — no
                extra tooling needed
              </li>
            </ul>
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
