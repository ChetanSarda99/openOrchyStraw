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

  // Strip numeric prefix and match exact role tokens
  // 03-pm → "pm", 09-pm-issues → "pm-issues", 02-content-strategist → "content-strategist"
  const role = id.replace(/^\d+[a-z]?-/, "");

  // Exact role matches (no substring confusion — pm-issues won't match pm)
  if (role === "cofounder" || role === "co-founder" || role === "founder") return "#f97316";
  if (role === "ceo") return "#8b5cf6";
  if (role === "cto") return "#06b6d4";
  if (role === "pm" || role === "pm-coordinator") return "#ec4899";
  if (role === "backend") return "#22c55e";
  if (role === "web" || role === "web-dev" || role === "frontend") return "#3b82f6";
  if (role === "qa-code" || role === "qa-visual" || role === "qa") return "#eab308";
  if (role === "security") return "#ef4444";
  if (role === "designer") return "#a855f7";
  if (role === "hr") return "#14b8a6";
  if (role === "pixel" || role === "pixel-agents") return "#f43f5e";

  // Domain-specific workers (AIVA, etc.) — distinct gray-ish colors
  if (role.includes("issue")) return "#94a3b8"; // pm-issues
  if (role.includes("content")) return "#0ea5e9";
  if (role.includes("linkedin")) return "#0a66c2";
  if (role.includes("instagram")) return "#e1306c";
  if (role.includes("reddit") || role.includes("youtube")) return "#ff4500";
  if (role.includes("twitter") || role.includes("tiktok") || role.includes("x-")) return "#1da1f2";
  if (role.includes("engagement")) return "#10b981";
  if (role.includes("analytics") || role.includes("growth")) return "#f59e0b";
  if (role.includes("research")) return "#8b5cf6";

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
  const r = isCoordinator ? 22 : 18;
  // Full role name (no prefix), no truncation — rendered BELOW the circle
  const label = agent.id.replace(/^\d+[a-z]?-/, "");

  return (
    <g
      onMouseEnter={() => onHover(agent.id)}
      onMouseLeave={() => onHover(null)}
      style={{ cursor: "pointer" }}
    >
      {/* Glow ring when working */}
      {working && (
        <circle cx={x} cy={y} r={r + 8} fill="none" stroke={color} strokeWidth="2" opacity="0.4">
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

      {/* Label BELOW the circle (no truncation) */}
      <text
        x={x}
        y={y + r + 14}
        textAnchor="middle"
        fill={working ? color : "#a1a1aa"}
        fontSize={isCoordinator ? 11 : 10}
        fontWeight={working ? "600" : "500"}
        fontFamily="ui-monospace, monospace"
        pointerEvents="none"
      >
        {label}
      </text>

      {/* Hover tooltip */}
      {hovered && (
        <g>
          <rect x={x - 90} y={y - r - 36} width="180" height="28" rx="4" fill="#0a0a0a" stroke="#262626" strokeWidth="1" />
          <text x={x} y={y - r - 22} textAnchor="middle" fill="#fafafa" fontSize="10" fontFamily="ui-monospace, monospace">
            {agent.id}
          </text>
          <text x={x} y={y - r - 11} textAnchor="middle" fill="#a1a1aa" fontSize="9">
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

  if (agents.length === 0) return null;

  // ── Categorize agents into chain of command layers ──
  const isLeader = (id: string): "cofounder" | "ceo" | "cto" | null => {
    const role = id.replace(/^\d+[a-z]?-/, "");
    if (role === "cofounder" || role === "co-founder" || role === "founder") return "cofounder";
    if (role === "ceo") return "ceo";
    if (role === "cto") return "cto";
    return null;
  };

  const cofounder = agents.find((a) => isLeader(a.id) === "cofounder");
  const ceo = agents.find((a) => isLeader(a.id) === "ceo");
  const cto = agents.find((a) => isLeader(a.id) === "cto");
  const pm = agents.find((a) => a.interval === 0);
  const workers = agents.filter(
    (a) => !isLeader(a.id) && a.interval !== 0
  );

  // ── Layout dimensions ──
  const width = 1000;
  const workerRows = Math.ceil(workers.length / 6);
  const height = 220 + workerRows * 90;
  const cx = width / 2;

  // Layer Y positions
  const yCofounder = 50;
  const yLeaders = 50;
  const yPM = 145;
  const yWorkersStart = 235;

  // Leader positions (cofounder center, ceo left, cto right)
  const leaderSpacing = 200;
  const cofounderPos = { x: cx, y: yCofounder };
  const ceoPos = ceo ? { x: cx - leaderSpacing, y: yLeaders } : null;
  const ctoPos = cto ? { x: cx + leaderSpacing, y: yLeaders } : null;

  // PM in the middle layer
  const pmPos = pm ? { x: cx, y: yPM } : null;

  // Workers in a grid below PM
  const workerCols = Math.min(workers.length, 6);
  const workerSpacing = workerCols > 1 ? Math.min(160, (width - 100) / workerCols) : 160;
  const workerStartX = cx - ((workerCols - 1) * workerSpacing) / 2;
  const workerPositions = workers.map((agent, i) => {
    const col = i % workerCols;
    const row = Math.floor(i / workerCols);
    return {
      agent,
      x: workerStartX + col * workerSpacing,
      y: yWorkersStart + row * 90,
    };
  });

  // ── Lines between layers ──
  // Cofounder ↔ CEO
  // Cofounder ↔ CTO
  // Cofounder/CEO/CTO → PM (all three connect)
  // PM → each worker

  const renderLine = (x1: number, y1: number, x2: number, y2: number, key: string, active: boolean, color: string) => (
    <line
      key={key}
      x1={x1} y1={y1} x2={x2} y2={y2}
      stroke={active ? color : "#3a3a3a"}
      strokeWidth={active ? 2 : 1.5}
      strokeDasharray={active ? "none" : "4 4"}
      opacity={active ? 0.85 : 0.55}
    />
  );

  const isWorking = (id: string | undefined): boolean => {
    if (!id) return false;
    const p = pixelMap.get(id);
    return !!(p?.state === "working" && p?.alive);
  };

  return (
    <div>
      <h2 className="text-sm font-medium text-text-muted mb-3">Agent Flow — Chain of Command</h2>
      <div className="bg-bg-secondary border border-border rounded-lg p-4 overflow-hidden">
        <svg
          viewBox={`0 0 ${width} ${height}`}
          preserveAspectRatio="xMidYMid meet"
          className="w-full h-auto block mx-auto"
          style={{ maxWidth: "1100px" }}
        >
          {/* Layer labels (left side) */}
          <g fill="#52525b" fontSize="9" fontFamily="ui-monospace, monospace">
            <text x={20} y={yCofounder + 4}>LEADERSHIP</text>
            <text x={20} y={yPM + 4}>COORDINATOR</text>
            <text x={20} y={yWorkersStart + 4}>WORKERS</text>
          </g>

          {/* CoFounder ↔ CEO/CTO peer lines */}
          {ceoPos && renderLine(cofounderPos.x - 22, cofounderPos.y, ceoPos.x + 22, ceoPos.y, "cf-ceo",
            isWorking(cofounder?.id) || isWorking(ceo?.id), agentColor(ceo?.id || ""))}
          {ctoPos && renderLine(cofounderPos.x + 22, cofounderPos.y, ctoPos.x - 22, ctoPos.y, "cf-cto",
            isWorking(cofounder?.id) || isWorking(cto?.id), agentColor(cto?.id || ""))}

          {/* Leadership trio → PM lines */}
          {pmPos && cofounder && renderLine(cofounderPos.x, cofounderPos.y + 22, pmPos.x, pmPos.y - 22, "cf-pm",
            isWorking(pm?.id), "#ec4899")}
          {pmPos && ceoPos && renderLine(ceoPos.x, ceoPos.y + 22, pmPos.x - 8, pmPos.y - 22, "ceo-pm",
            isWorking(pm?.id), "#ec4899")}
          {pmPos && ctoPos && renderLine(ctoPos.x, ctoPos.y + 22, pmPos.x + 8, pmPos.y - 22, "cto-pm",
            isWorking(pm?.id), "#ec4899")}

          {/* PM → each worker */}
          {pmPos && workerPositions.map(({ agent, x, y }) =>
            renderLine(pmPos.x, pmPos.y + 22, x, y - 18, `pm-${agent.id}`,
              isWorking(agent.id), agentColor(agent.id))
          )}

          {/* Render nodes (top to bottom) */}
          {cofounder && (
            <AgentNode
              agent={cofounder}
              x={cofounderPos.x}
              y={cofounderPos.y}
              isCoordinator={false}
              pixelState={pixelMap.get(cofounder.id)}
              hovered={hovered === cofounder.id}
              onHover={setHovered}
            />
          )}
          {ceo && ceoPos && (
            <AgentNode
              agent={ceo}
              x={ceoPos.x}
              y={ceoPos.y}
              isCoordinator={false}
              pixelState={pixelMap.get(ceo.id)}
              hovered={hovered === ceo.id}
              onHover={setHovered}
            />
          )}
          {cto && ctoPos && (
            <AgentNode
              agent={cto}
              x={ctoPos.x}
              y={ctoPos.y}
              isCoordinator={false}
              pixelState={pixelMap.get(cto.id)}
              hovered={hovered === cto.id}
              onHover={setHovered}
            />
          )}
          {pm && pmPos && (
            <AgentNode
              agent={pm}
              x={pmPos.x}
              y={pmPos.y}
              isCoordinator={true}
              pixelState={pixelMap.get(pm.id)}
              hovered={hovered === pm.id}
              onHover={setHovered}
            />
          )}
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
        </svg>
      </div>
    </div>
  );
}
