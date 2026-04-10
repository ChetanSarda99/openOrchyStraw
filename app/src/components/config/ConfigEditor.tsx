import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useState, useEffect } from "react";
import { Save, Plus, Trash2, AlertCircle, Check } from "lucide-react";
import { useAppStore } from "@/stores/app";
import { readAgentsConf, writeAgentsConf } from "@/services/tauri";
import type { Agent, AgentsConfig } from "@/types";

export function ConfigEditor() {
  const currentProjectPath = useAppStore((s) => s.currentProjectPath);
  const confPath = currentProjectPath;
  const queryClient = useQueryClient();

  const { data: config } = useQuery({
    queryKey: ["agentsConf", confPath],
    queryFn: () => readAgentsConf(confPath),
  });

  const [agents, setAgents] = useState<Agent[]>([]);
  const [dirty, setDirty] = useState(false);
  const [saved, setSaved] = useState(false);

  useEffect(() => {
    if (config?.agents) {
      setAgents(config.agents);
      setDirty(false);
    }
  }, [config]);

  const saveMutation = useMutation({
    mutationFn: (updatedConfig: AgentsConfig) => writeAgentsConf(confPath, updatedConfig),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["agentsConf", confPath] });
      queryClient.invalidateQueries({ queryKey: ["agents"] });
      setDirty(false);
      setSaved(true);
      setTimeout(() => setSaved(false), 2000);
    },
  });

  const updateAgent = (index: number, field: keyof Agent, value: string | number) => {
    setAgents((prev) => {
      const next = [...prev];
      next[index] = { ...next[index], [field]: value };
      return next;
    });
    setDirty(true);
  };

  const removeAgent = (index: number) => {
    setAgents((prev) => prev.filter((_, i) => i !== index));
    setDirty(true);
  };

  const addAgent = () => {
    setAgents((prev) => [
      ...prev,
      {
        id: "",
        label: "",
        prompt_path: "",
        ownership: "",
        interval: 1,
      },
    ]);
    setDirty(true);
  };

  const handleSave = () => {
    saveMutation.mutate({ agents, raw: config?.raw ?? "" });
  };

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-sm font-medium text-text">agents.conf</h2>
          <p className="text-xs text-text-dim mt-0.5">{confPath}</p>
        </div>
        <div className="flex items-center gap-2">
          {dirty && (
            <span className="flex items-center gap-1 text-xs text-status-yellow">
              <AlertCircle size={12} />
              Unsaved changes
            </span>
          )}
          {saved && (
            <span className="flex items-center gap-1 text-xs text-status-green">
              <Check size={12} />
              Saved
            </span>
          )}
          <button
            onClick={addAgent}
            className="flex items-center gap-1 px-3 py-1.5 text-xs font-medium text-text-muted border border-border rounded-md hover:bg-bg-tertiary transition-colors"
          >
            <Plus size={14} />
            Add Agent
          </button>
          <button
            onClick={handleSave}
            disabled={!dirty || saveMutation.isPending}
            className="flex items-center gap-1 px-3 py-1.5 text-xs font-medium bg-accent text-white rounded-md hover:bg-accent-hover transition-colors disabled:opacity-40 disabled:cursor-not-allowed"
          >
            <Save size={14} />
            Save
          </button>
        </div>
      </div>

      {/* Config table */}
      <div className="bg-bg-secondary border border-border rounded-lg overflow-hidden">
        {/* Header */}
        <div
          className="grid gap-2 px-4 py-2 border-b border-border text-[10px] uppercase tracking-wider text-text-dim font-semibold"
          style={{ gridTemplateColumns: "100px 120px 160px minmax(0, 1fr) 70px 40px" }}
        >
          <span>ID</span>
          <span>Label</span>
          <span>Prompt Path</span>
          <span>Ownership</span>
          <span>Interval</span>
          <span />
        </div>

        {/* Rows */}
        <div className="divide-y divide-border">
          {agents.map((agent, i) => (
            <div
              key={i}
              className="grid gap-2 px-4 py-1.5 items-center"
              style={{ gridTemplateColumns: "100px 120px 160px minmax(0, 1fr) 70px 40px" }}
            >
              <input
                value={agent.id}
                onChange={(e) => updateAgent(i, "id", e.target.value)}
                className="bg-transparent text-xs font-mono text-text border-b border-transparent focus:border-accent focus:outline-none py-1"
                placeholder="00-agent"
              />
              <input
                value={agent.label}
                onChange={(e) => updateAgent(i, "label", e.target.value)}
                className="bg-transparent text-xs text-text border-b border-transparent focus:border-accent focus:outline-none py-1"
                placeholder="Agent Label"
              />
              <input
                value={agent.prompt_path}
                onChange={(e) => updateAgent(i, "prompt_path", e.target.value)}
                className="bg-transparent text-xs font-mono text-text-muted border-b border-transparent focus:border-accent focus:outline-none py-1"
                placeholder="prompts/00-agent/"
              />
              <input
                value={agent.ownership}
                onChange={(e) => updateAgent(i, "ownership", e.target.value)}
                className="bg-transparent text-xs font-mono text-text-muted border-b border-transparent focus:border-accent focus:outline-none py-1"
                placeholder="src/ docs/"
              />
              <input
                type="number"
                min={0}
                value={agent.interval}
                onChange={(e) => updateAgent(i, "interval", parseInt(e.target.value) || 0)}
                className="bg-transparent text-xs text-center text-text border-b border-transparent focus:border-accent focus:outline-none py-1"
              />
              <button
                onClick={() => removeAgent(i)}
                className="text-text-dim hover:text-status-red transition-colors p-1"
                title="Remove agent"
              >
                <Trash2 size={14} />
              </button>
            </div>
          ))}
          {agents.length === 0 && (
            <div className="px-4 py-8 text-center text-sm text-text-dim">
              No agents configured. Click "Add Agent" to start.
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
