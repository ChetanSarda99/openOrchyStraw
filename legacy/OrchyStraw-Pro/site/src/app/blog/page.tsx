import type { Metadata } from "next";
import { ArrowLeft } from "lucide-react";

export const metadata: Metadata = {
  title: "Blog — OrchyStraw",
  description: "Articles about multi-agent AI coding orchestration, developer tools, and building with OrchyStraw.",
};

const posts = [
  {
    slug: "how-orchystraw-works",
    title: "How OrchyStraw Runs 9 AI Agents on One Codebase",
    date: "2026-03-20",
    summary:
      "A technical deep-dive into agents.conf, shared context, file ownership, and the orchestration cycle.",
  },
  {
    slug: "building-in-public",
    title: "Building in Public with AI Agents",
    date: "2026-03-20",
    summary:
      "We built an AI agent orchestrator using AI agents. Here's what 18 cycles of meta-development taught us.",
  },
  {
    slug: "why-we-built-orchystraw",
    title: "Why We Built OrchyStraw",
    date: "2026-03-20",
    summary:
      "Every multi-agent framework wants you to install their runtime. We just wanted bash and markdown.",
  },
];

export default function BlogPage() {
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

        <h1 className="text-3xl font-bold tracking-tight sm:text-4xl">Blog</h1>
        <p className="mt-3 text-muted">
          Thoughts on multi-agent orchestration, developer tools, and building
          in the open.
        </p>

        <div className="mt-12 space-y-8">
          {posts.map((post) => (
            <a
              key={post.slug}
              href={`/blog/${post.slug}`}
              className="block rounded-xl border border-card-border bg-card p-6 transition-colors hover:border-accent/30"
            >
              <time className="text-xs text-muted font-mono">{post.date}</time>
              <h2 className="mt-2 text-lg font-semibold">{post.title}</h2>
              <p className="mt-2 text-sm text-muted">{post.summary}</p>
            </a>
          ))}
        </div>
      </div>
    </main>
  );
}
