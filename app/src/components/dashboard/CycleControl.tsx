import { useQuery } from "@tanstack/react-query";
import { Activity, Hash, Clock, Users } from "lucide-react";
import { useAppStore } from "@/stores/app";
import { getPixelEvents, API_BASE } from "@/services/tauri";

interface RunningResponse {
  running: boolean;
  count: number;
  cycles: Array<{
    project: string;
    pid: number;
    cycles: number;
    started_at: string;
  }>;
  finished?: Array<{
    project: string;
    exit_code: number;
    duration_ms: number;
    finished_at: string;
  }>;
}

export function CycleControl() {
  const currentProject = useAppStore((s) => s.currentProject);
  const currentProjectPath = useAppStore((s) => s.currentProjectPath);

  const { data: status } = useQuery<RunningResponse>({
    queryKey: ["runningCycles"],
    queryFn: async () => {
      const res = await fetch(`${API_BASE}/api/running`);
      return res.json();
    },
    refetchInterval: 2_000,
  });

  // Live agent activity for this project (drives "agents run" count)
  const { data: pixelData } = useQuery({
    queryKey: ["pixelEvents", currentProjectPath],
    queryFn: () => getPixelEvents(currentProjectPath),
    refetchInterval: 2_000,
  });

  const thisCycle = status?.cycles?.find((c) => c.project === currentProject);
  const lastFinished = status?.finished
    ?.filter((f) => f.project === currentProject)
    .sort((a, b) => new Date(b.finished_at).getTime() - new Date(a.finished_at).getTime())[0];

  const isRunning = !!thisCycle;
  const activeAgents = pixelData?.agents?.filter((a) => a.alive).length ?? 0;
  const totalAgents = pixelData?.agents?.length ?? 0;

  // Cycle number and last cycle time
  const cycleNum = thisCycle?.cycles ?? 0;
  const lastCycleAt = lastFinished?.finished_at || thisCycle?.started_at || null;

  const cards = [
    {
      label: "Cycle",
      value: cycleNum > 0 ? cycleNum : "—",
      icon: Hash,
      color: "#3b82f6",
    },
    {
      label: "Status",
      value: isRunning ? "Running" : lastFinished ? (lastFinished.exit_code === 0 ? "OK" : "Failed") : "Idle",
      icon: Activity,
      color: isRunning ? "#22c55e" : lastFinished?.exit_code === 0 ? "#22c55e" : lastFinished ? "#ef4444" : "#6b7280",
    },
    {
      label: "Agents Active",
      value: totalAgents > 0 ? `${activeAgents} / ${totalAgents}` : "—",
      icon: Users,
      color: "#a855f7",
    },
    {
      label: "Last Cycle",
      value: lastCycleAt ? new Date(lastCycleAt).toLocaleTimeString() : "Never",
      icon: Clock,
      color: "#eab308",
    },
  ];

  return (
    <div className="grid grid-cols-4 gap-4">
      {cards.map((card) => (
        <div
          key={card.label}
          className="bg-bg-secondary border border-border rounded-lg p-4"
        >
          <div className="flex items-center gap-2 mb-2">
            <card.icon size={14} style={{ color: card.color }} />
            <span className="text-xs text-text-dim">{card.label}</span>
          </div>
          <div className="text-xl font-semibold text-text">{card.value}</div>
        </div>
      ))}
    </div>
  );
}
