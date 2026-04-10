import { useQuery } from "@tanstack/react-query";
import { useState, useMemo, useEffect, useRef } from "react";
import { Search, Filter, Radio } from "lucide-react";
import { getLatestLogs, listAgents, getCycleStatus, streamOutput } from "@/services/tauri";
import { useAppStore } from "@/stores/app";

const LEVEL_COLORS: Record<string, string> = {
  info: "#3b82f6",
  warn: "#eab308",
  error: "#ef4444",
  debug: "#6b7280",
};

const LEVELS = ["all", "info", "warn", "error", "debug"] as const;

export function LogViewer() {
  const [search, setSearch] = useState("");
  const [levelFilter, setLevelFilter] = useState<string>("all");
  const [agentFilter, setAgentFilter] = useState<string>("all");
  const [streamLines, setStreamLines] = useState<string[]>([]);
  const [streaming, setStreaming] = useState(false);
  const currentProjectPath = useAppStore((s) => s.currentProjectPath);
  const streamEndRef = useRef<HTMLDivElement>(null);

  const { data: cycleStatus } = useQuery({
    queryKey: ["cycleStatus"],
    queryFn: getCycleStatus,
    refetchInterval: 3_000,
  });

  const isRunning = !!cycleStatus?.running;

  const { data: logs = [] } = useQuery({
    queryKey: ["latestLogs", 200],
    queryFn: () => getLatestLogs(200),
    refetchInterval: isRunning ? false : 5_000,
    enabled: !isRunning,
  });

  const { data: agents = [] } = useQuery({
    queryKey: ["agents", currentProjectPath],
    queryFn: () => listAgents(currentProjectPath),
  });

  // SSE subscription when cycle is running
  useEffect(() => {
    if (!isRunning) {
      setStreaming(false);
      return;
    }
    setStreaming(true);
    setStreamLines([]);

    const close = streamOutput(
      currentProjectPath,
      (chunk) => {
        setStreamLines((prev) => {
          const combined = (prev.join("\n") + chunk).split("\n");
          // Keep last 2000 lines to avoid runaway memory
          return combined.slice(-2000);
        });
      },
      () => {
        setStreaming(false);
      }
    );

    return () => {
      close();
      setStreaming(false);
    };
  }, [isRunning, currentProjectPath]);

  // Auto-scroll on new stream lines
  useEffect(() => {
    if (streaming && streamEndRef.current) {
      streamEndRef.current.scrollIntoView({ behavior: "smooth", block: "end" });
    }
  }, [streamLines, streaming]);

  const filteredLogs = useMemo(() => {
    return logs.filter((log) => {
      if (levelFilter !== "all" && log.level !== levelFilter) return false;
      if (agentFilter !== "all" && log.agent_id !== agentFilter) return false;
      if (search && !log.message.toLowerCase().includes(search.toLowerCase()) && !log.agent_id.includes(search))
        return false;
      return true;
    });
  }, [logs, levelFilter, agentFilter, search]);

  // Live stream view (when cycle is running)
  if (isRunning) {
    return (
      <div className="space-y-4">
        <div className="flex items-center gap-3">
          <div className="flex items-center gap-2">
            <Radio size={14} className="text-status-green animate-pulse" />
            <span className="text-sm font-medium text-text">Live cycle output</span>
          </div>
          <span className="text-xs text-text-dim">
            {streaming ? "streaming" : "disconnected"} — {streamLines.length} lines
          </span>
          <span className="text-xs text-text-dim ml-auto font-mono">
            {currentProjectPath}
          </span>
        </div>

        <div className="bg-bg-secondary border border-border rounded-lg overflow-hidden">
          <div className="max-h-[calc(100vh-200px)] overflow-y-auto font-mono text-[11px] leading-relaxed p-4">
            {streamLines.length === 0 ? (
              <div className="text-text-dim text-center py-8">
                Waiting for output…
              </div>
            ) : (
              streamLines.map((line, i) => (
                <div
                  key={i}
                  className="whitespace-pre-wrap text-text-muted hover:bg-bg-tertiary/30 px-1"
                >
                  {line || "\u00A0"}
                </div>
              ))
            )}
            <div ref={streamEndRef} />
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-4">
      {/* Filters */}
      <div className="flex items-center gap-3">
        <div className="relative flex-1 max-w-sm">
          <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-text-dim" />
          <input
            type="text"
            placeholder="Search logs..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="w-full bg-bg-secondary border border-border rounded-md pl-9 pr-3 py-2 text-sm text-text placeholder:text-text-dim focus:outline-none focus:border-accent"
          />
        </div>

        <div className="flex items-center gap-2">
          <Filter size={14} className="text-text-dim" />
          <select
            value={levelFilter}
            onChange={(e) => setLevelFilter(e.target.value)}
            className="bg-bg-secondary border border-border rounded-md px-3 py-2 text-sm text-text focus:outline-none focus:border-accent cursor-pointer"
          >
            {LEVELS.map((l) => (
              <option key={l} value={l}>
                {l === "all" ? "All levels" : l.toUpperCase()}
              </option>
            ))}
          </select>

          <select
            value={agentFilter}
            onChange={(e) => setAgentFilter(e.target.value)}
            className="bg-bg-secondary border border-border rounded-md px-3 py-2 text-sm text-text focus:outline-none focus:border-accent cursor-pointer"
          >
            <option value="all">All agents</option>
            {agents.map((a) => (
              <option key={a.id} value={a.id}>
                {a.label}
              </option>
            ))}
          </select>
        </div>

        <span className="text-xs text-text-dim ml-auto">
          {filteredLogs.length} / {logs.length} entries
        </span>
      </div>

      {/* Log table */}
      <div className="bg-bg-secondary border border-border rounded-lg overflow-hidden">
        {/* Header */}
        <div className="grid grid-cols-[140px_80px_60px_1fr_60px] gap-2 px-4 py-2 border-b border-border text-[10px] uppercase tracking-wider text-text-dim font-semibold">
          <span>Timestamp</span>
          <span>Agent</span>
          <span>Level</span>
          <span>Message</span>
          <span>Cycle</span>
        </div>

        {/* Rows */}
        <div className="divide-y divide-border max-h-[calc(100vh-240px)] overflow-y-auto">
          {filteredLogs.map((log, i) => (
            <div
              key={i}
              className="grid grid-cols-[140px_80px_60px_1fr_60px] gap-2 px-4 py-2.5 text-sm hover:bg-bg-tertiary/50 transition-colors"
            >
              <span className="font-mono text-xs text-text-dim">
                {new Date(log.timestamp).toLocaleTimeString()}
              </span>
              <span className="font-mono text-xs text-text-muted truncate" title={log.agent_id}>
                {log.agent_id}
              </span>
              <span
                className="text-[10px] font-semibold uppercase tracking-wider"
                style={{ color: LEVEL_COLORS[log.level] ?? "#6b7280" }}
              >
                {log.level}
              </span>
              <span className="text-sm text-text-muted truncate">{log.message}</span>
              <span className="text-xs text-text-dim text-center">{log.cycle}</span>
            </div>
          ))}
          {filteredLogs.length === 0 && (
            <div className="px-4 py-8 text-center text-sm text-text-dim">
              {logs.length === 0 ? "No logs available" : "No logs match your filters"}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
