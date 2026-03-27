"use client";

import {
  ArrowLeft,
  ArrowRight,
  GitPullRequest,
  GitBranch,
  FileCode,
  Check,
  ChevronDown,
  ChevronRight,
  Shield,
  TestTube,
  Users,
  Bot,
  Copy,
  ExternalLink,
} from "lucide-react";
import { useState, useCallback } from "react";

type WizardStep = "branch" | "changes" | "details" | "review";

interface BranchOption {
  name: string;
  agents: string[];
  filesChanged: number;
  additions: number;
  deletions: number;
  cycle: number;
}

const branches: BranchOption[] = [
  {
    name: "auto/cycle-7-backend",
    agents: ["06-Backend", "09-QA"],
    filesChanged: 4,
    additions: 187,
    deletions: 23,
    cycle: 7,
  },
  {
    name: "auto/cycle-7-web",
    agents: ["11-Web"],
    filesChanged: 3,
    additions: 142,
    deletions: 8,
    cycle: 7,
  },
  {
    name: "auto/cycle-6-pixel",
    agents: ["08-Pixel", "05-Tauri-UI"],
    filesChanged: 6,
    additions: 310,
    deletions: 45,
    cycle: 6,
  },
];

interface FileChange {
  path: string;
  status: "added" | "modified" | "deleted";
  additions: number;
  deletions: number;
}

const mockFiles: FileChange[] = [
  { path: "src/core/token-budget.sh", status: "modified", additions: 52, deletions: 8 },
  { path: "src/core/smart-cycle.sh", status: "added", additions: 87, deletions: 0 },
  { path: "tests/core/test-token-budget.sh", status: "added", additions: 34, deletions: 0 },
  { path: "tests/core/test-smart-cycle.sh", status: "added", additions: 14, deletions: 0 },
];

interface GateResult {
  name: string;
  icon: typeof Shield;
  status: "pass" | "fail" | "warn";
  detail: string;
}

const gateResults: GateResult[] = [
  { name: "Tests", icon: TestTube, status: "pass", detail: "32/32 unit + 42/42 integration pass" },
  { name: "File Ownership", icon: Users, status: "pass", detail: "All changes within agent boundaries" },
  { name: "Code Review", icon: Bot, status: "pass", detail: "CTO review: APPROVED" },
  { name: "Security Scan", icon: Shield, status: "warn", detail: "No new vulnerabilities. 1 advisory note." },
];

const gateStatusStyles = {
  pass: { color: "text-status-success", bg: "bg-status-success/10", label: "Pass" },
  fail: { color: "text-status-error", bg: "bg-status-error/10", label: "Fail" },
  warn: { color: "text-status-warning", bg: "bg-status-warning/10", label: "Warning" },
};

const fileStatusStyles = {
  added: { color: "text-status-success", label: "A" },
  modified: { color: "text-status-warning", label: "M" },
  deleted: { color: "text-status-error", label: "D" },
};

const steps: { id: WizardStep; label: string }[] = [
  { id: "branch", label: "Select Branch" },
  { id: "changes", label: "Review Changes" },
  { id: "details", label: "PR Details" },
  { id: "review", label: "Create PR" },
];

export default function CreatePRPage() {
  const [currentStep, setCurrentStep] = useState<WizardStep>("branch");
  const [selectedBranch, setSelectedBranch] = useState<string | null>(null);
  const [expandedFiles, setExpandedFiles] = useState<Record<string, boolean>>({});
  const [prTitle, setPrTitle] = useState("");
  const [prBody, setPrBody] = useState("");
  const [created, setCreated] = useState(false);

  const currentStepIndex = steps.findIndex((s) => s.id === currentStep);
  const branch = branches.find((b) => b.name === selectedBranch);

  const goNext = useCallback(() => {
    const idx = steps.findIndex((s) => s.id === currentStep);
    if (idx < steps.length - 1) setCurrentStep(steps[idx + 1].id);
  }, [currentStep]);

  const goBack = useCallback(() => {
    const idx = steps.findIndex((s) => s.id === currentStep);
    if (idx > 0) setCurrentStep(steps[idx - 1].id);
  }, [currentStep]);

  const toggleFile = useCallback((path: string) => {
    setExpandedFiles((prev) => ({ ...prev, [path]: !prev[path] }));
  }, []);

  const handleSelectBranch = useCallback(
    (name: string) => {
      setSelectedBranch(name);
      const b = branches.find((br) => br.name === name);
      if (b) {
        setPrTitle(`feat: cycle ${b.cycle} — ${b.agents.join(", ")}`);
        setPrBody(
          `## Summary\n- ${b.agents.join(", ")} completed cycle ${b.cycle}\n- ${b.filesChanged} files changed (+${b.additions} -${b.deletions})\n\n## Quality Gates\nAll gates passed. See merge checklist for details.\n\n## Test Plan\n- [ ] Unit tests pass\n- [ ] Integration tests pass\n- [ ] Manual smoke test`
        );
      }
    },
    []
  );

  const handleCreate = useCallback(() => {
    setCreated(true);
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
          Create Pull Request
        </h1>
        <p className="mt-3 text-muted">
          One-click PR creation — select a workspace branch, review changes,
          and ship.
        </p>

        {/* Step indicator */}
        <div className="mt-10 flex items-center gap-2">
          {steps.map((step, idx) => (
            <div key={step.id} className="flex items-center gap-2">
              <div
                className={`flex h-7 w-7 items-center justify-center rounded-full text-xs font-bold ${
                  idx < currentStepIndex
                    ? "bg-accent text-accent-foreground"
                    : idx === currentStepIndex
                      ? "border-2 border-accent text-accent"
                      : "border border-card-border text-muted"
                }`}
              >
                {idx < currentStepIndex ? (
                  <Check className="h-3.5 w-3.5" />
                ) : (
                  idx + 1
                )}
              </div>
              <span
                className={`hidden text-xs font-medium sm:inline ${
                  idx === currentStepIndex ? "text-foreground" : "text-muted"
                }`}
              >
                {step.label}
              </span>
              {idx < steps.length - 1 && (
                <ArrowRight className="h-3 w-3 text-card-border" />
              )}
            </div>
          ))}
        </div>

        {/* Step 1: Select Branch */}
        {currentStep === "branch" && (
          <div className="mt-8 space-y-3">
            <h2 className="mb-4 text-lg font-semibold">Select workspace branch</h2>
            {branches.map((b) => (
              <button
                key={b.name}
                onClick={() => handleSelectBranch(b.name)}
                className={`flex w-full items-center gap-4 rounded-xl border px-5 py-4 text-left transition-colors ${
                  selectedBranch === b.name
                    ? "border-accent bg-accent/5"
                    : "border-card-border bg-card hover:bg-card-border/20"
                }`}
              >
                <GitBranch
                  className={`h-5 w-5 shrink-0 ${
                    selectedBranch === b.name ? "text-accent" : "text-muted"
                  }`}
                />
                <div className="min-w-0 flex-1">
                  <span className="font-mono text-sm font-medium">{b.name}</span>
                  <div className="mt-1 flex flex-wrap items-center gap-3 text-xs text-muted">
                    <span>{b.filesChanged} files</span>
                    <span className="text-status-success">+{b.additions}</span>
                    <span className="text-status-error">-{b.deletions}</span>
                    <span>Cycle {b.cycle}</span>
                  </div>
                  <div className="mt-1.5 flex flex-wrap gap-1.5">
                    {b.agents.map((agent) => (
                      <span
                        key={agent}
                        className="inline-flex items-center gap-1 rounded-md bg-card-border/30 px-2 py-0.5 text-xs"
                      >
                        <Bot className="h-3 w-3 text-orange-400" />
                        {agent}
                      </span>
                    ))}
                  </div>
                </div>
                {selectedBranch === b.name && (
                  <Check className="h-5 w-5 shrink-0 text-accent" />
                )}
              </button>
            ))}

            <div className="flex justify-end pt-4">
              <button
                onClick={goNext}
                disabled={!selectedBranch}
                className="inline-flex items-center gap-2 rounded-lg bg-accent px-6 py-3 text-sm font-semibold text-accent-foreground transition-colors hover:bg-accent/90 disabled:opacity-40 disabled:cursor-not-allowed"
              >
                Review Changes
                <ArrowRight className="h-4 w-4" />
              </button>
            </div>
          </div>
        )}

        {/* Step 2: Review Changes */}
        {currentStep === "changes" && (
          <div className="mt-8">
            <h2 className="mb-2 text-lg font-semibold">Changed files</h2>
            {branch && (
              <p className="mb-6 text-xs text-muted">
                <span className="font-mono">{branch.name}</span> —{" "}
                {branch.filesChanged} files,{" "}
                <span className="text-status-success">+{branch.additions}</span>{" "}
                <span className="text-status-error">-{branch.deletions}</span>
              </p>
            )}

            <div className="space-y-2">
              {mockFiles.map((file) => {
                const fStyle = fileStatusStyles[file.status];
                const isExpanded = expandedFiles[file.path];

                return (
                  <div
                    key={file.path}
                    className="rounded-xl border border-card-border bg-card"
                  >
                    <button
                      onClick={() => toggleFile(file.path)}
                      className="flex w-full items-center justify-between px-5 py-3 text-left transition-colors hover:bg-card-border/20"
                    >
                      <div className="flex items-center gap-3 min-w-0">
                        {isExpanded ? (
                          <ChevronDown className="h-4 w-4 shrink-0 text-muted" />
                        ) : (
                          <ChevronRight className="h-4 w-4 shrink-0 text-muted" />
                        )}
                        <span className={`shrink-0 font-mono text-xs font-bold ${fStyle.color}`}>
                          {fStyle.label}
                        </span>
                        <FileCode className="h-3.5 w-3.5 shrink-0 text-muted" />
                        <span className="truncate font-mono text-sm">
                          {file.path}
                        </span>
                      </div>
                      <div className="flex items-center gap-3 text-xs">
                        <span className="text-status-success">+{file.additions}</span>
                        <span className="text-status-error">
                          {file.deletions > 0 ? `-${file.deletions}` : "0"}
                        </span>
                      </div>
                    </button>

                    {isExpanded && (
                      <div className="border-t border-card-border bg-background/50 px-5 py-4">
                        <pre className="overflow-x-auto font-mono text-xs leading-relaxed">
                          <code>
                            {file.status === "modified" ? (
                              <>
                                <span className="text-muted">@@ -12,8 +12,14 @@</span>
                                {"\n"}
                                <span className="text-muted"> # Existing function</span>
                                {"\n"}
                                <span className="text-red-400">- old_implementation()</span>
                                {"\n"}
                                <span className="text-green-400">+ new_implementation() {"{"}</span>
                                {"\n"}
                                <span className="text-green-400">+   validate_input "$1"</span>
                                {"\n"}
                                <span className="text-green-400">+   process_tokens</span>
                                {"\n"}
                                <span className="text-green-400">+ {"}"}</span>
                              </>
                            ) : file.status === "added" ? (
                              <>
                                <span className="text-green-400">+ #!/usr/bin/env bash</span>
                                {"\n"}
                                <span className="text-green-400">+ # {file.path.split("/").pop()}</span>
                                {"\n"}
                                <span className="text-green-400">+ # Auto-generated by agent</span>
                                {"\n"}
                                <span className="text-muted">  ...</span>
                                {"\n"}
                                <span className="text-green-400">+ {file.additions} lines added</span>
                              </>
                            ) : (
                              <span className="text-red-400">File deleted</span>
                            )}
                          </code>
                        </pre>
                      </div>
                    )}
                  </div>
                );
              })}
            </div>

            {/* Quality gates */}
            <h2 className="mb-4 mt-10 text-lg font-semibold">Quality Gates</h2>
            <div className="grid gap-3 sm:grid-cols-2">
              {gateResults.map((gate) => {
                const GateIcon = gate.icon;
                const style = gateStatusStyles[gate.status];
                return (
                  <div
                    key={gate.name}
                    className="flex items-center gap-3 rounded-xl border border-card-border bg-card px-4 py-3"
                  >
                    <GateIcon className={`h-4 w-4 shrink-0 ${style.color}`} />
                    <div className="min-w-0 flex-1">
                      <span className="text-sm font-medium">{gate.name}</span>
                      <p className="truncate text-xs text-muted">{gate.detail}</p>
                    </div>
                    <span
                      className={`shrink-0 rounded px-2 py-0.5 text-xs font-medium ${style.color} ${style.bg}`}
                    >
                      {style.label}
                    </span>
                  </div>
                );
              })}
            </div>

            <div className="flex justify-between pt-6">
              <button
                onClick={goBack}
                className="inline-flex items-center gap-2 rounded-lg border border-card-border px-5 py-3 text-sm font-medium text-muted transition-colors hover:text-foreground"
              >
                <ArrowLeft className="h-4 w-4" />
                Back
              </button>
              <button
                onClick={goNext}
                className="inline-flex items-center gap-2 rounded-lg bg-accent px-6 py-3 text-sm font-semibold text-accent-foreground transition-colors hover:bg-accent/90"
              >
                Add Details
                <ArrowRight className="h-4 w-4" />
              </button>
            </div>
          </div>
        )}

        {/* Step 3: PR Details */}
        {currentStep === "details" && (
          <div className="mt-8">
            <h2 className="mb-6 text-lg font-semibold">Pull request details</h2>

            <div className="space-y-5">
              <div>
                <label
                  htmlFor="pr-title"
                  className="mb-1.5 block text-sm font-medium"
                >
                  Title
                </label>
                <input
                  id="pr-title"
                  type="text"
                  value={prTitle}
                  onChange={(e) => setPrTitle(e.target.value)}
                  className="w-full rounded-lg border border-card-border bg-card px-4 py-3 font-mono text-sm text-foreground placeholder:text-muted/50 focus:border-accent focus:outline-none focus:ring-1 focus:ring-accent"
                  placeholder="feat: cycle 7 — backend improvements"
                />
              </div>

              <div>
                <label
                  htmlFor="pr-body"
                  className="mb-1.5 block text-sm font-medium"
                >
                  Description
                </label>
                <textarea
                  id="pr-body"
                  value={prBody}
                  onChange={(e) => setPrBody(e.target.value)}
                  rows={10}
                  className="w-full rounded-lg border border-card-border bg-card px-4 py-3 font-mono text-sm text-foreground placeholder:text-muted/50 focus:border-accent focus:outline-none focus:ring-1 focus:ring-accent"
                  placeholder="## Summary&#10;..."
                />
                <p className="mt-1.5 text-xs text-muted">
                  Auto-generated from cycle data. Edit as needed.
                </p>
              </div>

              <div className="rounded-xl border border-card-border bg-card p-4">
                <span className="text-xs font-medium text-muted">Preview</span>
                <div className="mt-3 space-y-2">
                  <div className="flex items-center gap-2">
                    <GitPullRequest className="h-4 w-4 text-status-success" />
                    <span className="text-sm font-semibold">{prTitle || "Untitled PR"}</span>
                  </div>
                  <div className="flex items-center gap-3 text-xs text-muted">
                    <span className="font-mono">{selectedBranch}</span>
                    <ArrowRight className="h-3 w-3" />
                    <span className="font-mono">main</span>
                  </div>
                </div>
              </div>
            </div>

            <div className="flex justify-between pt-6">
              <button
                onClick={goBack}
                className="inline-flex items-center gap-2 rounded-lg border border-card-border px-5 py-3 text-sm font-medium text-muted transition-colors hover:text-foreground"
              >
                <ArrowLeft className="h-4 w-4" />
                Back
              </button>
              <button
                onClick={goNext}
                disabled={!prTitle}
                className="inline-flex items-center gap-2 rounded-lg bg-accent px-6 py-3 text-sm font-semibold text-accent-foreground transition-colors hover:bg-accent/90 disabled:opacity-40 disabled:cursor-not-allowed"
              >
                Review & Create
                <ArrowRight className="h-4 w-4" />
              </button>
            </div>
          </div>
        )}

        {/* Step 4: Review & Create */}
        {currentStep === "review" && !created && (
          <div className="mt-8">
            <h2 className="mb-6 text-lg font-semibold">Confirm & create</h2>

            <div className="space-y-4">
              {/* Summary card */}
              <div className="rounded-xl border border-card-border bg-card p-5">
                <div className="flex items-center gap-3">
                  <GitPullRequest className="h-5 w-5 text-status-success" />
                  <span className="text-sm font-semibold">{prTitle}</span>
                </div>
                <div className="mt-3 flex items-center gap-3 text-xs text-muted">
                  <GitBranch className="h-3.5 w-3.5" />
                  <span className="font-mono">{selectedBranch}</span>
                  <ArrowRight className="h-3 w-3" />
                  <span className="font-mono">main</span>
                </div>
              </div>

              {/* Stats row */}
              {branch && (
                <div className="grid grid-cols-3 gap-3">
                  <div className="rounded-xl border border-card-border bg-card px-4 py-3 text-center">
                    <span className="text-2xl font-bold">{branch.filesChanged}</span>
                    <p className="text-xs text-muted">Files</p>
                  </div>
                  <div className="rounded-xl border border-card-border bg-card px-4 py-3 text-center">
                    <span className="text-2xl font-bold text-status-success">+{branch.additions}</span>
                    <p className="text-xs text-muted">Additions</p>
                  </div>
                  <div className="rounded-xl border border-card-border bg-card px-4 py-3 text-center">
                    <span className="text-2xl font-bold text-status-error">-{branch.deletions}</span>
                    <p className="text-xs text-muted">Deletions</p>
                  </div>
                </div>
              )}

              {/* Gates summary */}
              <div className="flex items-center gap-4 rounded-xl border border-card-border bg-card px-5 py-3">
                <span className="text-sm font-medium">Quality Gates</span>
                <div className="flex items-center gap-2">
                  {gateResults.map((g) => {
                    const style = gateStatusStyles[g.status];
                    return (
                      <span
                        key={g.name}
                        className={`rounded px-2 py-0.5 text-xs font-medium ${style.color} ${style.bg}`}
                      >
                        {g.name}
                      </span>
                    );
                  })}
                </div>
              </div>

              {/* Description preview */}
              <div className="rounded-xl border border-card-border bg-card p-5">
                <span className="text-xs font-medium text-muted">Description</span>
                <pre className="mt-2 whitespace-pre-wrap font-mono text-xs leading-relaxed text-foreground/80">
                  {prBody}
                </pre>
              </div>
            </div>

            <div className="flex justify-between pt-6">
              <button
                onClick={goBack}
                className="inline-flex items-center gap-2 rounded-lg border border-card-border px-5 py-3 text-sm font-medium text-muted transition-colors hover:text-foreground"
              >
                <ArrowLeft className="h-4 w-4" />
                Back
              </button>
              <button
                onClick={handleCreate}
                className="inline-flex items-center gap-2 rounded-lg bg-accent px-6 py-3 text-sm font-semibold text-accent-foreground transition-colors hover:bg-accent/90"
              >
                <GitPullRequest className="h-4 w-4" />
                Create Pull Request
              </button>
            </div>
          </div>
        )}

        {/* Success state */}
        {created && (
          <div className="mt-8">
            <div className="rounded-xl border border-status-success/30 bg-status-success/5 p-8 text-center">
              <div className="mx-auto mb-4 flex h-12 w-12 items-center justify-center rounded-full bg-status-success/10">
                <Check className="h-6 w-6 text-status-success" />
              </div>
              <h2 className="text-xl font-bold">Pull Request Created</h2>
              <p className="mt-2 text-sm text-muted">
                <span className="font-mono">{selectedBranch}</span> → main
              </p>

              <div className="mt-6 rounded-lg border border-card-border bg-card p-4 text-left">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-2">
                    <GitPullRequest className="h-4 w-4 text-status-success" />
                    <span className="text-sm font-semibold">{prTitle}</span>
                  </div>
                  <span className="rounded-full bg-status-success/10 px-2.5 py-0.5 text-xs font-medium text-status-success">
                    Open
                  </span>
                </div>
                <div className="mt-2 flex items-center gap-4 text-xs text-muted">
                  <span>#{Math.floor(Math.random() * 50 + 80)}</span>
                  <span>opened just now</span>
                  {branch && (
                    <span>
                      <span className="text-status-success">+{branch.additions}</span>{" "}
                      <span className="text-status-error">-{branch.deletions}</span>
                    </span>
                  )}
                </div>
              </div>

              <div className="mt-6 flex justify-center gap-3">
                <button
                  onClick={() => {
                    void navigator.clipboard.writeText(
                      `https://github.com/ChetanSarda99/OrchyStraw-Pro/pull/new`
                    );
                  }}
                  className="inline-flex items-center gap-2 rounded-lg border border-card-border px-4 py-2.5 text-sm text-muted transition-colors hover:text-foreground"
                >
                  <Copy className="h-3.5 w-3.5" />
                  Copy Link
                </button>
                <a
                  href="https://github.com/ChetanSarda99/OrchyStraw-Pro/pulls"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="inline-flex items-center gap-2 rounded-lg bg-accent px-5 py-2.5 text-sm font-semibold text-accent-foreground transition-colors hover:bg-accent/90"
                >
                  <ExternalLink className="h-3.5 w-3.5" />
                  View on GitHub
                </a>
              </div>
            </div>

            <div className="mt-8 flex justify-center gap-4">
              <a
                href="/todos"
                className="inline-flex items-center gap-2 rounded-lg border border-card-border px-5 py-3 text-sm font-medium text-muted transition-colors hover:text-foreground"
              >
                Merge Checklist
              </a>
              <a
                href="/checkpoints"
                className="inline-flex items-center gap-2 rounded-lg border border-card-border px-5 py-3 text-sm font-medium text-muted transition-colors hover:text-foreground"
              >
                View Checkpoints
              </a>
            </div>
          </div>
        )}
      </div>
    </main>
  );
}
