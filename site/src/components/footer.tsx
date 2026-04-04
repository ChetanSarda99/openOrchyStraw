import { Github } from "lucide-react";

export function Footer() {
  return (
    <footer className="border-t border-card-border px-4 py-12 sm:px-6 sm:py-16">
      <div className="mx-auto flex max-w-5xl flex-col items-center gap-8 sm:flex-row sm:justify-between sm:items-start">
        <div className="flex flex-col items-center gap-3 sm:items-start">
          <span
            className="font-mono font-medium text-foreground tracking-tight"
            style={{ fontSize: "var(--font-size-small)" }}
          >
            orchystraw
          </span>
          <span
            className="inline-flex items-center gap-1.5 rounded-md border border-card-border px-2 py-0.5 font-mono text-text-tertiary"
            style={{ fontSize: "var(--font-size-micro)" }}
          >
            MIT License
          </span>
        </div>

        <div className="flex items-center gap-6">
          <a
            href="https://github.com/ChetanSarda99/openOrchyStraw"
            target="_blank"
            rel="noopener noreferrer"
            className="text-text-secondary transition-colors hover:text-foreground"
            style={{ fontSize: "var(--font-size-small)" }}
          >
            Documentation
          </a>
          <a
            href="https://github.com/ChetanSarda99/openOrchyStraw"
            target="_blank"
            rel="noopener noreferrer"
            className="flex items-center gap-1.5 text-text-secondary transition-colors hover:text-foreground"
            style={{ fontSize: "var(--font-size-small)" }}
          >
            <Github className="h-4 w-4" />
            GitHub
          </a>
        </div>
      </div>
    </footer>
  );
}
