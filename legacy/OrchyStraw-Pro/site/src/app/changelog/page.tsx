import type { Metadata } from "next";
import { ArrowLeft } from "lucide-react";

export const metadata: Metadata = {
  title: "Changelog — OrchyStraw",
  description: "Release notes and updates for OrchyStraw multi-agent orchestration.",
};

const releases = [
  {
    version: "v0.2.0",
    date: "2026-03-20",
    tag: "Latest",
    summary: "Token optimization, smart cycling, and advanced orchestration modules.",
    changes: [
      "Token-efficient context filtering — 30-70% savings over full broadcast",
      "Smart cycle scheduling with agent frequency control",
      "Prompt compression for long-running sessions",
      "Usage monitoring and model budget tracking",
      "Agent-as-tool pattern for composable workflows",
      "Self-healing error recovery with automatic retries",
      "Quality gates for automated code review checks",
      "Init-project scaffolding command for new projects",
      "Pixel Agents fork with character mapping and overlay system",
      "Landing page SEO, social proof, and OG image generation",
      "25 issues closed across 5 sprint cycles",
    ],
  },
  {
    version: "v0.1.0",
    date: "2026-03-18",
    tag: "Stable",
    summary: "First tagged release. Core orchestrator hardened and shipped.",
    changes: [
      "8 core bash modules: logger, error-handler, cycle-state, agent-timeout, dry-run, config-validator, lock-file, bash-version",
      "Integration test suite — 42 assertions across all modules",
      "File ownership boundaries enforced via agents.conf",
      "Shared context communication between agents",
      "Auto-cycle mode for unattended multi-cycle runs",
      "Security audit passed (conditional — eval injection documented)",
      "QA review passed — 9/9 tests green",
      ".gitignore hardened for sensitive patterns",
      "Step-by-step integration guide for protected files",
    ],
  },
];

export default function ChangelogPage() {
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
          Changelog
        </h1>
        <p className="mt-3 text-muted">
          Release notes and updates for OrchyStraw.
        </p>

        <div className="mt-12 space-y-16">
          {releases.map((release) => (
            <article key={release.version} className="relative">
              <div className="flex items-center gap-3">
                <h2 className="font-mono text-xl font-bold">
                  {release.version}
                </h2>
                {release.tag && (
                  <span className="rounded-full border border-accent/30 bg-accent/10 px-2.5 py-0.5 font-mono text-xs text-accent">
                    {release.tag}
                  </span>
                )}
              </div>
              <time className="mt-1 block text-sm text-muted">
                {release.date}
              </time>
              <p className="mt-3 text-sm text-foreground/80">
                {release.summary}
              </p>
              <ul className="mt-4 space-y-2">
                {release.changes.map((change, i) => (
                  <li
                    key={i}
                    className="flex items-start gap-2 text-sm text-muted"
                  >
                    <span className="mt-1.5 h-1.5 w-1.5 shrink-0 rounded-full bg-accent/60" />
                    {change}
                  </li>
                ))}
              </ul>
            </article>
          ))}
        </div>
      </div>
    </main>
  );
}
