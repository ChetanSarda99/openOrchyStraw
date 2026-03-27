import type { Metadata } from "next";
import { ArrowLeft } from "lucide-react";

export const metadata: Metadata = {
  title: "Issue to PR — OrchyStraw Docs",
  description:
    "Step-by-step guide: go from a GitHub issue to a merged pull request using OrchyStraw's multi-agent orchestration.",
};

const steps = [
  {
    number: "1",
    title: "Create a GitHub issue",
    body: "Write a clear issue describing the feature or bug. Include acceptance criteria — your agents will use this as their goal.",
    code: null,
  },
  {
    number: "2",
    title: "Assign agents in agents.conf",
    body: "Decide which agents need to work on this issue. Update their prompts with the task details and file boundaries.",
    code: `# agents.conf — assign agents to the issue
[backend]
cli = claude
prompt = prompts/06-backend/06-backend.txt
owns = src/core/

[qa]
cli = claude
prompt = prompts/09-qa/09-qa.txt
owns = tests/`,
  },
  {
    number: "3",
    title: "Write agent prompts",
    body: "Each agent gets a markdown prompt with their specific tasks, constraints, and the issue context. Be explicit about what \"done\" looks like.",
    code: `## Current Tasks
1. Implement POST /api/notes/batch endpoint
   - Accept array of note IDs
   - Return 207 Multi-Status
   - Add input validation
2. Write unit tests for the new endpoint
3. Update shared context when done`,
  },
  {
    number: "4",
    title: "Run the orchestrator",
    body: "One command kicks off the cycle. Each agent reads its prompt, does its work, and writes to shared context for the next agent.",
    code: `# Run a single cycle
./scripts/auto-agent.sh

# Or run 3 cycles unattended
./scripts/auto-agent.sh --cycles 3`,
  },
  {
    number: "5",
    title: "Review agent output",
    body: "After the cycle, review what each agent produced. Use git diff filtered by file ownership to check each agent's work independently.",
    code: `# See what backend agent changed
git diff HEAD~1 -- src/core/

# See what QA agent changed
git diff HEAD~1 -- tests/

# Full cycle summary
git show HEAD --stat`,
  },
  {
    number: "6",
    title: "Iterate or ship",
    body: "If the work needs refinement, update the prompts and run another cycle. When you're satisfied, create a PR.",
    code: `# Create a PR with the cycle's changes
gh pr create --title "feat: batch notes endpoint" \\
  --body "Closes #42. Built with OrchyStraw (3 cycles, 2 agents)."`,
  },
];

export default function IssueToPrPage() {
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
          From Issue to PR
        </h1>
        <p className="mt-3 text-muted">
          A step-by-step walkthrough: take a GitHub issue, orchestrate your
          agents, and ship a pull request.
        </p>

        <div className="mt-10 space-y-8">
          {steps.map((step) => (
            <section
              key={step.number}
              className="rounded-xl border border-card-border bg-card/50 p-6"
            >
              <div className="flex items-start gap-4">
                <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-accent text-sm font-bold text-accent-foreground">
                  {step.number}
                </span>
                <div className="min-w-0 flex-1">
                  <h2 className="text-lg font-semibold">{step.title}</h2>
                  <p className="mt-2 text-sm leading-relaxed text-foreground/80">
                    {step.body}
                  </p>
                  {step.code && (
                    <pre className="mt-4 overflow-x-auto rounded-lg border border-card-border bg-background p-4 font-mono text-xs leading-relaxed text-foreground/70">
                      {step.code}
                    </pre>
                  )}
                </div>
              </div>
            </section>
          ))}
        </div>

        <div className="mt-12 rounded-xl border border-card-border bg-card p-6">
          <h2 className="text-lg font-semibold">Key principles</h2>
          <ul className="mt-3 list-inside list-disc space-y-2 text-sm text-muted">
            <li>
              <strong className="text-foreground">One issue, one branch.</strong>{" "}
              Keep the scope tight — agents work best with focused tasks.
            </li>
            <li>
              <strong className="text-foreground">Prompts are your spec.</strong>{" "}
              The more specific your prompt, the better the agent output.
            </li>
            <li>
              <strong className="text-foreground">Review every cycle.</strong>{" "}
              Don&apos;t blindly run 10 cycles. Check after each one.
            </li>
            <li>
              <strong className="text-foreground">Let QA catch issues.</strong>{" "}
              Include a QA agent to review before you do.
            </li>
          </ul>
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
