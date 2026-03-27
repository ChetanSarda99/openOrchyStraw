import type { Metadata } from "next";
import { ArrowLeft, Layers, GitBranch, Shield, MessageSquare, Cpu } from "lucide-react";

export const metadata: Metadata = {
  title: "Architecture — OrchyStraw Docs",
  description:
    "How OrchyStraw orchestrates multiple AI agents: cycle lifecycle, shared context, file ownership, and the commit-per-agent model.",
};

function FlowStep({ num, title, desc }: { num: string; title: string; desc: string }) {
  return (
    <div className="flex gap-4">
      <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full border border-accent/30 bg-accent/10 font-mono text-xs font-bold text-accent">
        {num}
      </div>
      <div>
        <p className="font-semibold text-foreground">{title}</p>
        <p className="mt-0.5 text-sm text-muted">{desc}</p>
      </div>
    </div>
  );
}

export default function ArchitecturePage() {
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
          Architecture
        </h1>
        <p className="mt-3 text-muted">
          One bash script. Markdown prompts. Git as the database.
          Here&apos;s how the pieces fit together.
        </p>

        <div className="mt-10 space-y-8">
          {/* System diagram */}
          <section>
            <h2 className="flex items-center gap-2 text-xl font-semibold">
              <Layers className="h-5 w-5 text-accent" />
              System overview
            </h2>
            <div className="mt-4 overflow-x-auto rounded-xl border border-card-border bg-card p-5 font-mono text-xs leading-relaxed">
              <pre className="text-foreground/80">{`┌─────────────────────────────────────────────────┐
│                 auto-agent.sh                   │
│            (orchestrator — bash)                │
├─────────────────────────────────────────────────┤
│                                                 │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐      │
│  │ Backend  │  │   Web    │  │  Pixel   │ ...  │
│  │ (claude) │  │ (gemini) │  │ (claude) │      │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘      │
│       │              │              │            │
│       ▼              ▼              ▼            │
│  ┌──────────────────────────────────────────┐   │
│  │         Shared Context (markdown)        │   │
│  │    prompts/00-shared-context/context.md  │   │
│  └──────────────────────────────────────────┘   │
│                      │                          │
│                      ▼                          │
│  ┌──────────────────────────────────────────┐   │
│  │          Quality Gates                   │   │
│  │   syntax │ tests │ ownership │ review    │   │
│  └──────────────────────────────────────────┘   │
│                      │                          │
│                      ▼                          │
│  ┌──────────────────────────────────────────┐   │
│  │        PM Agent (coordinator)            │   │
│  │   reviews → updates prompts → commits    │   │
│  └──────────────────────────────────────────┘   │
│                      │                          │
│                      ▼                          │
│               merge to main                     │
└─────────────────────────────────────────────────┘`}</pre>
            </div>
          </section>

          {/* Cycle flow */}
          <section>
            <h2 className="flex items-center gap-2 text-xl font-semibold">
              <GitBranch className="h-5 w-5 text-accent" />
              Cycle flow
            </h2>
            <div className="mt-4 space-y-4">
              <FlowStep
                num="1"
                title="Branch"
                desc="Orchestrator creates auto/cycle-N-MMDD-HHMM from main."
              />
              <FlowStep
                num="2"
                title="Inject context"
                desc="Shared context + cross-cycle history appended to each agent's prompt."
              />
              <FlowStep
                num="3"
                title="Spawn agents"
                desc="Workers run in parallel. Each reads its prompt, does its work, writes to shared context."
              />
              <FlowStep
                num="4"
                title="Quality gates"
                desc="Syntax, tests, and ownership gates run. Blocking failures halt the merge."
              />
              <FlowStep
                num="5"
                title="Commit by ownership"
                desc="Each agent's changes are committed separately, scoped to their owned paths."
              />
              <FlowStep
                num="6"
                title="PM coordinates"
                desc="PM agent runs last — reviews work, updates prompts, writes session tracker."
              />
              <FlowStep
                num="7"
                title="Merge"
                desc="Feature branch merges to main. Cycle state saved for resume support."
              />
            </div>
          </section>

          {/* Shared context */}
          <section>
            <h2 className="flex items-center gap-2 text-xl font-semibold">
              <MessageSquare className="h-5 w-5 text-accent" />
              Shared context
            </h2>
            <div className="mt-4 space-y-4 text-sm leading-relaxed text-foreground/80">
              <p>
                Agents communicate through a single markdown file:{" "}
                <code className="rounded bg-card px-1.5 py-0.5 font-mono text-xs text-accent">
                  prompts/00-shared-context/context.md
                </code>
              </p>
              <p>
                Each agent appends its status, blockers, and needs. The
                orchestrator resets the file at the start of each cycle but
                preserves a cross-cycle history file so agents can see what
                shipped previously.
              </p>
              <div className="rounded-lg border border-card-border bg-card p-4 font-mono text-xs whitespace-pre-wrap">
                <p className="text-muted"># Example shared context entry</p>
                {`## Backend Status\n- Added POST /api/notes/batch endpoint\n- NEED: GET /api/search endpoint from iOS team\n\n## QA Findings\n- BUG-012: file-access.sh allows write to protected path\n\n## Blockers\n- #77 integration blocked on CS applying fixes`}
              </div>
              <p>
                This is how agents coordinate without a database, message queue,
                or API. Plain text, version-controlled, token-efficient.
              </p>
            </div>
          </section>

          {/* File ownership */}
          <section>
            <h2 className="flex items-center gap-2 text-xl font-semibold">
              <Shield className="h-5 w-5 text-accent" />
              File ownership model
            </h2>
            <div className="mt-4 space-y-4 text-sm leading-relaxed text-foreground/80">
              <p>
                Every path in the repo belongs to exactly one agent. Ownership is
                declared in{" "}
                <code className="rounded bg-card px-1.5 py-0.5 font-mono text-xs text-accent">agents.conf</code>{" "}
                and enforced at commit time:
              </p>
              <div className="overflow-x-auto rounded-xl border border-card-border">
                <table className="w-full text-sm">
                  <thead>
                    <tr className="border-b border-card-border bg-card">
                      <th className="px-4 py-3 text-left font-medium text-muted">Agent</th>
                      <th className="px-4 py-3 text-left font-medium text-muted">Owns</th>
                    </tr>
                  </thead>
                  <tbody>
                    {[
                      { agent: "06-backend", owns: "scripts/, src/core/, src/lib/" },
                      { agent: "11-web", owns: "site/" },
                      { agent: "08-pixel", owns: "src/pixel/, pixel-agents/" },
                      { agent: "09-qa", owns: "tests/, reports/" },
                      { agent: "03-pm", owns: "prompts/, docs/" },
                      { agent: "01-ceo", owns: "docs/strategy/" },
                    ].map((row, i) => (
                      <tr
                        key={row.agent}
                        className={`border-b border-card-border/50 ${i % 2 === 0 ? "bg-card/50" : ""}`}
                      >
                        <td className="px-4 py-3 font-mono text-xs text-accent">{row.agent}</td>
                        <td className="px-4 py-3 text-foreground/90">{row.owns}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
              <p>
                This prevents merge conflicts, git races, and cross-agent
                interference. Each agent&apos;s work is committed in isolation.
              </p>
            </div>
          </section>

          {/* Design principles */}
          <section>
            <h2 className="flex items-center gap-2 text-xl font-semibold">
              <Cpu className="h-5 w-5 text-accent" />
              Design principles
            </h2>
            <div className="mt-4 space-y-3">
              {[
                { title: "No framework", desc: "Pure bash + markdown. No Python, no Node, no dependencies beyond git." },
                { title: "Git as database", desc: "Cycle state, agent output, and history all live in git. No external storage." },
                { title: "Agent-agnostic", desc: "Works with Claude Code, Codex, Gemini CLI, Aider, Cursor — anything that reads a prompt." },
                { title: "Token-efficient", desc: "Shared context is plain markdown. No JSON serialization, no API overhead." },
                { title: "Resumable", desc: "Cycle state persisted to disk. Interrupted runs resume from the right point." },
                { title: "Safe by default", desc: "Protected files, ownership enforcement, quality gates, rogue write detection." },
              ].map((p) => (
                <div key={p.title} className="rounded-lg border border-card-border bg-card/50 p-4">
                  <p className="font-semibold text-foreground">{p.title}</p>
                  <p className="mt-1 text-sm text-muted">{p.desc}</p>
                </div>
              ))}
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
