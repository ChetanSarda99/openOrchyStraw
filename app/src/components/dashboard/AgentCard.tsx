import type { Agent } from "@/types";
import { useAppStore } from "@/stores/app";

interface AgentCardProps {
  agent: Agent;
  status?: "running" | "idle" | "error" | "inactive";
  lastRun?: string;
}

const STATUS_COLORS: Record<string, string> = {
  running: "#22c55e",
  idle: "#eab308",
  error: "#ef4444",
  inactive: "#6b7280",
};

export function AgentCard({ agent, status = "inactive", lastRun }: AgentCardProps) {
  const setSelectedAgent = useAppStore((s) => s.setSelectedAgent);

  return (
    <button
      onClick={() => setSelectedAgent(agent.id)}
      className="w-full text-left bg-bg-secondary border border-border rounded-lg p-4 hover:border-border hover:bg-bg-tertiary transition-colors"
    >
      <div className="flex items-start justify-between mb-2">
        <div className="flex items-center gap-2">
          <span
            className="w-2 h-2 rounded-full shrink-0"
            style={{ backgroundColor: STATUS_COLORS[status] }}
          />
          <span className="text-sm font-medium text-text truncate">{agent.label}</span>
        </div>
        <span className="text-[10px] font-mono text-text-dim">{agent.id}</span>
      </div>
      <div className="space-y-1 mt-3">
        <div className="flex justify-between text-xs">
          <span className="text-text-dim">Interval</span>
          <span className="text-text-muted">{agent.interval === 0 ? "last" : `every ${agent.interval}`}</span>
        </div>
        <div className="flex justify-between text-xs">
          <span className="text-text-dim">Owns</span>
          <span className="text-text-muted truncate ml-2 max-w-[140px]" title={agent.ownership}>
            {agent.ownership}
          </span>
        </div>
        {lastRun && (
          <div className="flex justify-between text-xs">
            <span className="text-text-dim">Last run</span>
            <span className="text-text-muted">{new Date(lastRun).toLocaleTimeString()}</span>
          </div>
        )}
      </div>
    </button>
  );
}
