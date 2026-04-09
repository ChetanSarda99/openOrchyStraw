import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { FolderOpen, Moon, Sun, Cpu, RefreshCw } from "lucide-react";
import { useAppStore } from "@/stores/app";
import { scanProjects } from "@/services/tauri";

export function Settings() {
  const { currentProjectPath, setCurrentProject } = useAppStore();
  const [scanDir, setScanDir] = useState("~/Projects");
  const [darkMode, setDarkMode] = useState(true);
  const [defaultModel, setDefaultModel] = useState("claude-sonnet-4-20250514");
  const [projectPath, setProjectPath] = useState(currentProjectPath);

  const scanMutation = useQuery({
    queryKey: ["scanProjects", scanDir],
    queryFn: () => scanProjects(scanDir),
    enabled: false,
  });

  const handleUpdateProject = () => {
    const name = projectPath.split("/").pop() ?? projectPath;
    setCurrentProject(name, projectPath);
  };

  return (
    <div className="max-w-2xl space-y-8">
      <div>
        <h2 className="text-sm font-medium text-text mb-1">Settings</h2>
        <p className="text-xs text-text-dim">Configure OrchyStraw desktop preferences.</p>
      </div>

      {/* Project path */}
      <section className="space-y-3">
        <h3 className="text-xs font-semibold uppercase tracking-wider text-text-dim">Project</h3>
        <div className="bg-bg-secondary border border-border rounded-lg p-4 space-y-3">
          <div className="flex items-center gap-2">
            <FolderOpen size={14} className="text-text-dim shrink-0" />
            <label className="text-sm text-text-muted w-28 shrink-0">Project path</label>
            <input
              value={projectPath}
              onChange={(e) => setProjectPath(e.target.value)}
              className="flex-1 bg-bg-tertiary border border-border rounded px-3 py-1.5 text-sm font-mono text-text focus:outline-none focus:border-accent"
            />
            <button
              onClick={handleUpdateProject}
              className="px-3 py-1.5 text-xs font-medium border border-border rounded hover:bg-bg-tertiary transition-colors text-text-muted"
            >
              Set
            </button>
          </div>

          <div className="flex items-center gap-2">
            <RefreshCw size={14} className="text-text-dim shrink-0" />
            <label className="text-sm text-text-muted w-28 shrink-0">Scan directory</label>
            <input
              value={scanDir}
              onChange={(e) => setScanDir(e.target.value)}
              className="flex-1 bg-bg-tertiary border border-border rounded px-3 py-1.5 text-sm font-mono text-text focus:outline-none focus:border-accent"
            />
            <button
              onClick={() => scanMutation.refetch()}
              className="px-3 py-1.5 text-xs font-medium border border-border rounded hover:bg-bg-tertiary transition-colors text-text-muted"
            >
              Scan
            </button>
          </div>
        </div>
      </section>

      {/* Appearance */}
      <section className="space-y-3">
        <h3 className="text-xs font-semibold uppercase tracking-wider text-text-dim">Appearance</h3>
        <div className="bg-bg-secondary border border-border rounded-lg p-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              {darkMode ? <Moon size={14} className="text-text-dim" /> : <Sun size={14} className="text-text-dim" />}
              <span className="text-sm text-text-muted">Dark mode</span>
            </div>
            <button
              onClick={() => setDarkMode(!darkMode)}
              className={`w-10 h-5 rounded-full transition-colors relative ${
                darkMode ? "bg-accent" : "bg-border"
              }`}
            >
              <span
                className={`absolute top-0.5 w-4 h-4 bg-white rounded-full transition-transform ${
                  darkMode ? "left-5" : "left-0.5"
                }`}
              />
            </button>
          </div>
        </div>
      </section>

      {/* Model defaults */}
      <section className="space-y-3">
        <h3 className="text-xs font-semibold uppercase tracking-wider text-text-dim">AI Model</h3>
        <div className="bg-bg-secondary border border-border rounded-lg p-4">
          <div className="flex items-center gap-2">
            <Cpu size={14} className="text-text-dim shrink-0" />
            <label className="text-sm text-text-muted w-28 shrink-0">Default model</label>
            <select
              value={defaultModel}
              onChange={(e) => setDefaultModel(e.target.value)}
              className="flex-1 bg-bg-tertiary border border-border rounded px-3 py-1.5 text-sm text-text focus:outline-none focus:border-accent cursor-pointer"
            >
              <option value="claude-sonnet-4-20250514">Claude Sonnet 4</option>
              <option value="claude-opus-4-20250514">Claude Opus 4</option>
              <option value="claude-haiku-3-20250307">Claude Haiku 3.5</option>
            </select>
          </div>
        </div>
      </section>

      {/* Version info */}
      <section className="pt-4 border-t border-border">
        <div className="flex items-center justify-between text-xs text-text-dim">
          <span>OrchyStraw Desktop v0.5.0</span>
          <span>31 modules / 45+ tests / 8 projects wired</span>
        </div>
      </section>
    </div>
  );
}
