import type { Metadata } from "next";
import { ArrowLeft } from "lucide-react";

export const metadata: Metadata = {
  title: "Why We Built OrchyStraw — OrchyStraw Blog",
  description:
    "Every multi-agent framework wants you to install their runtime. We just wanted bash and markdown.",
};

const articleJsonLd = {
  "@context": "https://schema.org",
  "@type": "Article",
  headline: "Why We Built OrchyStraw",
  description:
    "Every multi-agent framework wants you to install their runtime. We just wanted bash and markdown.",
  datePublished: "2026-03-20",
  author: { "@type": "Organization", name: "OrchyStraw" },
  publisher: {
    "@type": "Organization",
    name: "OrchyStraw",
    url: "https://orchystraw.dev",
  },
};

export default function WhyWeBuiltOrchyStraw() {
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
          Why We Built OrchyStraw
        </h1>
        <p className="mt-4 text-lg text-muted">
          Every multi-agent framework wants you to install their runtime. We
          just wanted bash and markdown.
        </p>

        <div className="mt-10 space-y-6 text-sm leading-relaxed text-foreground/80">
          <h2 className="text-xl font-semibold text-foreground">
            The problem with &quot;agent frameworks&quot;
          </h2>
          <p>
            We started with a simple goal: get multiple AI coding agents working
            on the same codebase without stepping on each other. The obvious
            move was to look at existing tools — AutoGen, CrewAI, LangGraph,
            MetaGPT.
          </p>
          <p>
            Every single one required a Python runtime, a pile of dependencies,
            and a specific way of defining &quot;agents&quot; that were really
            just LLM chat wrappers. They could generate text, but they
            couldn&apos;t actually run Claude Code or Codex or Gemini CLI. They
            weren&apos;t orchestrating coding agents — they were orchestrating
            API calls.
          </p>

          <h2 className="text-xl font-semibold text-foreground">
            What we actually needed
          </h2>
          <p>We needed something much simpler:</p>
          <ul className="list-inside list-disc space-y-2 text-muted">
            <li>
              A way to define agents with roles, file ownership, and prompts
            </li>
            <li>
              A way to run them in sequence or parallel on the same repo
            </li>
            <li>
              A shared context system so agents could communicate without
              broadcasting everything to everyone
            </li>
            <li>
              No dependencies — just bash and markdown files
            </li>
          </ul>
          <p>
            That&apos;s OrchyStraw. An <code className="rounded bg-card px-1.5 py-0.5 font-mono text-xs text-accent">agents.conf</code> file
            defines who does what. Markdown prompts tell each agent their role
            and current tasks. A shared context file lets them pass information
            between cycles. And a single bash script —{" "}
            <code className="rounded bg-card px-1.5 py-0.5 font-mono text-xs text-accent">auto-agent.sh</code> — runs the whole thing.
          </p>

          <h2 className="text-xl font-semibold text-foreground">
            Agent-agnostic by design
          </h2>
          <p>
            The key insight: we don&apos;t care which AI tool you use.
            OrchyStraw works with Claude Code, Codex, Gemini CLI, Aider,
            Windsurf, Cursor — anything that can read a prompt and modify files.
            Your agents are real coding tools, not chat wrappers pretending to
            write code.
          </p>
          <p>
            This means you can mix models. Run your backend agent on Claude
            Opus, your frontend agent on Gemini, and your QA agent on GPT. Each
            tool brings its strengths. OrchyStraw just coordinates them.
          </p>

          <h2 className="text-xl font-semibold text-foreground">
            File ownership prevents chaos
          </h2>
          <p>
            The hardest problem in multi-agent coding isn&apos;t getting agents
            to write code — it&apos;s stopping them from overwriting each
            other&apos;s work. OrchyStraw solves this with file ownership
            boundaries defined in{" "}
            <code className="rounded bg-card px-1.5 py-0.5 font-mono text-xs text-accent">agents.conf</code>. The backend agent owns{" "}
            <code className="rounded bg-card px-1.5 py-0.5 font-mono text-xs text-accent">src/core/</code>, the web agent owns{" "}
            <code className="rounded bg-card px-1.5 py-0.5 font-mono text-xs text-accent">site/</code>, and neither can touch the other&apos;s files.
          </p>

          <h2 className="text-xl font-semibold text-foreground">
            What&apos;s next
          </h2>
          <p>
            We&apos;re building OrchyStraw in the open. The core orchestrator is
            MIT-licensed at{" "}
            <a
              href="https://github.com/ChetanSarda99/openOrchyStraw"
              target="_blank"
              rel="noopener noreferrer"
              className="text-accent hover:underline"
            >
              openOrchyStraw
            </a>
            . The pro version adds a Tauri desktop app, Pixel Agents
            visualization, token optimization, and smart cycling.
          </p>
          <p>
            If you&apos;re tired of agent frameworks that want to own your
            entire stack, give OrchyStraw a try. It&apos;s just bash and
            markdown. That&apos;s the whole point.
          </p>
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
      </article>
    </main>
  );
}
