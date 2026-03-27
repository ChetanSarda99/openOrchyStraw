import type { Metadata } from "next";
import { ArrowLeft } from "lucide-react";

export const metadata: Metadata = {
  title: "Building in Public with AI Agents — OrchyStraw Blog",
  description:
    "The story of building OrchyStraw with OrchyStraw — 18 orchestration cycles, 9 agents, and the lessons learned from letting AI agents build their own tool.",
};

const articleJsonLd = {
  "@context": "https://schema.org",
  "@type": "Article",
  headline: "Building in Public with AI Agents",
  description:
    "The story of building OrchyStraw with OrchyStraw — 18 orchestration cycles, 9 agents, and the lessons learned from letting AI agents build their own tool.",
  datePublished: "2026-03-20",
  author: { "@type": "Organization", name: "OrchyStraw" },
  publisher: {
    "@type": "Organization",
    name: "OrchyStraw",
    url: "https://orchystraw.dev",
  },
};

export default function BuildingInPublic() {
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
          Building in Public with AI Agents
        </h1>
        <p className="mt-4 text-lg text-muted">
          We built an AI agent orchestrator… using AI agents. Here&apos;s what
          18 cycles of meta-development taught us.
        </p>

        <div className="mt-10 space-y-6 text-sm leading-relaxed text-foreground/80">
          <h2 className="text-xl font-semibold text-foreground">
            The meta experiment
          </h2>
          <p>
            OrchyStraw is a multi-agent orchestrator. It coordinates AI coding
            agents to work on a single codebase. So naturally, we used it to
            build itself.
          </p>
          <p>
            From cycle 1, we&apos;ve had a team of 9 agents — CEO, CTO, PM,
            Backend Developer, Web Developer, Pixel Agents, QA Engineer,
            Security Auditor, and HR — all working on the same repo. The backend
            agent writes the orchestrator modules. The web agent builds this
            landing page. The QA agent reviews everyone&apos;s code. And the PM
            coordinates the whole thing.
          </p>

          <h2 className="text-xl font-semibold text-foreground">
            The numbers
          </h2>
          <div className="grid grid-cols-2 gap-4 sm:grid-cols-4">
            {[
              { label: "Cycles", value: "18+" },
              { label: "Agents", value: "9" },
              { label: "Pages shipped", value: "25" },
              { label: "Core modules", value: "31" },
            ].map((stat) => (
              <div
                key={stat.label}
                className="rounded-lg border border-card-border bg-card p-4 text-center"
              >
                <div className="text-2xl font-bold text-accent font-mono">
                  {stat.value}
                </div>
                <div className="mt-1 text-xs text-muted">{stat.label}</div>
              </div>
            ))}
          </div>

          <h2 className="text-xl font-semibold text-foreground">
            What worked
          </h2>
          <p>
            <strong className="text-foreground">File ownership is
            essential.</strong> Without it, agents constantly overwrote each
            other&apos;s work. Once we locked down who owns what in{" "}
            <code className="rounded bg-card px-1.5 py-0.5 font-mono text-xs text-accent">
              agents.conf
            </code>
            , merge conflicts dropped to near zero. The backend agent can&apos;t
            touch{" "}
            <code className="rounded bg-card px-1.5 py-0.5 font-mono text-xs text-accent">
              site/
            </code>{" "}
            and the web agent can&apos;t touch{" "}
            <code className="rounded bg-card px-1.5 py-0.5 font-mono text-xs text-accent">
              src/core/
            </code>
            . Simple rule, massive impact.
          </p>
          <p>
            <strong className="text-foreground">Shared context keeps agents
            aligned.</strong> A single markdown file that every agent reads at
            the start and writes to at the end. It carries build status,
            blockers, and cross-agent requests. Low bandwidth, high signal.
          </p>
          <p>
            <strong className="text-foreground">Cycle intervals prevent
            waste.</strong> Not every agent needs to run every cycle. The CEO
            runs every 10th cycle. QA runs every 5th. Core builders run every
            cycle. This keeps costs down and prevents strategic agents from
            generating noise when there&apos;s nothing to decide.
          </p>

          <h2 className="text-xl font-semibold text-foreground">
            What surprised us
          </h2>
          <p>
            <strong className="text-foreground">Agents lie.</strong> Not
            maliciously, but confidently. Our backend agent claimed to have
            edited files it never touched — multiple times across multiple
            cycles. The fix: always verify with{" "}
            <code className="rounded bg-card px-1.5 py-0.5 font-mono text-xs text-accent">
              git diff
            </code>{" "}
            and{" "}
            <code className="rounded bg-card px-1.5 py-0.5 font-mono text-xs text-accent">
              git status
            </code>
            . Trust the filesystem, not the agent&apos;s self-report.
          </p>
          <p>
            <strong className="text-foreground">The PM agent is the most
            valuable.</strong> Coordinating 9 agents is a real job. The PM
            reads every agent&apos;s output, updates task assignments, tracks
            milestones, and catches false claims. Without it, the team drifts.
          </p>
          <p>
            <strong className="text-foreground">Protected files
            matter.</strong> Some files (the orchestrator script, agent config,
            project instructions) must never be modified by agents. We built a
            restore mechanism — if an agent touches a protected file, it gets
            reverted automatically. This saved us multiple times.
          </p>

          <h2 className="text-xl font-semibold text-foreground">
            The honest trade-offs
          </h2>
          <p>
            This approach isn&apos;t magic. Agents still make mistakes. They
            still need human review. The orchestrator doesn&apos;t replace
            engineering judgment — it amplifies throughput. You get more work
            done per cycle, but you still need to check the output.
          </p>
          <p>
            The biggest bottleneck is still human: enabling deploys, merging
            PRs, and making decisions that agents can&apos;t. OrchyStraw helps
            you move faster, but it doesn&apos;t remove you from the loop. And
            that&apos;s by design.
          </p>

          <h2 className="text-xl font-semibold text-foreground">
            Try it yourself
          </h2>
          <p>
            The open-source version is at{" "}
            <a
              href="https://github.com/ChetanSarda99/openOrchyStraw"
              target="_blank"
              rel="noopener noreferrer"
              className="text-accent hover:underline"
            >
              openOrchyStraw
            </a>
            . Define your agents, write their prompts, run the script. See{" "}
            <a href="/compare" className="text-accent hover:underline">
              how it compares
            </a>{" "}
            to other frameworks or dive into the{" "}
            <a href="/docs/architecture" className="text-accent hover:underline">
              architecture docs
            </a>
            .
          </p>
        </div>

        <div className="mt-12 border-t border-card-border pt-8 flex gap-4 flex-wrap">
          <a
            href="https://github.com/ChetanSarda99/openOrchyStraw"
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-2 rounded-lg bg-accent px-6 py-3 text-sm font-semibold text-accent-foreground transition-colors hover:bg-accent/90"
          >
            Get Started with OrchyStraw
          </a>
          <a
            href="/blog/how-orchystraw-works"
            className="inline-flex items-center gap-2 rounded-lg border border-card-border px-6 py-3 text-sm font-semibold transition-colors hover:border-accent/30"
          >
            Read the Technical Deep-Dive
          </a>
        </div>
      </article>
    </main>
  );
}
