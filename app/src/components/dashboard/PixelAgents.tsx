import { useQuery } from "@tanstack/react-query";
import { useAppStore } from "@/stores/app";
import { getPixelEvents } from "@/services/tauri";
import type { PixelAgent } from "@/types";

// ── Tool → color + icon (emoji-free, pure CSS) ──
const TOOL_META: Record<string, { color: string; label: string }> = {
  write_file: { color: "#22c55e", label: "writing" },
  read_file: { color: "#3b82f6", label: "reading" },
  bash: { color: "#eab308", label: "running" },
  grep: { color: "#a855f7", label: "searching" },
  list_files: { color: "#06b6d4", label: "listing" },
  idle: { color: "#6b7280", label: "idle" },
};

function toolMeta(tool: string): { color: string; label: string } {
  return TOOL_META[tool] ?? { color: "#6b7280", label: tool || "idle" };
}

interface PixelAgentDotProps {
  agent: PixelAgent;
}

function PixelAgentDot({ agent }: PixelAgentDotProps) {
  const meta = toolMeta(agent.last_tool);
  const working = agent.state === "working" && agent.alive;

  return (
    <div
      className="relative flex flex-col items-center gap-1.5 bg-bg-secondary border border-border rounded-lg px-3 py-2.5 min-w-[104px] transition-colors"
      style={{ borderColor: working ? meta.color : undefined }}
      title={`${agent.agent_id} — ${meta.label}${agent.last_message ? `: ${agent.last_message}` : ""}`}
    >
      {/* Dot + pulse */}
      <div className="relative flex items-center justify-center h-6 w-6">
        {working && (
          <span
            className="absolute inline-flex h-6 w-6 rounded-full opacity-70"
            style={{
              backgroundColor: meta.color,
              animation: "pixel-pulse 1.2s ease-out infinite",
            }}
          />
        )}
        <span
          className="relative inline-flex h-3 w-3 rounded-full"
          style={{ backgroundColor: meta.color }}
        />
      </div>

      {/* Agent id (short) */}
      <span className="text-[10px] font-mono text-text-muted leading-none">
        {agent.agent_id.replace(/^\d+-/, "")}
      </span>

      {/* Current action */}
      <span
        className="text-[9px] uppercase tracking-wider font-semibold leading-none"
        style={{ color: working ? meta.color : "#6b7280" }}
      >
        {meta.label}
      </span>
    </div>
  );
}

export function PixelAgents() {
  const currentProjectPath = useAppStore((s) => s.currentProjectPath);

  const { data } = useQuery({
    queryKey: ["pixelEvents", currentProjectPath],
    queryFn: () => getPixelEvents(currentProjectPath),
    refetchInterval: 2_000,
  });

  const agents = data?.agents ?? [];
  const aliveCount = agents.filter((a) => a.alive).length;

  return (
    <div>
      {/* Inline keyframes via <style> so we don't touch globals */}
      <style>{`
        @keyframes pixel-pulse {
          0% { transform: scale(0.85); opacity: 0.75; }
          100% { transform: scale(2.0); opacity: 0; }
        }
      `}</style>

      <div className="flex items-center justify-between mb-3">
        <h2 className="text-sm font-medium text-text-muted">Live Activity</h2>
        <span className="text-[10px] text-text-dim font-mono">
          {aliveCount} / {agents.length} alive
        </span>
      </div>

      <div className="bg-bg-secondary border border-border rounded-lg p-4">
        {agents.length === 0 ? (
          <div className="text-center text-xs text-text-dim py-4">
            No pixel events yet. Start a cycle to see agents come alive.
          </div>
        ) : (
          <div className="flex flex-wrap gap-2.5">
            {agents.map((agent) => (
              <PixelAgentDot key={agent.agent_id} agent={agent} />
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
