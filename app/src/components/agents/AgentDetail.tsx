import { useQuery } from "@tanstack/react-query";
import { ArrowLeft, FolderOpen, Clock, Gauge } from "lucide-react";
import { useAppStore } from "@/stores/app";
import { listAgents, getLatestLogs } from "@/services/tauri";

const LEVEL_COLORS: Record<string, string> = {
  info: "#3b82f6",
  warn: "#eab308",
  error: "#ef4444",
  debug: "#6b7280",
};

export function AgentDetail() {
  const { selectedAgentId, setActiveView, setSelectedAgent, currentProjectPath } = useAppStore();

  const { data: agents = [] } = useQuery({
    queryKey: ["agents", currentProjectPath],
    queryFn: () => listAgents(currentProjectPath),
  });

  const { data: logs = [] } = useQuery({
    queryKey: ["latestLogs", currentProjectPath, 50],
    queryFn: () => getLatestLogs(50, currentProjectPath),
  });

  // If no agent selected, show agent list
  if (!selectedAgentId) {
    return (
      <div className="space-y-4">
        <h2 className="text-sm font-medium text-text-muted">All Agents</h2>
        <div className="bg-bg-secondary border border-border rounded-lg divide-y divide-border">
          {agents.map((agent) => (
            <button
              key={agent.id}
              onClick={() => setSelectedAgent(agent.id)}
              className="w-full flex items-center gap-4 px-4 py-3 hover:bg-bg-tertiary transition-colors text-left"
            >
              <span className="text-xs font-mono text-text-dim w-24 shrink-0">{agent.id}</span>
              <span className="text-sm font-medium text-text flex-1">{agent.label}</span>
              <span className="text-xs text-text-dim">{agent.ownership}</span>
              <span className="text-xs text-text-muted">
                {agent.interval === 0 ? "runs last" : `every ${agent.interval}`}
              </span>
            </button>
          ))}
        </div>
      </div>
    );
  }

  const agent = agents.find((a) => a.id === selectedAgentId);
  if (!agent) {
    return (
      <div className="text-sm text-text-dim">
        Agent not found.{" "}
        <button onClick={() => setActiveView("dashboard")} className="text-accent underline">
          Go back
        </button>
      </div>
    );
  }

  const agentLogs = logs.filter((l) => l.agent_id === agent.id);
  const ownershipList = agent.ownership.split(/\s+/).filter(Boolean);

  return (
    <div className="space-y-6">
      {/* Back nav */}
      <button
        onClick={() => setSelectedAgent(null)}
        className="flex items-center gap-2 text-xs text-text-muted hover:text-text transition-colors"
      >
        <ArrowLeft size={14} />
        Back to all agents
      </button>

      {/* Agent header */}
      <div className="bg-bg-secondary border border-border rounded-lg p-6">
        <div className="flex items-start justify-between mb-4">
          <div>
            <h1 className="text-lg font-semibold text-text">{agent.label}</h1>
            <span className="text-xs font-mono text-text-dim">{agent.id}</span>
          </div>
          <span className="w-3 h-3 rounded-full bg-status-green" title="Active" />
        </div>

        <div className="grid grid-cols-3 gap-4 mt-4">
          <div className="flex items-center gap-2">
            <Gauge size={14} className="text-text-dim" />
            <div>
              <div className="text-[10px] uppercase tracking-wider text-text-dim">Interval</div>
              <div className="text-sm text-text">
                {agent.interval === 0 ? "Runs last each cycle" : `Every ${agent.interval} cycles`}
              </div>
            </div>
          </div>
          <div className="flex items-center gap-2">
            <FolderOpen size={14} className="text-text-dim" />
            <div>
              <div className="text-[10px] uppercase tracking-wider text-text-dim">Prompt</div>
              <div className="text-sm font-mono text-text">{agent.prompt_path}</div>
            </div>
          </div>
          <div className="flex items-center gap-2">
            <Clock size={14} className="text-text-dim" />
            <div>
              <div className="text-[10px] uppercase tracking-wider text-text-dim">Last Activity</div>
              <div className="text-sm text-text">
                {agentLogs.length > 0
                  ? new Date(agentLogs[0].timestamp).toLocaleString()
                  : "No recent activity"}
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Ownership */}
      <div>
        <h3 className="text-sm font-medium text-text-muted mb-2">File Ownership</h3>
        <div className="flex flex-wrap gap-2">
          {ownershipList.map((path) => (
            <span
              key={path}
              className="text-xs font-mono bg-bg-secondary border border-border rounded px-2.5 py-1 text-text-muted"
            >
              {path}
            </span>
          ))}
        </div>
      </div>

      {/* Activity log */}
      <div>
        <h3 className="text-sm font-medium text-text-muted mb-2">Activity Log</h3>
        <div className="bg-bg-secondary border border-border rounded-lg divide-y divide-border">
          {agentLogs.length > 0 ? (
            agentLogs.map((log, i) => (
              <div key={i} className="px-4 py-3 flex items-start gap-3">
                <span
                  className="text-[10px] font-semibold uppercase tracking-wider mt-0.5 w-10 shrink-0"
                  style={{ color: LEVEL_COLORS[log.level] ?? "#6b7280" }}
                >
                  {log.level}
                </span>
                <span className="text-xs text-text-dim shrink-0 w-16">
                  C{log.cycle}
                </span>
                <p className="text-sm text-text-muted flex-1">{log.message}</p>
                <span className="text-[10px] text-text-dim shrink-0">
                  {new Date(log.timestamp).toLocaleTimeString()}
                </span>
              </div>
            ))
          ) : (
            <div className="px-4 py-8 text-center text-sm text-text-dim">
              No activity recorded for this agent
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
