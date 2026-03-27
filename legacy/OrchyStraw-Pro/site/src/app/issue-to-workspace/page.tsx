"use client";

import {
  ArrowLeft,
  ArrowRight,
  AlertCircle,
  Bot,
  GitPullRequest,
  FileCode,
  CheckCircle2,
  Users,
  Zap,
  ChevronDown,
  ChevronRight,
} from "lucide-react";
import { useState, useCallback } from "react";

interface PipelineStep {
  id: string;
  title: string;
  icon: typeof AlertCircle;
  description: string;
  detail: string;
  color: string;
}

const pipelineSteps: PipelineStep[] = [
  {
    id: "issue",
    title: "GitHub Issue",
    icon: AlertCircle,
    description: "A bug report or feature request lands",
    detail:
      'The PM agent picks up new GitHub issues during its cycle scan. Issues tagged with "orchystraw" or assigned to the repo are automatically triaged and prioritized against the existing backlog.',
    color: "text-status-info",
  },
  {
    id: "triage",
    title: "PM Triage",
    icon: Users,
    description: "PM agent assigns priority and owners",
    detail:
      "The PM reads the issue, maps it to the right agent(s) based on file ownership, assigns a priority (P0–P3), and writes the task into each agent's prompt for the next cycle.",
    color: "text-purple-400",
  },
  {
    id: "workspace",
    title: "Agent Workspace",
    icon: Bot,
    description: "Agents execute in parallel",
    detail:
      "Each assigned agent works in its file ownership zone. The orchestrator runs agents in parallel — backend writes code, QA writes tests, web updates docs. Shared context keeps everyone in sync.",
    color: "text-orange-400",
  },
  {
    id: "review",
    title: "Quality Gates",
    icon: CheckCircle2,
    description: "Merge checklist runs automatically",
    detail:
      "After all agents finish, the merge checklist runs: tests, ownership boundaries, code review, security scan. Blocking issues prevent merge. The QA and CTO agents review changes.",
    color: "text-status-success",
  },
  {
    id: "pr",
    title: "Pull Request",
    icon: GitPullRequest,
    description: "Auto-generated PR with full context",
    detail:
      "OrchyStraw creates a PR with: what changed, which agents worked on it, test results, and the original issue link. The PM summarizes the cycle in the PR description.",
    color: "text-cyan-400",
  },
];

interface ExampleIssue {
  number: number;
  title: string;
  labels: string[];
  priority: string;
  assignedAgents: string[];
  files: string[];
  status: "open" | "in-progress" | "merged";
}

const exampleIssues: ExampleIssue[] = [
  {
    number: 77,
    title: "auto-agent.sh only sources 8/31 modules",
    labels: ["bug", "P0", "backend"],
    priority: "P0",
    assignedAgents: ["06-Backend", "09-QA"],
    files: ["scripts/auto-agent.sh", "tests/core/test-integration.sh"],
    status: "in-progress",
  },
  {
    number: 44,
    title: "Deploy landing page to GitHub Pages",
    labels: ["infra", "P1", "web"],
    priority: "P1",
    assignedAgents: ["11-Web"],
    files: [".github/workflows/deploy.yml", "site/next.config.ts"],
    status: "open",
  },
  {
    number: 39,
    title: "Hero terminal typing animation",
    labels: ["feature", "P2", "web"],
    priority: "P2",
    assignedAgents: ["11-Web"],
    files: ["site/src/components/hero.tsx"],
    status: "merged",
  },
];

const statusStyles = {
  open: { color: "text-status-info", bg: "bg-status-info/10", label: "Open" },
  "in-progress": { color: "text-orange-400", bg: "bg-orange-400/10", label: "In Progress" },
  merged: { color: "text-status-success", bg: "bg-status-success/10", label: "Merged" },
};

export default function IssueToWorkspacePage() {
  const [activeStep, setActiveStep] = useState<string | null>(null);
  const [expandedIssues, setExpandedIssues] = useState<Record<number, boolean>>({
    77: true,
  });

  const toggleStep = useCallback((id: string) => {
    setActiveStep((prev) => (prev === id ? null : id));
  }, []);

  const toggleIssue = useCallback((num: number) => {
    setExpandedIssues((prev) => ({ ...prev, [num]: !prev[num] }));
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
          Issue to Workspace
        </h1>
        <p className="mt-3 text-muted">
          How a GitHub issue becomes a merged PR — the full orchestration
          pipeline from triage to ship.
        </p>

        {/* Pipeline flow */}
        <div className="mt-12">
          <h2 className="mb-6 text-lg font-semibold">Pipeline</h2>

          {/* Step cards */}
          <div className="space-y-3">
            {pipelineSteps.map((step, idx) => {
              const StepIcon = step.icon;
              const isActive = activeStep === step.id;

              return (
                <div key={step.id}>
                  <button
                    onClick={() => toggleStep(step.id)}
                    className="flex w-full items-center gap-4 rounded-xl border border-card-border bg-card px-5 py-4 text-left transition-colors hover:bg-card-border/20"
                  >
                    {/* Step number */}
                    <div className={`flex h-8 w-8 shrink-0 items-center justify-center rounded-full border ${isActive ? "border-accent bg-accent/10" : "border-card-border"}`}>
                      <span className="text-xs font-bold">{idx + 1}</span>
                    </div>

                    <StepIcon className={`h-5 w-5 shrink-0 ${step.color}`} />

                    <div className="min-w-0 flex-1">
                      <span className="text-sm font-semibold">{step.title}</span>
                      <p className="text-xs text-muted">{step.description}</p>
                    </div>

                    {isActive ? (
                      <ChevronDown className="h-4 w-4 shrink-0 text-muted" />
                    ) : (
                      <ChevronRight className="h-4 w-4 shrink-0 text-muted" />
                    )}
                  </button>

                  {isActive && (
                    <div className="ml-4 mt-1 rounded-lg border border-card-border/60 bg-background/50 px-5 py-4 sm:ml-14">
                      <p className="text-sm leading-relaxed text-muted">
                        {step.detail}
                      </p>
                    </div>
                  )}

                  {/* Arrow connector */}
                  {idx < pipelineSteps.length - 1 && (
                    <div className="flex justify-center py-1">
                      <ArrowRight className="h-4 w-4 rotate-90 text-card-border" />
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        </div>

        {/* Example issues */}
        <div className="mt-14">
          <h2 className="mb-6 text-lg font-semibold">Example Issues</h2>
          <div className="space-y-3">
            {exampleIssues.map((issue) => {
              const isExpanded = expandedIssues[issue.number];
              const style = statusStyles[issue.status];

              return (
                <div
                  key={issue.number}
                  className="rounded-xl border border-card-border bg-card"
                >
                  <button
                    onClick={() => toggleIssue(issue.number)}
                    className="flex w-full items-center justify-between px-5 py-4 text-left transition-colors hover:bg-card-border/20"
                  >
                    <div className="flex items-center gap-3 min-w-0">
                      {isExpanded ? (
                        <ChevronDown className="h-4 w-4 shrink-0 text-muted" />
                      ) : (
                        <ChevronRight className="h-4 w-4 shrink-0 text-muted" />
                      )}
                      <span className="font-mono text-xs text-muted">#{issue.number}</span>
                      <span className="text-sm font-medium truncate">{issue.title}</span>
                    </div>
                    <span className={`shrink-0 rounded px-2 py-0.5 text-xs font-medium ${style.color} ${style.bg}`}>
                      {style.label}
                    </span>
                  </button>

                  {isExpanded && (
                    <div className="border-t border-card-border px-5 py-4 space-y-4">
                      {/* Labels */}
                      <div className="flex flex-wrap gap-2">
                        {issue.labels.map((label) => (
                          <span
                            key={label}
                            className="rounded-full border border-card-border px-2.5 py-0.5 text-xs text-muted"
                          >
                            {label}
                          </span>
                        ))}
                      </div>

                      {/* Assigned agents */}
                      <div>
                        <span className="text-xs font-medium text-muted">Assigned agents</span>
                        <div className="mt-1.5 flex flex-wrap gap-2">
                          {issue.assignedAgents.map((agent) => (
                            <span
                              key={agent}
                              className="inline-flex items-center gap-1.5 rounded-md bg-card-border/30 px-2.5 py-1 text-xs font-medium"
                            >
                              <Bot className="h-3 w-3 text-orange-400" />
                              {agent}
                            </span>
                          ))}
                        </div>
                      </div>

                      {/* Files */}
                      <div>
                        <span className="text-xs font-medium text-muted">Files touched</span>
                        <div className="mt-1.5 space-y-1">
                          {issue.files.map((file) => (
                            <div
                              key={file}
                              className="flex items-center gap-2 rounded bg-background/80 px-3 py-1.5 font-mono text-xs text-foreground/80"
                            >
                              <FileCode className="h-3 w-3 text-muted" />
                              {file}
                            </div>
                          ))}
                        </div>
                      </div>
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        </div>

        {/* Explanation */}
        <div className="mt-12 rounded-xl border border-card-border bg-card p-6">
          <h2 className="text-lg font-semibold">How it works end-to-end</h2>
          <p className="mt-3 text-sm leading-relaxed text-muted">
            OrchyStraw turns GitHub issues into shipped code through automated
            orchestration. The PM agent scans for new issues, triages them
            against the backlog, and assigns work to the right agents based on
            file ownership zones. Agents execute in parallel during the next
            cycle, writing code, tests, and docs within their boundaries. After
            execution, the merge checklist validates everything before a PR is
            created. The entire pipeline — from issue to merged PR — can run
            unattended across multiple cycles.
          </p>
        </div>

        <div className="mt-8 flex justify-center gap-4">
          <a
            href="/todos"
            className="inline-flex items-center gap-2 rounded-lg border border-card-border px-5 py-3 text-sm font-medium text-muted transition-colors hover:text-foreground"
          >
            <Zap className="h-4 w-4" />
            Merge Checklist
          </a>
          <a
            href="/checkpoints"
            className="inline-flex items-center gap-2 rounded-lg bg-accent px-6 py-3 text-sm font-semibold text-accent-foreground transition-colors hover:bg-accent/90"
          >
            View Checkpoints
          </a>
        </div>
      </div>
    </main>
  );
}
