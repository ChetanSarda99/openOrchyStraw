import type { Metadata } from "next";
import { ArrowLeft, Cpu, Shield, AlertTriangle } from "lucide-react";

export const metadata: Metadata = {
  title: "Parallel Agents — OrchyStraw Docs",
  description:
    "How to run multiple AI coding agents simultaneously on the same codebase with file ownership boundaries preventing conflicts.",
};

export default function ParallelAgentsPage() {
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
          Parallel Agents
        </h1>
        <p className="mt-3 text-muted">
          Run multiple AI coding agents simultaneously on the same codebase.
          File ownership boundaries prevent conflicts — each agent works in
          its own lane.
        </p>

        <div className="mt-10 space-y-8">
          {/* Why parallel */}
          <section>
            <h2 className="flex items-center gap-2 text-xl font-semibold">
              <Cpu className="h-5 w-5 text-accent" />
              Why run agents in parallel?
            </h2>
            <div className="mt-4 text-sm leading-relaxed text-foreground/80">
              <p>
                Sequential orchestration is safe but slow. If your backend
                agent takes 5 minutes and your frontend agent takes 5 minutes,
                you wait 10 minutes. Running them in parallel cuts that to 5.
              </p>
              <p className="mt-3">
                OrchyStraw makes this safe through{" "}
                <strong className="text-foreground">file ownership boundaries</strong>.
                Each agent is assigned directories it can modify. The
                orchestrator enforces these boundaries — no two agents can
                touch the same file.
              </p>
            </div>
          </section>

          {/* Configuration */}
          <section>
            <h2 className="flex items-center gap-2 text-xl font-semibold">
              <Shield className="h-5 w-5 text-accent" />
              Setting up parallel agents
            </h2>
            <div className="mt-4 space-y-4">
              <p className="text-sm text-foreground/80">
                Define non-overlapping file ownership in{" "}
                <code className="rounded bg-card px-1.5 py-0.5 font-mono text-xs text-accent">agents.conf</code>:
              </p>
              <pre className="overflow-x-auto rounded-lg border border-card-border bg-card p-4 font-mono text-xs leading-relaxed text-foreground/70">
{`# agents.conf — parallel-safe configuration
[backend]
cli = claude
prompt = prompts/06-backend/06-backend.txt
owns = src/core/, scripts/

[frontend]
cli = gemini -p
prompt = prompts/05-tauri-ui/05-tauri-ui.txt
owns = src/components/, src/styles/

[ios]
cli = claude
prompt = prompts/07-ios/07-ios.txt
owns = ios/

[qa]
cli = claude
prompt = prompts/09-qa/09-qa.txt
owns = tests/`}
              </pre>
              <p className="text-sm text-foreground/80">
                The <code className="rounded bg-card px-1.5 py-0.5 font-mono text-xs text-accent">owns</code> field
                is the key. As long as no two agents share a directory, they can
                run simultaneously without merge conflicts.
              </p>
            </div>
          </section>

          {/* Running */}
          <section>
            <h2 className="text-xl font-semibold">Running in parallel</h2>
            <div className="mt-4 space-y-3">
              <div className="rounded-lg border border-card-border bg-card p-4 font-mono text-xs">
                <p className="text-muted"># Run all agents in the current cycle simultaneously</p>
                ./scripts/auto-agent.sh --parallel
              </div>
              <div className="rounded-lg border border-card-border bg-card p-4 font-mono text-xs">
                <p className="text-muted"># Run 3 parallel cycles</p>
                ./scripts/auto-agent.sh --parallel --cycles 3
              </div>
              <p className="text-sm text-foreground/80">
                The orchestrator spawns each agent as a background process,
                waits for all to complete, then commits their combined changes
                as a single checkpoint.
              </p>
            </div>
          </section>

          {/* Shared context */}
          <section>
            <h2 className="text-xl font-semibold">
              Communication via shared context
            </h2>
            <div className="mt-4 space-y-4 text-sm text-foreground/80">
              <p>
                Parallel agents can&apos;t read each other&apos;s changes mid-cycle.
                They communicate through the{" "}
                <strong className="text-foreground">shared context file</strong> —
                a markdown file that persists between cycles.
              </p>
              <pre className="overflow-x-auto rounded-lg border border-card-border bg-card p-4 font-mono text-xs leading-relaxed text-foreground/70">
{`# prompts/00-shared-context/context.md

## Backend Status
- Added POST /api/notes/batch endpoint
- NEED: frontend to add batch select UI

## Frontend Status
- NEED: POST /api/notes/batch from backend`}
              </pre>
              <p>
                After each cycle, agents append their status. Before the next
                cycle, they read what others wrote. This is how cross-agent
                coordination works without real-time communication.
              </p>
            </div>
          </section>

          {/* Pitfalls */}
          <section className="rounded-xl border border-yellow-400/20 bg-yellow-400/5 p-6">
            <h2 className="flex items-center gap-2 text-lg font-semibold">
              <AlertTriangle className="h-5 w-5 text-yellow-400" />
              Pitfalls to avoid
            </h2>
            <ul className="mt-3 list-inside list-disc space-y-2 text-sm text-muted">
              <li>
                <strong className="text-foreground">Overlapping ownership</strong> —
                if two agents both own{" "}
                <code className="rounded bg-card px-1.5 py-0.5 font-mono text-xs">src/</code>,
                they will create merge conflicts. Keep boundaries strict.
              </li>
              <li>
                <strong className="text-foreground">Shared config files</strong> —
                files like <code className="rounded bg-card px-1.5 py-0.5 font-mono text-xs">package.json</code> or{" "}
                <code className="rounded bg-card px-1.5 py-0.5 font-mono text-xs">Cargo.toml</code> need
                a single owner. Don&apos;t let multiple agents edit them.
              </li>
              <li>
                <strong className="text-foreground">Dependent work</strong> —
                if the frontend needs an API that the backend hasn&apos;t built yet,
                run backend first (sequential), then frontend. Use parallel only
                for independent work.
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
