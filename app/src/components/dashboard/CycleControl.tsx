import { useQuery } from "@tanstack/react-query";
import { Activity, Hash, Clock, Users } from "lucide-react";
import { getCycleStatus } from "@/services/tauri";

export function CycleControl() {
  const { data: status } = useQuery({
    queryKey: ["cycleStatus"],
    queryFn: getCycleStatus,
    refetchInterval: 3_000,
  });

  if (!status) return null;

  const cards = [
    {
      label: "Cycle",
      value: status.cycle_number,
      icon: Hash,
      color: "#3b82f6",
    },
    {
      label: "Status",
      value: status.running ? "Running" : "Stopped",
      icon: Activity,
      color: status.running ? "#22c55e" : "#6b7280",
    },
    {
      label: "Agents Run",
      value: status.agents_run,
      icon: Users,
      color: "#a855f7",
    },
    {
      label: "Last Cycle",
      value: status.last_cycle_time
        ? new Date(status.last_cycle_time).toLocaleTimeString()
        : "Never",
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
