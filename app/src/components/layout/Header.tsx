import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { Play, Square, Loader2 } from "lucide-react";
import { useAppStore } from "@/stores/app";
import { getCycleStatus, startCycle, stopCycle } from "@/services/tauri";
import { useState } from "react";

export function Header() {
  const { currentProject, currentProjectPath } = useAppStore();
  const queryClient = useQueryClient();
  const [cycleCount, setCycleCount] = useState(5);

  const { data: status } = useQuery({
    queryKey: ["cycleStatus"],
    queryFn: getCycleStatus,
    refetchInterval: 2_000,
  });

  const startMutation = useMutation({
    mutationFn: () => startCycle(currentProjectPath, cycleCount),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["cycleStatus"] }),
  });

  const stopMutation = useMutation({
    mutationFn: () => stopCycle(currentProject),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["cycleStatus"] }),
  });

  const running = status?.running ?? false;
  const runCount = status?.agents_run ?? 0;

  return (
    <header className="h-14 border-b border-border bg-bg-secondary flex items-center justify-between px-6 shrink-0">
      <div className="flex items-center gap-4">
        <h1 className="text-sm font-medium">{currentProject}</h1>
        <div className="flex items-center gap-2 text-xs">
          <span
            className="w-2 h-2 rounded-full"
            style={{ backgroundColor: running ? "#22c55e" : "#6b7280" }}
          />
          <span className="text-text-muted">
            {running
              ? `${runCount} project${runCount !== 1 ? "s" : ""} running`
              : "Idle"}
          </span>
        </div>
      </div>

      <div className="flex items-center gap-3">
        <input
          type="number"
          min={1}
          max={100}
          value={cycleCount}
          onChange={(e) => setCycleCount(Math.max(1, parseInt(e.target.value) || 5))}
          className="w-14 bg-bg-tertiary text-text text-xs text-center px-2 py-1.5 rounded border border-border focus:outline-none focus:border-accent"
          title="Number of cycles"
        />
        <button
          onClick={() => startMutation.mutate()}
          disabled={startMutation.isPending}
          className="flex items-center gap-2 px-3 py-1.5 text-xs font-medium bg-status-green/10 text-status-green border border-status-green/20 rounded-md hover:bg-status-green/20 transition-colors disabled:opacity-50"
        >
          {startMutation.isPending ? <Loader2 size={14} className="animate-spin" /> : <Play size={14} />}
          Start
        </button>
        {running && (
          <button
            onClick={() => stopMutation.mutate()}
            disabled={stopMutation.isPending}
            className="flex items-center gap-2 px-3 py-1.5 text-xs font-medium bg-status-red/10 text-status-red border border-status-red/20 rounded-md hover:bg-status-red/20 transition-colors disabled:opacity-50"
          >
            {stopMutation.isPending ? <Loader2 size={14} className="animate-spin" /> : <Square size={14} />}
            Stop
          </button>
        )}
      </div>
    </header>
  );
}
