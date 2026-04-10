import { useQuery } from "@tanstack/react-query";
import { useAppStore } from "@/stores/app";
import { listAgents, getLatestLogs, getPixelEvents } from "@/services/tauri";
import { CycleControl } from "./CycleControl";
import { AgentCard } from "./AgentCard";
import { PixelAgents } from "./PixelAgents";
import { Clock } from "lucide-react";

type AgentStatus = "running" | "idle" | "error" | "inactive";

const LEVEL_COLORS: Record<string, string> = {
  info: "#3b82f6",
  warn: "#eab308",
  error: "#ef4444",
  debug: "#6b7280",
};

export function Dashboard() {
  const currentProjectPath = useAppStore((s) => s.currentProjectPath);

  const { data: agents = [] } = useQuery({
    queryKey: ["agents", currentProjectPath],
    queryFn: () => listAgents(currentProjectPath),
  });

  const { data: logs = [] } = useQuery({
    queryKey: ["latestLogs"],
    queryFn: () => getLatestLogs(5),
    refetchInterval: 5_000,
  });

  // Real agent activity from pixel events
  const { data: pixelData } = useQuery({
    queryKey: ["pixelEvents", currentProjectPath],
    queryFn: () => getPixelEvents(currentProjectPath),
    refetchInterval: 2_000,
  });

  const agentStatusMap = new Map<string, AgentStatus>();
  for (const a of pixelData?.agents ?? []) {
    if (a.alive && a.state === "working") agentStatusMap.set(a.agent_id, "running");
    else if (a.last_timestamp) agentStatusMap.set(a.agent_id, "idle");
  }

  return (
    <div className="space-y-6">
      {/* Cycle stats */}
      <CycleControl />

      {/* Live pixel agent activity */}
      <PixelAgents />

      {/* Agent grid */}
      <div>
        <h2 className="text-sm font-medium text-text-muted mb-3">Agents</h2>
        <div className="grid grid-cols-3 gap-3">
          {agents.map((agent) => (
            <AgentCard
              key={agent.id}
              agent={agent}
              status={agentStatusMap.get(agent.id) ?? "inactive"}
            />
          ))}
        </div>
      </div>

      {/* Recent activity */}
      <div>
        <h2 className="text-sm font-medium text-text-muted mb-3">Recent Activity</h2>
        <div className="bg-bg-secondary border border-border rounded-lg divide-y divide-border">
          {logs.map((log, i) => (
            <div key={i} className="flex items-start gap-3 px-4 py-3">
              <Clock size={14} className="text-text-dim mt-0.5 shrink-0" />
              <div className="min-w-0 flex-1">
                <div className="flex items-center gap-2 mb-0.5">
                  <span
                    className="text-[10px] font-semibold uppercase tracking-wider"
                    style={{ color: LEVEL_COLORS[log.level] ?? "#6b7280" }}
                  >
                    {log.level}
                  </span>
                  <span className="text-xs font-mono text-text-dim">{log.agent_id}</span>
                  <span className="text-[10px] text-text-dim ml-auto">
                    {new Date(log.timestamp).toLocaleTimeString()}
                  </span>
                </div>
                <p className="text-sm text-text-muted truncate">{log.message}</p>
              </div>
            </div>
          ))}
          {logs.length === 0 && (
            <div className="px-4 py-8 text-center text-sm text-text-dim">No recent activity</div>
          )}
        </div>
      </div>
    </div>
  );
}
