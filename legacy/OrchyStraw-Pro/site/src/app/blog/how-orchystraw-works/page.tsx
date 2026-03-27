import type { Metadata } from "next";
import { ArrowLeft } from "lucide-react";

export const metadata: Metadata = {
  title: "How OrchyStraw Runs 9 AI Agents on One Codebase — OrchyStraw Blog",
  description:
    "A technical deep-dive into how OrchyStraw orchestrates 9 AI coding agents with bash, markdown prompts, shared context, and file ownership boundaries.",
};

const articleJsonLd = {
  "@context": "https://schema.org",
  "@type": "Article",
  headline: "How OrchyStraw Runs 9 AI Agents on One Codebase",
  description:
    "A technical deep-dive into how OrchyStraw orchestrates 9 AI coding agents with bash, markdown prompts, shared context, and file ownership boundaries.",
  datePublished: "2026-03-20",
  author: { "@type": "Organization", name: "OrchyStraw" },
  publisher: {
    "@type": "Organization",
    name: "OrchyStraw",
    url: "https://orchystraw.dev",
  },
};

export default function HowOrchyStrawWorks() {
  return (
    <main className="min-h-screen px-4 py-16 sm:px-6 sm:py-24">
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(articleJsonLd) }}
      />
      <article className="prose-invert mx-auto max-w-2xl">
        <a
          href="/blog"
          className="mb-8 inline-flex items-center gap-1.5 text-sm text-muted transition-colors hover:text-foreground"
        >
          <ArrowLeft className="h-3.5 w-3.5" />
          Back to blog
        </a>

        <time className="mt-4 block text-xs text-muted font-mono">
          2026-03-20
        </time>
        <h1 className="mt-2 text-3xl font-bold tracking-tight sm:text-4xl">
          How OrchyStraw Runs 9 AI Agents on One Codebase
        </h1>
        <p className="mt-4 text-lg text-muted">
          A technical deep-dive into agents.conf, shared context, file
          ownership, and the orchestration cycle that keeps everything in sync.
        </p>

        <div className="mt-10 space-y-6 text-sm leading-relaxed text-foreground/80">
          <h2 className="text-xl font-semibold text-foreground">
            The agent roster
          </h2>
          <p>
            OrchyStraw Pro runs 9 agents on a single repository. Each has a
            role, a prompt file, a set of owned files, and a cycle interval
            that controls how often it runs:
          </p>
          <div className="overflow-x-auto rounded-lg border border-card-border">
            <pre className="bg-code-bg p-4 text-xs font-mono leading-relaxed overflow-x-auto">
{`# agents.conf — who does what
03-pm        | prompts/03-pm/03-pm.txt       | prompts/ docs/          | 0 | PM Coordinator
06-backend   | prompts/06-backend/...        | scripts/ src/core/      | 1 | Backend Dev
11-web       | prompts/11-web/...            | site/                   | 1 | Web Dev
02-cto       | prompts/02-cto/...            | docs/architecture/      | 3 | CTO
08-pixel     | prompts/08-pixel/...          | src/pixel/              | 3 | Pixel Agents
09-qa        | prompts/09-qa/...             | tests/ reports/         | 5 | QA Engineer
01-ceo       | prompts/01-ceo/...            | docs/strategy/          | 10 | CEO
13-hr        | prompts/13-hr/...             | docs/team/              | 10 | HR
10-security  | prompts/10-security/...       | reports/                | 10 | Security`}
            </pre>
          </div>
          <p>
            The format is{" "}
            <code className="rounded bg-card px-1.5 py-0.5 font-mono text-xs text-accent">
              id | prompt_path | ownership | interval | label
            </code>
            . Interval{" "}
            <code className="rounded bg-card px-1.5 py-0.5 font-mono text-xs text-accent">
              0
            </code>{" "}
            means the agent runs last (coordinator).{" "}
            <code className="rounded bg-card px-1.5 py-0.5 font-mono text-xs text-accent">
              1
            </code>{" "}
            means every cycle.{" "}
            <code className="rounded bg-card px-1.5 py-0.5 font-mono text-xs text-accent">
              N
            </code>{" "}
            means every Nth cycle. This lets strategic agents like the CEO run
            less frequently while core builders run every time.
          </p>

          <h2 className="text-xl font-semibold text-foreground">
            File ownership prevents conflicts
          </h2>
          <p>
            The hardest problem in multi-agent coding is merge conflicts. Two
            agents editing the same file will produce garbage. OrchyStraw solves
            this at the config level: each agent declares the directories it
            owns, and only that agent can create or modify files there.
          </p>
          <p>
            The backend agent owns{" "}
            <code className="rounded bg-card px-1.5 py-0.5 font-mono text-xs text-accent">
              scripts/
            </code>{" "}
            and{" "}
            <code className="rounded bg-card px-1.5 py-0.5 font-mono text-xs text-accent">
              src/core/
            </code>
            . The web agent owns{" "}
            <code className="rounded bg-card px-1.5 py-0.5 font-mono text-xs text-accent">
              site/
            </code>
            . The CTO owns{" "}
            <code className="rounded bg-card px-1.5 py-0.5 font-mono text-xs text-accent">
              docs/architecture/
            </code>
            . No overlap, no conflicts. If an agent needs something from another
            agent&apos;s territory, it writes a request to shared context.
          </p>

          <h2 className="text-xl font-semibold text-foreground">
            Shared context: the communication bus
          </h2>
          <p>
            Agents can&apos;t talk to each other directly. Instead, they
            communicate through a single markdown file:{" "}
            <code className="rounded bg-card px-1.5 py-0.5 font-mono text-xs text-accent">
              prompts/00-shared-context/context.md
            </code>
            . At the start of each cycle, every agent reads this file. At the
            end, they append their status — what they built, what they need, and
            what&apos;s blocked.
          </p>
          <p>
            This is deliberately low-bandwidth. Instead of broadcasting every
            thought to every agent (expensive and noisy), shared context carries
            only the essentials: build status, blockers, and cross-agent
            requests. It gets reset each cycle to keep token costs down.
          </p>

          <h2 className="text-xl font-semibold text-foreground">
            The orchestration cycle
          </h2>
          <p>
            A single cycle works like this:
          </p>
          <ol className="list-inside list-decimal space-y-3 text-muted">
            <li>
              <span className="text-foreground/80">
                The orchestrator reads{" "}
                <code className="rounded bg-card px-1.5 py-0.5 font-mono text-xs text-accent">
                  agents.conf
                </code>{" "}
                and determines which agents run this cycle based on their
                interval
              </span>
            </li>
            <li>
              <span className="text-foreground/80">
                Each active agent gets launched with its prompt file, which
                includes the shared context prepended
              </span>
            </li>
            <li>
              <span className="text-foreground/80">
                Agents read their tasks, do their work, and write files within
                their ownership boundaries
              </span>
            </li>
            <li>
              <span className="text-foreground/80">
                Each agent appends its status to shared context when done
              </span>
            </li>
            <li>
              <span className="text-foreground/80">
                The PM coordinator agent runs last — it reads all status updates,
                updates task assignments, and prepares prompts for the next cycle
              </span>
            </li>
            <li>
              <span className="text-foreground/80">
                The orchestrator commits all changes to a branch and increments
                the cycle counter
              </span>
            </li>
          </ol>

          <h2 className="text-xl font-semibold text-foreground">
            Model routing: different tools for different agents
          </h2>
          <p>
            OrchyStraw is agent-agnostic — it works with any AI coding tool.
            But you can also route specific agents to specific models. In our
            setup, architecture decisions run on Claude Opus, UI work runs on
            Gemini, and code review runs on Codex. Each model brings its
            strengths. The orchestrator doesn&apos;t care which tool an agent
            uses — it just needs the work done and the status written.
          </p>

          <h2 className="text-xl font-semibold text-foreground">
            What makes this different
          </h2>
          <p>
            Most multi-agent frameworks (AutoGen, CrewAI, LangGraph) orchestrate
            API calls between LLM chat sessions. They run in Python, require
            dependencies, and their &quot;agents&quot; are wrappers around
            completion endpoints.
          </p>
          <p>
            OrchyStraw orchestrates real coding tools — tools that can read
            files, run tests, execute shell commands, and modify code. The
            orchestrator is a bash script. Agent definitions are plain text
            config. Prompts are markdown. There&apos;s nothing to install,
            nothing to import, and nothing that locks you into a specific model
            or provider.
          </p>
          <p>
            The entire system fits in your head: config file, prompt files,
            shared context, bash script. That&apos;s it.
          </p>
        </div>

        <div className="mt-12 border-t border-card-border pt-8 flex gap-4 flex-wrap">
          <a
            href="/docs/architecture"
            className="inline-flex items-center gap-2 rounded-lg bg-accent px-6 py-3 text-sm font-semibold text-accent-foreground transition-colors hover:bg-accent/90"
          >
            Read the Architecture Docs
          </a>
          <a
            href="https://github.com/ChetanSarda99/openOrchyStraw"
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-2 rounded-lg border border-card-border px-6 py-3 text-sm font-semibold transition-colors hover:border-accent/30"
          >
            View on GitHub
          </a>
        </div>
      </article>
    </main>
  );
}
