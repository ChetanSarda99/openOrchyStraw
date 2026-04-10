import { useQuery } from "@tanstack/react-query";
import { useEffect, useRef, useState } from "react";
import { useAppStore } from "@/stores/app";
import { getPixelEvents } from "@/services/tauri";
import type { PixelAgent } from "@/types";

// ── Tool → color + label ──
const TOOL_META: Record<string, { color: string; label: string }> = {
  write_file: { color: "#22c55e", label: "writing" },
  Write: { color: "#22c55e", label: "writing" },
  Edit: { color: "#22c55e", label: "editing" },
  read_file: { color: "#3b82f6", label: "reading" },
  Read: { color: "#3b82f6", label: "reading" },
  bash: { color: "#eab308", label: "running" },
  Bash: { color: "#eab308", label: "running" },
  grep: { color: "#a855f7", label: "searching" },
  Grep: { color: "#a855f7", label: "searching" },
  list_files: { color: "#06b6d4", label: "listing" },
  Glob: { color: "#06b6d4", label: "listing" },
  WebFetch: { color: "#ec4899", label: "fetching" },
  Task: { color: "#f97316", label: "delegating" },
  idle: { color: "#6b7280", label: "idle" },
};

function toolMeta(tool: string): { color: string; label: string } {
  return TOOL_META[tool] ?? { color: "#6b7280", label: tool || "idle" };
}

interface PixelAgentRowProps {
  agent: PixelAgent;
  position: number;
}

function PixelAgentRow({ agent, position }: PixelAgentRowProps) {
  const working = agent.state === "working" && agent.alive;
  // When not working, show idle meta (gray) regardless of last_tool value
  const meta = working ? toolMeta(agent.last_tool) : toolMeta("idle");

  return (
    <div
      className="flex items-center gap-3 py-1.5 transition-all duration-500"
      style={{ transform: `translateX(${working ? position : 0}px)` }}
    >
      {/* Animated dot */}
      <div className="relative flex items-center justify-center h-5 w-5 shrink-0">
        {working && (
          <span
            className="absolute inline-flex h-5 w-5 rounded-full"
            style={{
              backgroundColor: meta.color,
              opacity: 0.4,
              animation: "pixel-pulse 1.2s ease-out infinite",
            }}
          />
        )}
        <span
          className="relative inline-flex h-2.5 w-2.5 rounded-full transition-colors"
          style={{ backgroundColor: meta.color }}
        />
      </div>

      {/* Agent ID */}
      <span className="text-xs font-mono text-text-muted shrink-0 w-32 truncate">
        {agent.agent_id}
      </span>

      {/* Action label */}
      <span
        className="text-[10px] uppercase tracking-wider font-semibold w-20 shrink-0"
        style={{ color: working ? meta.color : "#6b7280" }}
      >
        {meta.label}
      </span>

      {/* Activity bar */}
      <div className="flex-1 h-1 rounded-full bg-bg-tertiary overflow-hidden">
        {working && (
          <div
            className="h-full rounded-full transition-all"
            style={{
              backgroundColor: meta.color,
              width: "100%",
              animation: "pixel-progress 2s ease-in-out infinite",
            }}
          />
        )}
      </div>

      {/* Last message preview */}
      <span
        className="text-[10px] text-text-dim font-mono truncate max-w-[280px] shrink-0"
        title={agent.last_message ?? ""}
      >
        {agent.last_message ? agent.last_message.slice(0, 60) : ""}
      </span>
    </div>
  );
}

export function PixelAgents() {
  const currentProjectPath = useAppStore((s) => s.currentProjectPath);
  const [tick, setTick] = useState(0);
  const tickRef = useRef<number>(0);

  const { data } = useQuery({
    queryKey: ["pixelEvents", currentProjectPath],
    queryFn: () => getPixelEvents(currentProjectPath),
    refetchInterval: 1_000,
  });

  // Drive animation tick (8fps wave for movement)
  useEffect(() => {
    const id = setInterval(() => {
      tickRef.current = (tickRef.current + 1) % 60;
      setTick(tickRef.current);
    }, 125);
    return () => clearInterval(id);
  }, []);

  const agents = data?.agents ?? [];
  const aliveCount = agents.filter((a) => a.state === "working" && a.alive).length;
  const idleCount = agents.length - aliveCount;

  return (
    <div>
      <style>{`
        @keyframes pixel-pulse {
          0% { transform: scale(0.85); opacity: 0.5; }
          100% { transform: scale(2.5); opacity: 0; }
        }
        @keyframes pixel-progress {
          0% { transform: translateX(-100%); }
          100% { transform: translateX(100%); }
        }
      `}</style>

      <div className="flex items-center justify-between mb-3">
        <h2 className="text-sm font-medium text-text-muted">Live Activity</h2>
        <div className="flex items-center gap-3 text-[10px] text-text-dim font-mono">
          <span>
            <span className="text-status-green">●</span> {aliveCount} working
          </span>
          <span>
            <span className="text-text-dim">●</span> {idleCount} idle
          </span>
        </div>
      </div>

      <div className="bg-bg-secondary border border-border rounded-lg px-4 py-3">
        {agents.length === 0 ? (
          <div className="text-center text-xs text-text-dim py-4">
            No pixel events yet. Start a cycle to see agents come alive.
          </div>
        ) : (
          <div className="space-y-0.5">
            {agents.map((agent, i) => {
              // Subtle wave motion for working agents
              const phase = (tick + i * 3) % 30;
              const offset = phase < 15 ? phase : 30 - phase;
              return (
                <PixelAgentRow
                  key={agent.agent_id}
                  agent={agent}
                  position={offset / 4}
                />
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}
