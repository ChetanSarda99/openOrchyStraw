import { Github } from "lucide-react";

export function Footer() {
  return (
    <footer className="border-t border-card-border px-6 py-12">
      <div className="mx-auto flex max-w-5xl flex-col items-center gap-6 sm:flex-row sm:justify-between">
        <div className="flex items-center gap-3">
          <span className="font-mono text-sm font-bold text-accent">
            orchystraw
          </span>
          <span className="text-xs text-muted">MIT License</span>
        </div>

        <div className="grid w-full grid-cols-2 gap-8 sm:grid-cols-4 sm:w-auto">
          <div className="flex flex-col gap-2">
            <span className="text-xs font-semibold uppercase tracking-wider text-muted/60">Product</span>
            <a href="/playground" className="text-sm text-muted transition-colors hover:text-foreground">Playground</a>
            <a href="/compare" className="text-sm text-muted transition-colors hover:text-foreground">Compare</a>
            <a href="/benchmarks" className="text-sm text-muted transition-colors hover:text-foreground">Benchmarks</a>
            <a href="/changelog" className="text-sm text-muted transition-colors hover:text-foreground">Changelog</a>
            <a href="/blog" className="text-sm text-muted transition-colors hover:text-foreground">Blog</a>
          </div>
          <div className="flex flex-col gap-2">
            <span className="text-xs font-semibold uppercase tracking-wider text-muted/60">Workflow</span>
            <a href="/checkpoints" className="text-sm text-muted transition-colors hover:text-foreground">Checkpoints</a>
            <a href="/diff-viewer" className="text-sm text-muted transition-colors hover:text-foreground">Diff Viewer</a>
            <a href="/todos" className="text-sm text-muted transition-colors hover:text-foreground">Merge Checklist</a>
            <a href="/issue-to-workspace" className="text-sm text-muted transition-colors hover:text-foreground">Issue to Workspace</a>
            <a href="/create-pr" className="text-sm text-muted transition-colors hover:text-foreground">Create PR</a>
          </div>
          <div className="flex flex-col gap-2">
            <span className="text-xs font-semibold uppercase tracking-wider text-muted/60">Docs</span>
            <a href="/docs/architecture" className="text-sm text-muted transition-colors hover:text-foreground">Architecture</a>
            <a href="/docs/cli" className="text-sm text-muted transition-colors hover:text-foreground">CLI Reference</a>
            <a href="/docs/parallel-agents" className="text-sm text-muted transition-colors hover:text-foreground">Parallel Agents</a>
            <a href="/docs/checkpoints" className="text-sm text-muted transition-colors hover:text-foreground">Checkpoints</a>
            <a href="/docs/reviewing-changes" className="text-sm text-muted transition-colors hover:text-foreground">Reviewing Changes</a>
            <a href="/docs/issue-to-pr" className="text-sm text-muted transition-colors hover:text-foreground">Issue to PR</a>
            <a href="/docs/merge-checklist" className="text-sm text-muted transition-colors hover:text-foreground">Merge Checklist</a>
          </div>
          <div className="flex flex-col gap-2">
            <span className="text-xs font-semibold uppercase tracking-wider text-muted/60">Links</span>
            <a
              href="https://github.com/ChetanSarda99/OrchyStraw-Pro"
              target="_blank"
              rel="noopener noreferrer"
              className="flex items-center gap-1.5 text-sm text-muted transition-colors hover:text-foreground"
            >
              <Github className="h-4 w-4" />
              GitHub
            </a>
          </div>
        </div>
      </div>

      <p className="mt-8 text-center text-xs text-muted/50">
        Built with OrchyStraw
      </p>
    </footer>
  );
}
