import { useState } from "react";
import { X, FolderOpen, Loader2, Check, ChevronLeft, ChevronRight, AlertCircle } from "lucide-react";
import { useAppStore } from "@/stores/app";
import { initProject } from "@/services/tauri";
import type { DetectedProject, ProjectTemplate } from "@/types";

const TEMPLATES: { id: ProjectTemplate; label: string; description: string }[] = [
  { id: "saas", label: "SaaS", description: "Web app with frontend + backend + marketing site" },
  { id: "api", label: "API", description: "Backend service, library, or CLI tool" },
  { id: "content", label: "Content", description: "Blog, docs, or content-heavy site" },
  { id: "yc-startup", label: "YC Startup", description: "Full startup: product + site + docs + ops" },
];

type Step = 1 | 2 | 3 | 4;

export function ProjectWizard() {
  const wizardOpen = useAppStore((s) => s.wizardOpen);
  const setWizardOpen = useAppStore((s) => s.setWizardOpen);

  const [step, setStep] = useState<Step>(1);
  const [path, setPath] = useState("");
  const [template, setTemplate] = useState<ProjectTemplate>("saas");
  const [detecting, setDetecting] = useState(false);
  const [initializing, setInitializing] = useState(false);
  const [detection, setDetection] = useState<DetectedProject | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [completed, setCompleted] = useState(false);

  if (!wizardOpen) return null;

  const reset = (): void => {
    setStep(1);
    setPath("");
    setTemplate("saas");
    setDetection(null);
    setError(null);
    setCompleted(false);
  };

  const handleClose = (): void => {
    reset();
    setWizardOpen(false);
  };

  const handleDetect = async (): Promise<void> => {
    if (!path.trim()) {
      setError("Please enter a folder path");
      return;
    }
    setError(null);
    setDetecting(true);
    try {
      const result = await initProject(path.trim(), undefined, true);
      setDetection(result);
      if (result.suggested_template) {
        setTemplate(result.suggested_template as ProjectTemplate);
      }
      setStep(2);
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setDetecting(false);
    }
  };

  const handlePreview = async (): Promise<void> => {
    setError(null);
    setDetecting(true);
    try {
      const result = await initProject(path.trim(), template, true);
      setDetection(result);
      setStep(3);
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setDetecting(false);
    }
  };

  const handleConfirm = async (): Promise<void> => {
    setError(null);
    setInitializing(true);
    try {
      const result = await initProject(path.trim(), template, false);
      setDetection(result);
      setCompleted(true);
      setStep(4);
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setInitializing(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/70 backdrop-blur-sm">
      <div className="bg-bg-secondary border border-border rounded-xl w-full max-w-2xl max-h-[90vh] overflow-hidden flex flex-col">
        {/* Header */}
        <div className="flex items-center justify-between px-5 py-4 border-b border-border">
          <div>
            <h2 className="text-base font-semibold text-text">Add Project</h2>
            <p className="text-xs text-text-dim mt-0.5">Step {step} of 4</p>
          </div>
          <button
            onClick={handleClose}
            className="text-text-dim hover:text-text transition-colors"
          >
            <X size={18} />
          </button>
        </div>

        {/* Step progress */}
        <div className="flex gap-1 px-5 pt-4">
          {[1, 2, 3, 4].map((n) => (
            <div
              key={n}
              className={`h-1 flex-1 rounded-full transition-colors ${
                n <= step ? "bg-accent" : "bg-border"
              }`}
            />
          ))}
        </div>

        {/* Body */}
        <div className="flex-1 overflow-y-auto px-5 py-5">
          {error && (
            <div className="mb-4 flex items-start gap-2 bg-status-red/10 border border-status-red/40 rounded-md px-3 py-2 text-sm text-status-red">
              <AlertCircle size={14} className="mt-0.5 shrink-0" />
              <span>{error}</span>
            </div>
          )}

          {step === 1 && (
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-text mb-2">Project folder</label>
                <p className="text-xs text-text-dim mb-3">
                  Absolute path to the project directory. Supports ~ for your home.
                </p>
                <div className="relative">
                  <FolderOpen
                    size={14}
                    className="absolute left-3 top-1/2 -translate-y-1/2 text-text-dim"
                  />
                  <input
                    type="text"
                    value={path}
                    onChange={(e) => setPath(e.target.value)}
                    placeholder="~/Projects/my-awesome-project"
                    className="w-full bg-bg-tertiary border border-border rounded-md pl-9 pr-3 py-2.5 text-sm text-text placeholder:text-text-dim focus:outline-none focus:border-accent font-mono"
                  />
                </div>
              </div>
            </div>
          )}

          {step === 2 && detection && (
            <div className="space-y-5">
              <div>
                <h3 className="text-sm font-medium text-text mb-2">Detected codebase</h3>
                <div className="bg-bg-tertiary border border-border rounded-md p-3 text-sm">
                  <div className="flex justify-between mb-1">
                    <span className="text-text-dim">Type</span>
                    <span className="text-text font-mono">{detection.detected_type}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-text-dim">Markers</span>
                    <span className="text-text font-mono">
                      {detection.markers_found.length > 0
                        ? detection.markers_found.join(", ")
                        : "none"}
                    </span>
                  </div>
                </div>
              </div>

              <div>
                <h3 className="text-sm font-medium text-text mb-2">Choose a template</h3>
                <div className="grid grid-cols-2 gap-2">
                  {TEMPLATES.map((t) => (
                    <button
                      key={t.id}
                      onClick={() => setTemplate(t.id)}
                      className={`text-left rounded-md border p-3 transition-colors ${
                        template === t.id
                          ? "border-accent bg-accent/10"
                          : "border-border bg-bg-tertiary hover:border-text-dim"
                      }`}
                    >
                      <div className="flex items-center justify-between mb-1">
                        <span className="text-sm font-medium text-text">{t.label}</span>
                        {template === t.id && <Check size={14} className="text-accent" />}
                      </div>
                      <p className="text-[11px] text-text-dim leading-snug">{t.description}</p>
                    </button>
                  ))}
                </div>
                {detection.suggested_template && (
                  <p className="text-[11px] text-text-dim mt-2">
                    Suggested based on detection: <span className="font-mono">{detection.suggested_template}</span>
                  </p>
                )}
              </div>
            </div>
          )}

          {step === 3 && detection && (
            <div className="space-y-4">
              <div>
                <h3 className="text-sm font-medium text-text mb-2">Agents preview</h3>
                <p className="text-xs text-text-dim mb-3">
                  This agents.conf will be created at{" "}
                  <span className="font-mono text-text-muted">{detection.path}/agents.conf</span>
                </p>
                <pre className="bg-bg-tertiary border border-border rounded-md p-3 text-[11px] font-mono text-text-muted whitespace-pre-wrap overflow-x-auto max-h-[280px] overflow-y-auto">
                  {detection.agents_conf_preview || "(no template found)"}
                </pre>
              </div>
            </div>
          )}

          {step === 4 && (
            <div className="space-y-4 text-center py-6">
              {completed ? (
                <>
                  <div className="w-12 h-12 rounded-full bg-status-green/20 border border-status-green/40 flex items-center justify-center mx-auto">
                    <Check size={24} className="text-status-green" />
                  </div>
                  <div>
                    <h3 className="text-base font-semibold text-text mb-1">Project registered</h3>
                    <p className="text-sm text-text-dim">
                      {detection?.path} is now wired into orchystraw.
                    </p>
                  </div>
                  <div className="bg-bg-tertiary border border-border rounded-md p-3 text-left text-xs text-text-muted space-y-1">
                    <div>agents.conf created</div>
                    <div>.orchystraw/ state directory created</div>
                    <div>Registered in ~/.orchystraw/registry.jsonl</div>
                  </div>
                  <p className="text-xs text-text-dim">
                    Next: run <span className="font-mono text-accent">orchystraw run {detection?.path} --dry-run</span>
                  </p>
                </>
              ) : (
                <div className="flex flex-col items-center gap-3 py-4">
                  <Loader2 size={28} className="animate-spin text-accent" />
                  <p className="text-sm text-text-muted">Initializing…</p>
                </div>
              )}
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="flex items-center justify-between px-5 py-4 border-t border-border">
          <button
            onClick={() => {
              if (step > 1 && step < 4) {
                setStep((s) => (s - 1) as Step);
                setError(null);
              } else {
                handleClose();
              }
            }}
            disabled={initializing}
            className="flex items-center gap-1.5 text-sm text-text-dim hover:text-text transition-colors disabled:opacity-50"
          >
            {step > 1 && step < 4 ? (
              <>
                <ChevronLeft size={14} />
                Back
              </>
            ) : (
              "Cancel"
            )}
          </button>

          {step === 1 && (
            <button
              onClick={() => void handleDetect()}
              disabled={detecting || !path.trim()}
              className="flex items-center gap-1.5 px-4 py-2 bg-accent text-white text-sm rounded-md hover:bg-accent-hover transition-colors disabled:opacity-50"
            >
              {detecting ? <Loader2 size={14} className="animate-spin" /> : null}
              Detect
              <ChevronRight size={14} />
            </button>
          )}

          {step === 2 && (
            <button
              onClick={() => void handlePreview()}
              disabled={detecting}
              className="flex items-center gap-1.5 px-4 py-2 bg-accent text-white text-sm rounded-md hover:bg-accent-hover transition-colors disabled:opacity-50"
            >
              {detecting ? <Loader2 size={14} className="animate-spin" /> : null}
              Preview agents
              <ChevronRight size={14} />
            </button>
          )}

          {step === 3 && (
            <button
              onClick={() => void handleConfirm()}
              disabled={initializing}
              className="flex items-center gap-1.5 px-4 py-2 bg-accent text-white text-sm rounded-md hover:bg-accent-hover transition-colors disabled:opacity-50"
            >
              {initializing ? <Loader2 size={14} className="animate-spin" /> : null}
              Confirm & init
              <Check size={14} />
            </button>
          )}

          {step === 4 && completed && (
            <button
              onClick={handleClose}
              className="px-4 py-2 bg-accent text-white text-sm rounded-md hover:bg-accent-hover transition-colors"
            >
              Done
            </button>
          )}
        </div>
      </div>
    </div>
  );
}
