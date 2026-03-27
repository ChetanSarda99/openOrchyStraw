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

        <div className="flex items-center gap-6">
          <a
            href="https://github.com/ChetanSarda99/openOrchyStraw"
            target="_blank"
            rel="noopener noreferrer"
            className="text-sm text-muted transition-colors hover:text-foreground"
          >
            Docs
          </a>
          <a
            href="https://github.com/ChetanSarda99/OrchyStraw"
            target="_blank"
            rel="noopener noreferrer"
            className="flex items-center gap-1.5 text-sm text-muted transition-colors hover:text-foreground"
          >
            <Github className="h-4 w-4" />
            GitHub
          </a>
        </div>
      </div>

      <p className="mt-8 text-center text-xs text-muted/50">
        Built with OrchyStraw
      </p>
    </footer>
  );
}
