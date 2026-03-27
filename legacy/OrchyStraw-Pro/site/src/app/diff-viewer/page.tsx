"use client";

import {
  ArrowLeft,
  GitCompare,
  ChevronDown,
  FileCode,
  Filter,
  Bot,
} from "lucide-react";
import { useState, useMemo, useCallback } from "react";

interface DiffLine {
  type: "add" | "remove" | "context";
  content: string;
  oldLine?: number;
  newLine?: number;
}

interface FileDiff {
  path: string;
  agent: string;
  cycle: number;
  additions: number;
  deletions: number;
  lines: DiffLine[];
}

const mockDiffs: FileDiff[] = [
  {
    path: "src/core/token-budget.sh",
    agent: "06-Backend",
    cycle: 5,
    additions: 12,
    deletions: 4,
    lines: [
      { type: "context", content: "#!/usr/bin/env bash", oldLine: 1, newLine: 1 },
      { type: "context", content: '# token-budget.sh — Track and enforce token budgets per agent', oldLine: 2, newLine: 2 },
      { type: "context", content: "", oldLine: 3, newLine: 3 },
      { type: "remove", content: 'orch_budget_init() {', oldLine: 4 },
      { type: "remove", content: '  local budget_file="${ORCH_STATE_DIR}/budget.json"', oldLine: 5 },
      { type: "add", content: 'orch_token_budget_init() {', newLine: 4 },
      { type: "add", content: '  local budget_file="${ORCH_STATE_DIR}/token-budget.json"', newLine: 5 },
      { type: "context", content: '  if [[ ! -f "$budget_file" ]]; then', oldLine: 6, newLine: 6 },
      { type: "context", content: '    echo "{}" > "$budget_file"', oldLine: 7, newLine: 7 },
      { type: "context", content: "  fi", oldLine: 8, newLine: 8 },
      { type: "context", content: "}", oldLine: 9, newLine: 9 },
      { type: "context", content: "", oldLine: 10, newLine: 10 },
      { type: "remove", content: 'orch_budget_check() {', oldLine: 11 },
      { type: "remove", content: '  local agent="$1" limit="$2"', oldLine: 12 },
      { type: "add", content: 'orch_token_budget_check() {', newLine: 11 },
      { type: "add", content: '  local agent_id="$1" limit="$2"', newLine: 12 },
      { type: "add", content: '  local budget_file="${ORCH_STATE_DIR}/token-budget.json"', newLine: 13 },
      { type: "context", content: '  local current', oldLine: 13, newLine: 14 },
      { type: "add", content: '  current=$(jq -r ".\"${agent_id}\" // 0" "$budget_file")', newLine: 15 },
      { type: "add", content: '  if (( current >= limit )); then', newLine: 16 },
      { type: "add", content: '    orch_log_warn "Token budget exceeded for ${agent_id}: ${current}/${limit}"', newLine: 17 },
      { type: "add", content: "    return 1", newLine: 18 },
      { type: "add", content: "  fi", newLine: 19 },
      { type: "context", content: "}", oldLine: 14, newLine: 20 },
    ],
  },
  {
    path: "site/src/app/checkpoints/page.tsx",
    agent: "11-Web",
    cycle: 5,
    additions: 8,
    deletions: 0,
    lines: [
      { type: "context", content: '"use client";', oldLine: 1, newLine: 1 },
      { type: "context", content: "", oldLine: 2, newLine: 2 },
      { type: "add", content: "import type { Metadata } from \"next\";", newLine: 3 },
      { type: "add", content: "import {", newLine: 4 },
      { type: "add", content: "  ArrowLeft,", newLine: 5 },
      { type: "add", content: "  ChevronDown,", newLine: 6 },
      { type: "add", content: "  ChevronRight,", newLine: 7 },
      { type: "add", content: "  Clock,", newLine: 8 },
      { type: "add", content: "  GitCommit,", newLine: 9 },
      { type: "add", content: '} from "lucide-react";', newLine: 10 },
      { type: "context", content: "", oldLine: 3, newLine: 11 },
    ],
  },
  {
    path: "prompts/03-pm/03-pm.txt",
    agent: "03-PM",
    cycle: 5,
    additions: 6,
    deletions: 2,
    lines: [
      { type: "context", content: "## Current Tasks", oldLine: 42, newLine: 42 },
      { type: "context", content: "", oldLine: 43, newLine: 43 },
      { type: "remove", content: "### Cycle 4 Status", oldLine: 44 },
      { type: "remove", content: "- #80 CLOSED — token budget rename shipped", oldLine: 45 },
      { type: "add", content: "### Cycle 5 Status", newLine: 44 },
      { type: "add", content: "- #80 CLOSED — token budget rename verified", newLine: 45 },
      { type: "add", content: "- #77 5th attempt — CS manual edit still pending", newLine: 46 },
      { type: "add", content: "- Web: Phase 12 checkpoints + diff viewer shipped", newLine: 47 },
      { type: "add", content: "- All agent prompts updated for cycle 5", newLine: 48 },
      { type: "add", content: "- Session tracker updated", newLine: 49 },
      { type: "context", content: "", oldLine: 46, newLine: 50 },
    ],
  },
  {
    path: "tests/core/test-token-budget.sh",
    agent: "06-Backend",
    cycle: 4,
    additions: 5,
    deletions: 3,
    lines: [
      { type: "context", content: "#!/usr/bin/env bash", oldLine: 1, newLine: 1 },
      { type: "context", content: '# test-token-budget.sh — unit tests', oldLine: 2, newLine: 2 },
      { type: "context", content: "", oldLine: 3, newLine: 3 },
      { type: "remove", content: 'test_budget_init() {', oldLine: 4 },
      { type: "remove", content: '  source src/core/token-budget.sh', oldLine: 5 },
      { type: "remove", content: "  orch_budget_init", oldLine: 6 },
      { type: "add", content: 'test_token_budget_init() {', newLine: 4 },
      { type: "add", content: '  source src/core/token-budget.sh', newLine: 5 },
      { type: "add", content: "  orch_token_budget_init", newLine: 6 },
      { type: "add", content: '  assert_file_exists "${ORCH_STATE_DIR}/token-budget.json"', newLine: 7 },
      { type: "add", content: '  assert_eq "$(cat "${ORCH_STATE_DIR}/token-budget.json")" "{}"', newLine: 8 },
      { type: "context", content: "}", oldLine: 7, newLine: 9 },
    ],
  },
];

const agents = ["All", ...Array.from(new Set(mockDiffs.map((d) => d.agent)))];
const cycles = ["All", ...Array.from(new Set(mockDiffs.map((d) => String(d.cycle))))];

const lineTypeStyles: Record<string, string> = {
  add: "bg-status-success/10 text-status-success",
  remove: "bg-status-error/10 text-status-error",
  context: "text-foreground/60",
};

const linePrefix: Record<string, string> = {
  add: "+",
  remove: "−",
  context: " ",
};

export default function DiffViewerPage() {
  const [agentFilter, setAgentFilter] = useState("All");
  const [cycleFilter, setCycleFilter] = useState("All");

  const filtered = useMemo(() => {
    return mockDiffs.filter((d) => {
      if (agentFilter !== "All" && d.agent !== agentFilter) return false;
      if (cycleFilter !== "All" && String(d.cycle) !== cycleFilter) return false;
      return true;
    });
  }, [agentFilter, cycleFilter]);

  const totalAdded = filtered.reduce((s, d) => s + d.additions, 0);
  const totalRemoved = filtered.reduce((s, d) => s + d.deletions, 0);

  return (
    <main className="min-h-screen px-4 py-16 sm:px-6 sm:py-24">
      <div className="mx-auto max-w-5xl">
        <a
          href="/"
          className="mb-8 inline-flex items-center gap-1.5 text-sm text-muted transition-colors hover:text-foreground"
        >
          <ArrowLeft className="h-3.5 w-3.5" />
          Back to home
        </a>

        <div className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
          <div>
            <h1 className="text-3xl font-bold tracking-tight sm:text-4xl">
              Diff Viewer
            </h1>
            <p className="mt-3 text-muted">
              Side-by-side diffs showing per-agent, per-cycle changes across the
              codebase.
            </p>
          </div>

          {/* Stats */}
          <div className="flex gap-4 text-sm">
            <span className="text-muted">
              {filtered.length} file{filtered.length !== 1 ? "s" : ""}
            </span>
            <span className="text-status-success">+{totalAdded}</span>
            <span className="text-status-error">−{totalRemoved}</span>
          </div>
        </div>

        {/* Filters */}
        <div className="mt-8 flex flex-wrap items-center gap-4">
          <div className="flex items-center gap-2">
            <Filter className="h-4 w-4 text-muted" />
            <span className="text-sm text-muted">Filter:</span>
          </div>

          <div className="flex items-center gap-2">
            <Bot className="h-3.5 w-3.5 text-muted" />
            <select
              value={agentFilter}
              onChange={(e) => setAgentFilter(e.target.value)}
              className="rounded-md border border-card-border bg-card px-3 py-1.5 text-xs text-foreground focus:outline-none focus:ring-1 focus:ring-accent"
            >
              {agents.map((a) => (
                <option key={a} value={a}>
                  {a}
                </option>
              ))}
            </select>
          </div>

          <div className="flex items-center gap-2">
            <GitCompare className="h-3.5 w-3.5 text-muted" />
            <select
              value={cycleFilter}
              onChange={(e) => setCycleFilter(e.target.value)}
              className="rounded-md border border-card-border bg-card px-3 py-1.5 text-xs text-foreground focus:outline-none focus:ring-1 focus:ring-accent"
            >
              {cycles.map((c) => (
                <option key={c} value={c}>
                  {c === "All" ? "All Cycles" : `Cycle ${c}`}
                </option>
              ))}
            </select>
          </div>
        </div>

        {/* Diffs */}
        <div className="mt-8 space-y-6">
          {filtered.length === 0 && (
            <div className="rounded-xl border border-card-border bg-card p-8 text-center text-sm text-muted">
              No diffs match the current filters.
            </div>
          )}

          {filtered.map((diff, i) => (
            <div
              key={`${diff.path}-${diff.cycle}`}
              className="overflow-hidden rounded-xl border border-card-border"
            >
              {/* File header */}
              <div className="flex items-center justify-between border-b border-card-border bg-card px-4 py-3">
                <div className="flex items-center gap-3">
                  <FileCode className="h-4 w-4 text-muted" />
                  <span className="font-mono text-sm text-foreground/90">
                    {diff.path}
                  </span>
                </div>
                <div className="flex items-center gap-3 text-xs">
                  <span className="rounded bg-accent/10 px-2 py-0.5 font-mono text-accent">
                    {diff.agent}
                  </span>
                  <span className="text-muted">Cycle {diff.cycle}</span>
                  <span className="text-status-success">+{diff.additions}</span>
                  <span className="text-status-error">−{diff.deletions}</span>
                </div>
              </div>

              {/* Diff content — unified view */}
              <div className="overflow-x-auto bg-code-bg">
                <table className="w-full font-mono text-xs">
                  <tbody>
                    {diff.lines.map((line, li) => (
                      <tr
                        key={li}
                        className={lineTypeStyles[line.type]}
                      >
                        <td className="w-12 select-none px-3 py-0.5 text-right text-foreground/20">
                          {line.oldLine ?? ""}
                        </td>
                        <td className="w-12 select-none px-3 py-0.5 text-right text-foreground/20">
                          {line.newLine ?? ""}
                        </td>
                        <td className="w-6 select-none py-0.5 text-center text-foreground/30">
                          {linePrefix[line.type]}
                        </td>
                        <td className="whitespace-pre py-0.5 pr-4">
                          {line.content}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          ))}
        </div>

        {/* Explanation */}
        <div className="mt-12 rounded-xl border border-card-border bg-card p-6">
          <h2 className="text-lg font-semibold">How the diff viewer works</h2>
          <p className="mt-3 text-sm leading-relaxed text-muted">
            Each orchestration cycle produces changes from multiple agents. This
            viewer shows unified diffs organized by file, with agent and cycle
            metadata attached. Filter by agent to see exactly what one team
            member changed, or by cycle to review a full turn of work. In
            production, these diffs come from{" "}
            <code className="rounded bg-card-border px-1.5 py-0.5 text-accent">
              git diff
            </code>{" "}
            between cycle checkpoints.
          </p>
        </div>

        <div className="mt-8 text-center">
          <a
            href="/checkpoints"
            className="inline-flex items-center gap-2 rounded-lg bg-accent px-6 py-3 text-sm font-semibold text-accent-foreground transition-colors hover:bg-accent/90"
          >
            View Checkpoints Timeline
          </a>
        </div>
      </div>
    </main>
  );
}
