"use client";

import {
  ArrowLeft,
  ChevronDown,
  ChevronRight,
  Clock,
  GitCommit,
  RotateCcw,
  FileCode,
  CheckCircle2,
  AlertCircle,
  Bot,
} from "lucide-react";
import { useState, useCallback } from "react";

interface FileChange {
  path: string;
  additions: number;
  deletions: number;
}

interface AgentSnapshot {
  agent: string;
  model: string;
  status: "done" | "blocked" | "standby";
  summary: string;
  files: FileChange[];
  duration: string;
}

interface Checkpoint {
  cycle: number;
  timestamp: string;
  agents: AgentSnapshot[];
  commitHash: string;
  totalFiles: number;
  totalAdditions: number;
  totalDeletions: number;
}

const mockCheckpoints: Checkpoint[] = [
  {
    cycle: 5,
    timestamp: "2026-03-20 09:04",
    commitHash: "46b8f5c",
    totalFiles: 8,
    totalAdditions: 342,
    totalDeletions: 47,
    agents: [
      {
        agent: "06-Backend",
        model: "claude",
        status: "done",
        summary: "Added token budget modules + integration tests",
        duration: "4m 12s",
        files: [
          { path: "src/core/token-budget.sh", additions: 89, deletions: 0 },
          { path: "src/core/token-tracker.sh", additions: 67, deletions: 0 },
          { path: "tests/core/test-token-budget.sh", additions: 54, deletions: 0 },
        ],
      },
      {
        agent: "11-Web",
        model: "gemini",
        status: "done",
        summary: "Phase 12 — checkpoints timeline + diff viewer pages",
        duration: "3m 45s",
        files: [
          { path: "site/src/app/checkpoints/page.tsx", additions: 78, deletions: 0 },
          { path: "site/src/app/diff-viewer/page.tsx", additions: 54, deletions: 0 },
        ],
      },
      {
        agent: "09-QA",
        model: "claude",
        status: "standby",
        summary: "Waiting for backend + web changes to land",
        duration: "—",
        files: [],
      },
      {
        agent: "03-PM",
        model: "claude",
        status: "done",
        summary: "Updated all agent prompts, session tracker, backlog priorities",
        duration: "2m 30s",
        files: [
          { path: "prompts/03-pm/03-pm.txt", additions: 32, deletions: 18 },
          { path: "prompts/00-shared-context/context.md", additions: 22, deletions: 5 },
        ],
      },
    ],
  },
  {
    cycle: 4,
    timestamp: "2026-03-20 08:31",
    commitHash: "ce2b362",
    totalFiles: 4,
    totalAdditions: 156,
    totalDeletions: 23,
    agents: [
      {
        agent: "06-Backend",
        model: "claude",
        status: "done",
        summary: "Renamed orch_budget_* → orch_token_budget_* in token-budget.sh",
        duration: "2m 08s",
        files: [
          { path: "src/core/token-budget.sh", additions: 45, deletions: 23 },
        ],
      },
      {
        agent: "03-PM",
        model: "claude",
        status: "done",
        summary: "#80 closed, #77 5th false closure tracked, all prompts updated",
        duration: "3m 15s",
        files: [
          { path: "prompts/03-pm/03-pm.txt", additions: 67, deletions: 0 },
          { path: "prompts/00-shared-context/context.md", additions: 44, deletions: 0 },
        ],
      },
      {
        agent: "08-Pixel",
        model: "gemini",
        status: "blocked",
        summary: "Blocked on #77 — standby for emitter integration",
        duration: "—",
        files: [],
      },
    ],
  },
  {
    cycle: 3,
    timestamp: "2026-03-18 13:21",
    commitHash: "a1c9e3f",
    totalFiles: 12,
    totalAdditions: 478,
    totalDeletions: 31,
    agents: [
      {
        agent: "02-CTO",
        model: "claude",
        status: "done",
        summary: "OWN-001 ADR: file ownership boundaries, BUG-009 confirmed P0",
        duration: "5m 02s",
        files: [
          { path: "docs/architecture/OWN-001.md", additions: 120, deletions: 0 },
          { path: "docs/architecture/ORCHESTRATOR-HARDENING.md", additions: 45, deletions: 12 },
        ],
      },
      {
        agent: "06-Backend",
        model: "claude",
        status: "done",
        summary: "Integration smoke test — 42 assertions pass",
        duration: "4m 48s",
        files: [
          { path: "tests/core/test-integration.sh", additions: 189, deletions: 0 },
          { path: "src/core/INTEGRATION-GUIDE.md", additions: 34, deletions: 8 },
        ],
      },
      {
        agent: "03-PM",
        model: "claude",
        status: "done",
        summary: "All agent prompts updated with cycle 3 status",
        duration: "2m 55s",
        files: [
          { path: "prompts/03-pm/03-pm.txt", additions: 45, deletions: 11 },
          { path: "prompts/00-session-tracker/tracker.md", additions: 45, deletions: 0 },
        ],
      },
    ],
  },
];

const statusColors: Record<string, string> = {
  done: "text-status-success",
  blocked: "text-status-error",
  standby: "text-status-warning",
};

const statusIcons: Record<string, typeof CheckCircle2> = {
  done: CheckCircle2,
  blocked: AlertCircle,
  standby: Clock,
};

const modelColors: Record<string, string> = {
  claude: "text-orange-400",
  gemini: "text-status-info",
  codex: "text-status-success",
};

export default function CheckpointsPage() {
  const [expanded, setExpanded] = useState<Record<string, boolean>>({
    "5": true,
  });
  const [expandedAgents, setExpandedAgents] = useState<Record<string, boolean>>(
    {}
  );

  const toggleCycle = useCallback((cycle: number) => {
    setExpanded((prev) => ({ ...prev, [cycle]: !prev[cycle] }));
  }, []);

  const toggleAgent = useCallback((key: string) => {
    setExpandedAgents((prev) => ({ ...prev, [key]: !prev[key] }));
  }, []);

  return (
    <main className="min-h-screen px-4 py-16 sm:px-6 sm:py-24">
      <div className="mx-auto max-w-4xl">
        <a
          href="/"
          className="mb-8 inline-flex items-center gap-1.5 text-sm text-muted transition-colors hover:text-foreground"
        >
          <ArrowLeft className="h-3.5 w-3.5" />
          Back to home
        </a>

        <h1 className="text-3xl font-bold tracking-tight sm:text-4xl">
          Checkpoints Timeline
        </h1>
        <p className="mt-3 text-muted">
          Turn-by-turn snapshots of every orchestration cycle. See what each
          agent did, which files changed, and revert if needed.
        </p>

        {/* Timeline */}
        <div className="relative mt-12">
          {/* Vertical line */}
          <div className="absolute left-4 top-0 bottom-0 w-px bg-card-border sm:left-6" />

          <div className="space-y-6">
            {mockCheckpoints.map((cp) => {
              const isExpanded = expanded[cp.cycle];

              return (
                <div key={cp.cycle} className="relative pl-12 sm:pl-16">
                  {/* Timeline dot */}
                  <div className="absolute left-2.5 top-4 h-3 w-3 rounded-full border-2 border-accent bg-background sm:left-4.5" />

                  {/* Cycle card */}
                  <div className="rounded-xl border border-card-border bg-card">
                    {/* Cycle header */}
                    <button
                      onClick={() => toggleCycle(cp.cycle)}
                      className="flex w-full items-center justify-between px-5 py-4 text-left transition-colors hover:bg-card-border/20"
                    >
                      <div className="flex items-center gap-3">
                        {isExpanded ? (
                          <ChevronDown className="h-4 w-4 text-muted" />
                        ) : (
                          <ChevronRight className="h-4 w-4 text-muted" />
                        )}
                        <div>
                          <span className="text-lg font-semibold">
                            Cycle {cp.cycle}
                          </span>
                          <span className="ml-3 font-mono text-xs text-muted">
                            {cp.timestamp}
                          </span>
                        </div>
                      </div>

                      <div className="flex items-center gap-4 text-xs text-muted">
                        <span className="flex items-center gap-1">
                          <GitCommit className="h-3 w-3" />
                          <code>{cp.commitHash}</code>
                        </span>
                        <span className="hidden sm:inline">
                          {cp.totalFiles} files
                        </span>
                        <span className="hidden text-status-success sm:inline">
                          +{cp.totalAdditions}
                        </span>
                        <span className="hidden text-status-error sm:inline">
                          −{cp.totalDeletions}
                        </span>
                      </div>
                    </button>

                    {/* Expanded agent snapshots */}
                    {isExpanded && (
                      <div className="border-t border-card-border px-5 py-4">
                        <div className="space-y-3">
                          {cp.agents.map((snap) => {
                            const agentKey = `${cp.cycle}-${snap.agent}`;
                            const isAgentExpanded = expandedAgents[agentKey];
                            const StatusIcon =
                              statusIcons[snap.status] ?? Clock;

                            return (
                              <div
                                key={snap.agent}
                                className="rounded-lg border border-card-border/60 bg-background/50"
                              >
                                <button
                                  onClick={() => toggleAgent(agentKey)}
                                  className="flex w-full items-center justify-between px-4 py-3 text-left transition-colors hover:bg-card-border/10"
                                >
                                  <div className="flex items-center gap-3">
                                    <Bot className="h-4 w-4 text-muted" />
                                    <span className="text-sm font-medium">
                                      {snap.agent}
                                    </span>
                                    <span
                                      className={`font-mono text-xs ${modelColors[snap.model] ?? "text-muted"}`}
                                    >
                                      {snap.model}
                                    </span>
                                    <StatusIcon
                                      className={`h-3.5 w-3.5 ${statusColors[snap.status]}`}
                                    />
                                  </div>
                                  <div className="flex items-center gap-3 text-xs text-muted">
                                    {snap.duration !== "—" && (
                                      <span className="flex items-center gap-1">
                                        <Clock className="h-3 w-3" />
                                        {snap.duration}
                                      </span>
                                    )}
                                    {snap.files.length > 0 && (
                                      <span>
                                        {snap.files.length} file
                                        {snap.files.length !== 1 ? "s" : ""}
                                      </span>
                                    )}
                                  </div>
                                </button>

                                {/* Agent details */}
                                <div className="border-t border-card-border/40 px-4 py-3">
                                  <p className="text-sm text-muted">
                                    {snap.summary}
                                  </p>

                                  {isAgentExpanded && snap.files.length > 0 && (
                                    <div className="mt-3 space-y-1.5">
                                      {snap.files.map((f) => (
                                        <div
                                          key={f.path}
                                          className="flex items-center justify-between rounded bg-card px-3 py-1.5 font-mono text-xs"
                                        >
                                          <span className="flex items-center gap-2 text-foreground/80">
                                            <FileCode className="h-3 w-3 text-muted" />
                                            {f.path}
                                          </span>
                                          <span className="flex gap-2">
                                            <span className="text-status-success">
                                              +{f.additions}
                                            </span>
                                            {f.deletions > 0 && (
                                              <span className="text-status-error">
                                                −{f.deletions}
                                              </span>
                                            )}
                                          </span>
                                        </div>
                                      ))}
                                    </div>
                                  )}
                                </div>
                              </div>
                            );
                          })}
                        </div>

                        {/* Revert button */}
                        <div className="mt-4 flex justify-end">
                          <button
                            className="inline-flex items-center gap-1.5 rounded-md border border-card-border px-3 py-1.5 text-xs text-muted transition-colors hover:border-status-error/30 hover:text-status-error"
                            title="Revert to this checkpoint (placeholder)"
                          >
                            <RotateCcw className="h-3 w-3" />
                            Revert to Cycle {cp.cycle}
                          </button>
                        </div>
                      </div>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        </div>

        {/* Explanation */}
        <div className="mt-12 rounded-xl border border-card-border bg-card p-6">
          <h2 className="text-lg font-semibold">How checkpoints work</h2>
          <p className="mt-3 text-sm leading-relaxed text-muted">
            Every orchestration cycle creates a checkpoint — a snapshot of what
            each agent did, which files they touched, and the resulting commit.
            Unlike linear git history, checkpoints are organized by agent, so you
            can see exactly who changed what. The revert button rolls the
            codebase back to the state before that cycle ran, undoing all agent
            changes in one step.
          </p>
        </div>

        <div className="mt-8 text-center">
          <a
            href="/diff-viewer"
            className="inline-flex items-center gap-2 rounded-lg bg-accent px-6 py-3 text-sm font-semibold text-accent-foreground transition-colors hover:bg-accent/90"
          >
            View Diff Viewer
          </a>
        </div>
      </div>
    </main>
  );
}
