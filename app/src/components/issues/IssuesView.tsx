import { useQuery } from "@tanstack/react-query";
import { useState, useMemo } from "react";
import { CircleDot, ExternalLink, Activity, Tag, User, Clock } from "lucide-react";
import { useAppStore } from "@/stores/app";
import { getIssues } from "@/services/tauri";
import type { GitHubIssue } from "@/types";

function timeAgo(iso: string): string {
  const diff = Date.now() - new Date(iso).getTime();
  const mins = Math.floor(diff / 60000);
  if (mins < 60) return `${mins}m ago`;
  const hours = Math.floor(mins / 60);
  if (hours < 24) return `${hours}h ago`;
  const days = Math.floor(hours / 24);
  return `${days}d ago`;
}

function labelColor(label: string): string {
  if (label.includes("priority:high") || label.includes("bug")) return "#ef4444";
  if (label.includes("priority:medium") || label.includes("enhancement")) return "#eab308";
  if (label.includes("priority:low") || label.includes("question")) return "#3b82f6";
  if (label.includes("feature")) return "#22c55e";
  return "#6b7280";
}

export function IssuesView() {
  const currentProjectPath = useAppStore((s) => s.currentProjectPath);
  const [selectedIssue, setSelectedIssue] = useState<GitHubIssue | null>(null);
  const [labelFilter, setLabelFilter] = useState<string>("all");

  const { data, isLoading } = useQuery({
    queryKey: ["issues", currentProjectPath],
    queryFn: () => getIssues(currentProjectPath),
    refetchInterval: 30_000,
  });

  const allLabels = useMemo(() => {
    const labels = new Set<string>();
    data?.issues?.forEach((i) => i.labels.forEach((l) => labels.add(l)));
    return Array.from(labels).sort();
  }, [data]);

  const filteredIssues = useMemo(() => {
    if (!data?.issues) return [];
    if (labelFilter === "all") return data.issues;
    return data.issues.filter((i) => i.labels.includes(labelFilter));
  }, [data, labelFilter]);

  return (
    <div className="flex gap-4 h-[calc(100vh-120px)]">
      {/* Issues list */}
      <div className="flex-1 flex flex-col min-w-0">
        <div className="flex items-center justify-between mb-4">
          <div>
            <h2 className="text-sm font-medium text-text">GitHub Issues</h2>
            <p className="text-xs text-text-dim mt-0.5">
              {data?.total ?? 0} open
              {data && data.working_count > 0 && (
                <span className="text-status-green ml-2">
                  · {data.working_count} being worked on
                </span>
              )}
            </p>
          </div>
          <select
            value={labelFilter}
            onChange={(e) => setLabelFilter(e.target.value)}
            className="bg-bg-secondary border border-border rounded-md px-3 py-1.5 text-xs text-text focus:outline-none focus:border-accent cursor-pointer"
          >
            <option value="all">All labels</option>
            {allLabels.map((l) => (
              <option key={l} value={l}>{l}</option>
            ))}
          </select>
        </div>

        {/* List */}
        <div className="flex-1 bg-bg-secondary border border-border rounded-lg overflow-hidden flex flex-col">
          {isLoading && (
            <div className="px-4 py-8 text-center text-sm text-text-dim">Loading issues...</div>
          )}
          {!isLoading && filteredIssues.length === 0 && (
            <div className="px-4 py-8 text-center text-sm text-text-dim">
              {data?.error ?? "No open issues"}
            </div>
          )}
          <div className="overflow-y-auto divide-y divide-border">
            {filteredIssues.map((issue) => (
              <button
                key={issue.number}
                onClick={() => setSelectedIssue(issue)}
                className={`w-full flex items-start gap-3 px-4 py-3 text-left hover:bg-bg-tertiary transition-colors ${
                  selectedIssue?.number === issue.number ? "bg-bg-tertiary" : ""
                }`}
              >
                <CircleDot size={14} className="text-status-green mt-0.5 shrink-0" />
                <div className="min-w-0 flex-1">
                  <div className="flex items-center gap-2 mb-1">
                    <span className="text-xs font-mono text-text-dim shrink-0">#{issue.number}</span>
                    <span className="text-sm text-text truncate">{issue.title}</span>
                    {issue.working_on && (
                      <span className="flex items-center gap-1 text-[10px] text-status-green bg-status-green/10 border border-status-green/20 rounded px-1.5 py-0.5 shrink-0">
                        <Activity size={10} />
                        working
                      </span>
                    )}
                  </div>
                  <div className="flex items-center gap-3 text-[10px] text-text-dim">
                    <span className="flex items-center gap-1">
                      <User size={10} />
                      {issue.author}
                    </span>
                    <span className="flex items-center gap-1">
                      <Clock size={10} />
                      {timeAgo(issue.updated_at)}
                    </span>
                    {issue.labels.slice(0, 3).map((l) => (
                      <span
                        key={l}
                        className="flex items-center gap-1 px-1.5 py-0.5 rounded text-[9px]"
                        style={{
                          color: labelColor(l),
                          borderColor: labelColor(l) + "40",
                          backgroundColor: labelColor(l) + "10",
                          border: "1px solid",
                        }}
                      >
                        <Tag size={8} />
                        {l}
                      </span>
                    ))}
                  </div>
                </div>
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* Detail panel */}
      {selectedIssue && (
        <div className="w-[420px] bg-bg-secondary border border-border rounded-lg p-4 overflow-y-auto shrink-0">
          <div className="flex items-start justify-between mb-3">
            <div>
              <span className="text-xs font-mono text-text-dim">#{selectedIssue.number}</span>
              <h3 className="text-sm font-medium text-text mt-1">{selectedIssue.title}</h3>
            </div>
            <a
              href={selectedIssue.url}
              target="_blank"
              rel="noopener noreferrer"
              className="text-text-dim hover:text-text"
              title="Open in browser"
            >
              <ExternalLink size={14} />
            </a>
          </div>
          {selectedIssue.working_on && (
            <div className="flex items-center gap-2 text-xs text-status-green bg-status-green/10 border border-status-green/20 rounded px-2 py-1 mb-3">
              <Activity size={12} />
              Currently being worked on by agents
            </div>
          )}
          <div className="text-[10px] text-text-dim space-y-1 mb-3">
            <div>Opened by <span className="text-text-muted">{selectedIssue.author}</span> · {timeAgo(selectedIssue.created_at)}</div>
            {selectedIssue.assignees.length > 0 && (
              <div>Assigned to: <span className="text-text-muted">{selectedIssue.assignees.join(", ")}</span></div>
            )}
          </div>
          {selectedIssue.labels.length > 0 && (
            <div className="flex flex-wrap gap-1 mb-4">
              {selectedIssue.labels.map((l) => (
                <span
                  key={l}
                  className="text-[9px] px-1.5 py-0.5 rounded border"
                  style={{
                    color: labelColor(l),
                    borderColor: labelColor(l) + "40",
                    backgroundColor: labelColor(l) + "10",
                  }}
                >
                  {l}
                </span>
              ))}
            </div>
          )}
          <pre className="text-xs text-text-muted whitespace-pre-wrap font-sans bg-bg-tertiary border border-border rounded p-3 max-h-96 overflow-y-auto">
            {selectedIssue.body || "(no description)"}
          </pre>
        </div>
      )}
    </div>
  );
}
