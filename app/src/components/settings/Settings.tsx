import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { FolderOpen, Moon, Sun, Cpu, RefreshCw, Key, Server } from "lucide-react";
import { useAppStore } from "@/stores/app";
import { scanProjects } from "@/services/tauri";

export function Settings() {
  const { currentProjectPath, setCurrentProject } = useAppStore();
  const [scanDir, setScanDir] = useState("~/Projects");
  const [darkMode, setDarkMode] = useState(true);
  const [defaultModel, setDefaultModel] = useState("sonnet");
  const [anthropicKey, setAnthropicKey] = useState("");
  const [openaiKey, setOpenaiKey] = useState("");
  const [geminiKey, setGeminiKey] = useState("");
  const [localUrl, setLocalUrl] = useState("http://localhost:11434");
  const [localModel, setLocalModel] = useState("llama3.3");
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
        <div className="bg-bg-secondary border border-border rounded-lg p-4 space-y-3">
          <div className="flex items-center gap-2">
            <Cpu size={14} className="text-text-dim shrink-0" />
            <label className="text-sm text-text-muted w-28 shrink-0">Default model</label>
            <select
              value={defaultModel}
              onChange={(e) => setDefaultModel(e.target.value)}
              className="flex-1 bg-bg-tertiary border border-border rounded px-3 py-1.5 text-sm text-text focus:outline-none focus:border-accent cursor-pointer"
            >
              <optgroup label="Anthropic Claude">
                <option value="opus">Claude Opus 4.6</option>
                <option value="sonnet">Claude Sonnet 4.6</option>
                <option value="haiku">Claude Haiku 4.5</option>
              </optgroup>
              <optgroup label="OpenAI">
                <option value="gpt4o">GPT-4o</option>
                <option value="o3">o3</option>
                <option value="o4-mini">o4-mini</option>
              </optgroup>
              <optgroup label="Google">
                <option value="gemini-pro">Gemini 2.5 Pro</option>
                <option value="gemini-flash">Gemini 2.5 Flash</option>
              </optgroup>
              <optgroup label="Local LLM">
                <option value="local">Local (Ollama)</option>
                <option value="local-large">Local Large (32B+)</option>
                <option value="local-small">Local Small</option>
              </optgroup>
            </select>
          </div>
        </div>
      </section>

      {/* API Keys */}
      <section className="space-y-3">
        <h3 className="text-xs font-semibold uppercase tracking-wider text-text-dim">API Keys</h3>
        <div className="bg-bg-secondary border border-border rounded-lg p-4 space-y-3">
          <div className="flex items-center gap-2">
            <Key size={14} className="text-text-dim shrink-0" />
            <label className="text-sm text-text-muted w-28 shrink-0">Anthropic</label>
            <input
              type="password"
              value={anthropicKey}
              onChange={(e) => setAnthropicKey(e.target.value)}
              placeholder="sk-ant-... (or use Claude CLI auth)"
              className="flex-1 bg-bg-tertiary border border-border rounded px-3 py-1.5 text-sm font-mono text-text focus:outline-none focus:border-accent"
            />
          </div>
          <div className="flex items-center gap-2">
            <Key size={14} className="text-text-dim shrink-0" />
            <label className="text-sm text-text-muted w-28 shrink-0">OpenAI</label>
            <input
              type="password"
              value={openaiKey}
              onChange={(e) => setOpenaiKey(e.target.value)}
              placeholder="sk-..."
              className="flex-1 bg-bg-tertiary border border-border rounded px-3 py-1.5 text-sm font-mono text-text focus:outline-none focus:border-accent"
            />
          </div>
          <div className="flex items-center gap-2">
            <Key size={14} className="text-text-dim shrink-0" />
            <label className="text-sm text-text-muted w-28 shrink-0">Gemini</label>
            <input
              type="password"
              value={geminiKey}
              onChange={(e) => setGeminiKey(e.target.value)}
              placeholder="AIza..."
              className="flex-1 bg-bg-tertiary border border-border rounded px-3 py-1.5 text-sm font-mono text-text focus:outline-none focus:border-accent"
            />
          </div>
          <p className="text-xs text-text-dim pl-6">
            Keys are stored in ~/.orchystraw/config.env. Or set env vars directly.
          </p>
        </div>
      </section>

      {/* Local LLM */}
      <section className="space-y-3">
        <h3 className="text-xs font-semibold uppercase tracking-wider text-text-dim">Local LLM</h3>
        <div className="bg-bg-secondary border border-border rounded-lg p-4 space-y-3">
          <div className="flex items-center gap-2">
            <Server size={14} className="text-text-dim shrink-0" />
            <label className="text-sm text-text-muted w-28 shrink-0">Ollama URL</label>
            <input
              value={localUrl}
              onChange={(e) => setLocalUrl(e.target.value)}
              placeholder="http://localhost:11434"
              className="flex-1 bg-bg-tertiary border border-border rounded px-3 py-1.5 text-sm font-mono text-text focus:outline-none focus:border-accent"
            />
          </div>
          <div className="flex items-center gap-2">
            <Cpu size={14} className="text-text-dim shrink-0" />
            <label className="text-sm text-text-muted w-28 shrink-0">Model name</label>
            <input
              value={localModel}
              onChange={(e) => setLocalModel(e.target.value)}
              placeholder="llama3.3, qwen3:32b, etc."
              className="flex-1 bg-bg-tertiary border border-border rounded px-3 py-1.5 text-sm font-mono text-text focus:outline-none focus:border-accent"
            />
          </div>
          <p className="text-xs text-text-dim pl-6">
            Install Ollama: curl -fsSL https://ollama.com/install.sh | sh && ollama pull llama3.3
          </p>
        </div>
      </section>

      {/* Version info */}
      <section className="pt-4 border-t border-border">
        <div className="flex items-center justify-between text-xs text-text-dim">
          <span>OrchyStraw Desktop v0.5.0</span>
          <span>35 modules / 58 tests / 8 projects wired</span>
        </div>
      </section>
    </div>
  );
}
