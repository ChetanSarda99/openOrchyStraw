"use client";

import {
  ArrowLeft,
  CheckCircle2,
  XCircle,
  AlertTriangle,
  ChevronDown,
  ChevronRight,
  Shield,
  FileCheck,
  TestTube,
  Eye,
  Lock,
  Bot,
} from "lucide-react";
import { useState, useCallback } from "react";

interface CheckItem {
  id: string;
  label: string;
  description: string;
  status: "pass" | "fail" | "warn";
  details?: string;
}

interface GateSection {
  id: string;
  title: string;
  icon: typeof Shield;
  items: CheckItem[];
}

const mockGates: GateSection[] = [
  {
    id: "tests",
    title: "Test Gate",
    icon: TestTube,
    items: [
      {
        id: "unit",
        label: "Unit tests pass",
        description: "32/32 unit tests across 8 modules",
        status: "pass",
        details: "All tests in tests/core/ passed in 1.4s",
      },
      {
        id: "integration",
        label: "Integration tests pass",
        description: "42/42 assertions in integration smoke test",
        status: "pass",
        details: "test-integration.sh — all modules source correctly, functions callable",
      },
      {
        id: "build",
        label: "Site build succeeds",
        description: "Next.js static export with 0 errors",
        status: "pass",
        details: "npm run build — 22 pages generated, 0 type errors",
      },
    ],
  },
  {
    id: "ownership",
    title: "File Ownership",
    icon: Lock,
    items: [
      {
        id: "boundaries",
        label: "No cross-agent file conflicts",
        description: "Each agent touched only files in their ownership zone",
        status: "pass",
        details: "06-Backend: src/core/, tests/core/ — 11-Web: site/ — 03-PM: prompts/",
      },
      {
        id: "protected",
        label: "Protected files untouched",
        description: "auto-agent.sh, agents.conf, CLAUDE.md unchanged",
        status: "pass",
        details: "No modifications to scripts/auto-agent.sh, scripts/agents.conf, or CLAUDE.md",
      },
      {
        id: "overlap",
        label: "Shared context properly appended",
        description: "Agents append only — no overwrites in shared context",
        status: "warn",
        details: "context.md was reset at cycle start (expected), all agents appended correctly",
      },
    ],
  },
  {
    id: "review",
    title: "Code Review",
    icon: Eye,
    items: [
      {
        id: "qa-verdict",
        label: "QA verdict",
        description: "09-QA review of all changes this cycle",
        status: "pass",
        details: "QA report: CONDITIONAL PASS — no new bugs, HIGH-01 eval fix still pending CS action",
      },
      {
        id: "cto-review",
        label: "CTO architecture review",
        description: "02-CTO reviewed new modules and patterns",
        status: "pass",
        details: "Token budget modules follow established patterns. Naming convention aligned.",
      },
      {
        id: "style",
        label: "Code style consistent",
        description: "Bash: set -euo pipefail, double-source guards, no eval",
        status: "pass",
        details: "All new .sh files follow BASH-001 ADR conventions",
      },
    ],
  },
  {
    id: "security",
    title: "Security Scan",
    icon: Shield,
    items: [
      {
        id: "eval-injection",
        label: "No eval injection",
        description: "No unquoted eval or unsafe variable expansion",
        status: "pass",
        details: "Scanned all src/core/*.sh — zero eval calls, all variable expansions quoted",
      },
      {
        id: "secrets",
        label: "No secrets in committed files",
        description: ".gitignore covers logs/, .env, credentials",
        status: "pass",
        details: ".gitignore reviewed — sensitive patterns covered per MEDIUM-01 fix",
      },
      {
        id: "high-01",
        label: "HIGH-01 eval vulnerability",
        description: "commit_by_ownership() eval injection in auto-agent.sh",
        status: "fail",
        details: "STILL OPEN — requires CS to manually edit scripts/auto-agent.sh. Documented fix available.",
      },
    ],
  },
];

const statusConfig = {
  pass: { color: "text-green-400", bg: "bg-green-400/10", icon: CheckCircle2, label: "Pass" },
  fail: { color: "text-red-400", bg: "bg-red-400/10", icon: XCircle, label: "Fail" },
  warn: { color: "text-yellow-400", bg: "bg-yellow-400/10", icon: AlertTriangle, label: "Warning" },
};

function getGateSummary(items: CheckItem[]) {
  const pass = items.filter((i) => i.status === "pass").length;
  const fail = items.filter((i) => i.status === "fail").length;
  const warn = items.filter((i) => i.status === "warn").length;
  if (fail > 0) return { status: "fail" as const, text: `${fail} blocking` };
  if (warn > 0) return { status: "warn" as const, text: `${pass} pass, ${warn} warning` };
  return { status: "pass" as const, text: `${pass}/${items.length} pass` };
}

export default function TodosPage() {
  const [expanded, setExpanded] = useState<Record<string, boolean>>({
    tests: true,
    ownership: true,
    review: true,
    security: true,
  });
  const [expandedItems, setExpandedItems] = useState<Record<string, boolean>>({});

  const toggleSection = useCallback((id: string) => {
    setExpanded((prev) => ({ ...prev, [id]: !prev[id] }));
  }, []);

  const toggleItem = useCallback((id: string) => {
    setExpandedItems((prev) => ({ ...prev, [id]: !prev[id] }));
  }, []);

  const totalPass = mockGates.flatMap((g) => g.items).filter((i) => i.status === "pass").length;
  const totalFail = mockGates.flatMap((g) => g.items).filter((i) => i.status === "fail").length;
  const totalWarn = mockGates.flatMap((g) => g.items).filter((i) => i.status === "warn").length;
  const totalItems = mockGates.flatMap((g) => g.items).length;

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
          Merge Checklist
        </h1>
        <p className="mt-3 text-muted">
          Pre-PR quality gates. Every check must pass before agents can merge
          their cycle output.
        </p>

        {/* Summary bar */}
        <div className="mt-8 flex flex-wrap items-center gap-4 rounded-xl border border-card-border bg-card px-5 py-4">
          <div className="flex items-center gap-2">
            <Bot className="h-4 w-4 text-muted" />
            <span className="text-sm font-medium">Cycle 5 — Pre-merge status</span>
          </div>
          <div className="flex items-center gap-4 text-sm">
            <span className="flex items-center gap-1.5 text-green-400">
              <CheckCircle2 className="h-3.5 w-3.5" />
              {totalPass} pass
            </span>
            {totalWarn > 0 && (
              <span className="flex items-center gap-1.5 text-yellow-400">
                <AlertTriangle className="h-3.5 w-3.5" />
                {totalWarn} warning
              </span>
            )}
            {totalFail > 0 && (
              <span className="flex items-center gap-1.5 text-red-400">
                <XCircle className="h-3.5 w-3.5" />
                {totalFail} blocking
              </span>
            )}
          </div>
          <div className="ml-auto">
            {totalFail > 0 ? (
              <span className="rounded-md bg-red-400/10 px-3 py-1 text-xs font-medium text-red-400">
                BLOCKED
              </span>
            ) : totalWarn > 0 ? (
              <span className="rounded-md bg-yellow-400/10 px-3 py-1 text-xs font-medium text-yellow-400">
                CONDITIONAL
              </span>
            ) : (
              <span className="rounded-md bg-green-400/10 px-3 py-1 text-xs font-medium text-green-400">
                READY TO MERGE
              </span>
            )}
          </div>
        </div>

        {/* Gate sections */}
        <div className="mt-8 space-y-4">
          {mockGates.map((gate) => {
            const isExpanded = expanded[gate.id];
            const summary = getGateSummary(gate.items);
            const SectionIcon = gate.icon;
            const SummaryIcon = statusConfig[summary.status].icon;

            return (
              <div key={gate.id} className="rounded-xl border border-card-border bg-card">
                <button
                  onClick={() => toggleSection(gate.id)}
                  className="flex w-full items-center justify-between px-5 py-4 text-left transition-colors hover:bg-card-border/20"
                >
                  <div className="flex items-center gap-3">
                    {isExpanded ? (
                      <ChevronDown className="h-4 w-4 text-muted" />
                    ) : (
                      <ChevronRight className="h-4 w-4 text-muted" />
                    )}
                    <SectionIcon className="h-4 w-4 text-muted" />
                    <span className="text-sm font-semibold">{gate.title}</span>
                  </div>
                  <div className="flex items-center gap-2 text-xs">
                    <SummaryIcon className={`h-3.5 w-3.5 ${statusConfig[summary.status].color}`} />
                    <span className={statusConfig[summary.status].color}>{summary.text}</span>
                  </div>
                </button>

                {isExpanded && (
                  <div className="border-t border-card-border px-5 py-4 space-y-2">
                    {gate.items.map((item) => {
                      const cfg = statusConfig[item.status];
                      const ItemIcon = cfg.icon;
                      const isItemExpanded = expandedItems[item.id];

                      return (
                        <div
                          key={item.id}
                          className="rounded-lg border border-card-border/60 bg-background/50"
                        >
                          <button
                            onClick={() => toggleItem(item.id)}
                            className="flex w-full items-center gap-3 px-4 py-3 text-left transition-colors hover:bg-card-border/10"
                          >
                            <ItemIcon className={`h-4 w-4 shrink-0 ${cfg.color}`} />
                            <div className="min-w-0 flex-1">
                              <span className="text-sm font-medium">{item.label}</span>
                              <p className="text-xs text-muted truncate">{item.description}</p>
                            </div>
                            <span className={`shrink-0 rounded px-2 py-0.5 text-xs font-medium ${cfg.color} ${cfg.bg}`}>
                              {cfg.label}
                            </span>
                          </button>

                          {isItemExpanded && item.details && (
                            <div className="border-t border-card-border/40 px-4 py-3">
                              <p className="font-mono text-xs text-muted leading-relaxed">
                                {item.details}
                              </p>
                            </div>
                          )}
                        </div>
                      );
                    })}
                  </div>
                )}
              </div>
            );
          })}
        </div>

        {/* Explanation */}
        <div className="mt-12 rounded-xl border border-card-border bg-card p-6">
          <h2 className="text-lg font-semibold">How merge checklist works</h2>
          <p className="mt-3 text-sm leading-relaxed text-muted">
            Before any cycle output can be merged, OrchyStraw runs four quality
            gates: test suite, file ownership boundaries, code review verdicts,
            and security scan. Every gate must pass or explicitly be marked as
            conditional. Blocking items (red) prevent merge until resolved.
            Warnings (yellow) allow merge with acknowledgment. The PM agent
            coordinates this checklist automatically at the end of each cycle.
          </p>
        </div>

        <div className="mt-8 text-center">
          <a
            href="/checkpoints"
            className="inline-flex items-center gap-2 rounded-lg bg-accent px-6 py-3 text-sm font-semibold text-accent-foreground transition-colors hover:bg-accent/90"
          >
            <FileCheck className="h-4 w-4" />
            View Checkpoints
          </a>
        </div>
      </div>
    </main>
  );
}
