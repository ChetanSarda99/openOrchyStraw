import { useQuery } from "@tanstack/react-query";
import { useState } from "react";
import { useAppStore } from "@/stores/app";
import { getPixelEvents, listAgents } from "@/services/tauri";
import type { Agent, PixelAgent } from "@/types";

// Locked agent color palette
const AGENT_COLORS: Record<string, string> = {
  "00-cofounder": "#f97316",
  "01-ceo": "#8b5cf6",
  "02-cto": "#06b6d4",
  "03-pm": "#ec4899",
  "06-backend": "#22c55e",
  "11-web": "#3b82f6",
  "09-qa-code": "#eab308",
  "09-qa-visual": "#eab308",
  "10-security": "#ef4444",
  "12-designer": "#a855f7",
  "13-hr": "#14b8a6",
  "08-pixel": "#f43f5e",
};

function agentColor(id: string): string {
  if (AGENT_COLORS[id]) return AGENT_COLORS[id];
  // Partial matches for projects with different IDs (AIVA, etc.)
  if (id.includes("cofounder")) return "#f97316";
  if (id.includes("ceo")) return "#8b5cf6";
  if (id.includes("cto")) return "#06b6d4";
  if (id.includes("pm")) return "#ec4899";
  if (id.includes("backend")) return "#22c55e";
  if (id.includes("web") || id.includes("frontend")) return "#3b82f6";
  if (id.includes("qa")) return "#eab308";
  if (id.includes("security")) return "#ef4444";
  if (id.includes("design")) return "#a855f7";
  if (id.includes("hr")) return "#14b8a6";
  if (id.includes("pixel")) return "#f43f5e";
  return "#6b7280";
}

interface NodeProps {
  agent: Agent;
  x: number;
  y: number;
  isCoordinator: boolean;
  pixelState?: PixelAgent;
  hovered: boolean;
  onHover: (id: string | null) => void;
}

function AgentNode({ agent, x, y, isCoordinator, pixelState, hovered, onHover }: NodeProps) {
  const color = agentColor(agent.id);
  const working = pixelState?.state === "working" && pixelState?.alive;
  const r = isCoordinator ? 28 : 20;
  const shortLabel = agent.label.split(" ")[0].slice(0, 8);

  return (
    <g
      onMouseEnter={() => onHover(agent.id)}
      onMouseLeave={() => onHover(null)}
      style={{ cursor: "pointer" }}
    >
      {/* Glow ring when working */}
      {working && (
        <circle
          cx={x}
          cy={y}
          r={r + 8}
          fill="none"
          stroke={color}
          strokeWidth="2"
          opacity="0.4"
        >
          <animate attributeName="r" from={r + 4} to={r + 14} dur="1.5s" repeatCount="indefinite" />
          <animate attributeName="opacity" from="0.6" to="0" dur="1.5s" repeatCount="indefinite" />
        </circle>
      )}

      {/* Main node */}
      <circle
        cx={x}
        cy={y}
        r={r}
        fill={working ? color : "#141414"}
        stroke={color}
        strokeWidth={hovered || working ? 3 : 2}
      />

      {/* Agent label */}
      <text
        x={x}
        y={y + 4}
        textAnchor="middle"
        fill={working ? "#0a0a0a" : color}
        fontSize={isCoordinator ? 10 : 9}
        fontWeight="600"
        fontFamily="ui-monospace, monospace"
        pointerEvents="none"
      >
        {shortLabel}
      </text>

      {/* Hover tooltip */}
      {hovered && (
        <g>
          <rect
            x={x - 80}
            y={y + r + 8}
            width="160"
            height="30"
            rx="4"
            fill="#0a0a0a"
            stroke="#262626"
            strokeWidth="1"
          />
          <text x={x} y={y + r + 22} textAnchor="middle" fill="#fafafa" fontSize="10" fontFamily="ui-monospace, monospace">
            {agent.id}
          </text>
          <text x={x} y={y + r + 33} textAnchor="middle" fill="#a1a1aa" fontSize="9">
            {working ? (pixelState?.last_tool ?? "working") : "idle"}
          </text>
        </g>
      )}
    </g>
  );
}

export function AgentFlow() {
  const currentProjectPath = useAppStore((s) => s.currentProjectPath);
  const [hovered, setHovered] = useState<string | null>(null);

  const { data: agents = [] } = useQuery({
    queryKey: ["agents", currentProjectPath],
    queryFn: () => listAgents(currentProjectPath),
  });

  const { data: pixelData } = useQuery({
    queryKey: ["pixelEvents", currentProjectPath],
    queryFn: () => getPixelEvents(currentProjectPath),
    refetchInterval: 1_000,
  });

  const pixelMap = new Map<string, PixelAgent>();
  for (const p of pixelData?.agents ?? []) {
    pixelMap.set(p.agent_id, p);
  }

  // Layout: coordinator (interval=0) at center, others around in circle
  const coordinator = agents.find((a) => a.interval === 0);
  const workers = agents.filter((a) => a.interval !== 0);

  const width = 600;
  const height = 400;
  const cx = width / 2;
  const cy = height / 2;
  const radius = 140;

  // Positions for worker agents around the circle
  const workerPositions = workers.map((agent, i) => {
    const angle = (i / workers.length) * 2 * Math.PI - Math.PI / 2;
    return {
      agent,
      x: cx + radius * Math.cos(angle),
      y: cy + radius * Math.sin(angle),
    };
  });

  if (agents.length === 0) return null;

  return (
    <div>
      <h2 className="text-sm font-medium text-text-muted mb-3">Agent Flow</h2>
      <div className="bg-bg-secondary border border-border rounded-lg p-4 flex justify-center overflow-hidden">
        <svg width={width} height={height} viewBox={`0 0 ${width} ${height}`}>
          {/* Spokes from coordinator to workers */}
          {coordinator &&
            workerPositions.map(({ agent, x, y }) => {
              const pState = pixelMap.get(agent.id);
              const working = pState?.state === "working" && pState?.alive;
              const color = agentColor(agent.id);
              return (
                <line
                  key={`line-${agent.id}`}
                  x1={cx}
                  y1={cy}
                  x2={x}
                  y2={y}
                  stroke={working ? color : "#262626"}
                  strokeWidth={working ? 2 : 1}
                  strokeDasharray={working ? "none" : "4 4"}
                  opacity={working ? 0.7 : 0.4}
                />
              );
            })}

          {/* Worker agents */}
          {workerPositions.map(({ agent, x, y }) => (
            <AgentNode
              key={agent.id}
              agent={agent}
              x={x}
              y={y}
              isCoordinator={false}
              pixelState={pixelMap.get(agent.id)}
              hovered={hovered === agent.id}
              onHover={setHovered}
            />
          ))}

          {/* Coordinator at center (drawn last so it's on top) */}
          {coordinator && (
            <AgentNode
              agent={coordinator}
              x={cx}
              y={cy}
              isCoordinator={true}
              pixelState={pixelMap.get(coordinator.id)}
              hovered={hovered === coordinator.id}
              onHover={setHovered}
            />
          )}
        </svg>
      </div>
    </div>
  );
}
