import type {
  Agent,
  AgentsConfig,
  ChatResponse,
  CycleStatus,
  DetectedProject,
  LogEntry,
  PixelEventsResponse,
  ProjectInfo,
} from "@/types";

// ── API Configuration ──
// The app server runs locally. Configure via env or defaults.
export const API_BASE = import.meta.env.VITE_API_URL || window.location.origin;

async function api<T>(path: string): Promise<T> {
  const res = await fetch(`${API_BASE}${path}`);
  if (!res.ok) throw new Error(`API ${path}: ${res.status}`);
  return res.json();
}

async function apiPost<T>(path: string, body: unknown): Promise<T> {
  const res = await fetch(`${API_BASE}${path}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  if (!res.ok) {
    let msg = `API ${path}: ${res.status}`;
    try {
      const err = (await res.json()) as { error?: string };
      if (err?.error) msg = err.error;
    } catch {}
    throw new Error(msg);
  }
  return res.json();
}

// ── Tauri detection (optional — used when running as native desktop app) ──

let invoke: ((cmd: string, args?: Record<string, unknown>) => Promise<unknown>) | null = null;

function isTauri(): boolean {
  return typeof window !== "undefined" && "__TAURI_INTERNALS__" in window;
}

async function getInvoke() {
  if (invoke) return invoke;
  if (!isTauri()) return null;
  try {
    const mod = await import("@tauri-apps/api/core");
    invoke = mod.invoke;
    return invoke;
  } catch {
    return null;
  }
}

// ── Service layer: tries Tauri invoke first, falls back to HTTP API ──

export async function listAgents(configPath: string): Promise<Agent[]> {
  const inv = await getInvoke();
  if (inv) {
    try { return (await inv("list_agents", { configPath })) as Agent[]; } catch {}
  }
  return api<Agent[]>(`/api/agents?path=${encodeURIComponent(configPath)}`);
}

export async function startCycle(projectPath: string, cycles: number): Promise<CycleStatus> {
  const inv = await getInvoke();
  if (inv) {
    try { return (await inv("start_cycle", { projectPath, cycles })) as CycleStatus; } catch {}
  }
  const result = await api<{ started: boolean; project: string; cycles: number; pid: number }>(
    `/api/start?path=${encodeURIComponent(projectPath)}&cycles=${cycles}`
  );
  return {
    running: result.started,
    cycle_number: result.cycles,
    agents_run: 0,
    last_cycle_time: new Date().toISOString(),
    project_path: projectPath,
  };
}

export async function stopCycle(project?: string): Promise<void> {
  const inv = await getInvoke();
  if (inv) {
    try { await inv("stop_cycle"); } catch {}
    return;
  }
  await api(`/api/stop${project ? `?project=${encodeURIComponent(project)}` : ""}`);
}

export async function getCycleStatus(): Promise<CycleStatus> {
  const inv = await getInvoke();
  if (inv) {
    try { return (await inv("get_cycle_status")) as CycleStatus; } catch {}
  }
  const status = await api<{ running: boolean; count: number; cycles: Array<{ project: string; pid: number; cycles: number }> }>("/api/running");
  return {
    running: status.running,
    cycle_number: status.count,
    agents_run: status.cycles?.length || 0,
    last_cycle_time: new Date().toISOString(),
    project_path: status.cycles?.[0]?.project || "",
  };
}

export async function getCycleLogs(cycleNumber: number): Promise<LogEntry[]> {
  const inv = await getInvoke();
  if (inv) {
    try { return (await inv("get_cycle_logs", { cycleNumber })) as LogEntry[]; } catch {}
  }
  return api<LogEntry[]>(`/api/logs?limit=50`);
}

export async function getLatestLogs(limit: number): Promise<LogEntry[]> {
  const inv = await getInvoke();
  if (inv) {
    try { return (await inv("get_latest_logs", { limit })) as LogEntry[]; } catch {}
  }
  return api<LogEntry[]>(`/api/logs?limit=${limit}`);
}

export async function readAgentsConf(path: string): Promise<AgentsConfig> {
  const inv = await getInvoke();
  if (inv) {
    try { return (await inv("read_agents_conf", { path })) as AgentsConfig; } catch {}
  }
  return api<AgentsConfig>(`/api/config?path=${encodeURIComponent(path)}`);
}

export async function writeAgentsConf(path: string, config: AgentsConfig): Promise<void> {
  const inv = await getInvoke();
  if (inv) {
    try { await inv("write_agents_conf", { path, config }); } catch {}
  }
}

export async function listProjects(): Promise<ProjectInfo[]> {
  const inv = await getInvoke();
  if (inv) {
    try { return (await inv("list_projects")) as ProjectInfo[]; } catch {}
  }
  return api<ProjectInfo[]>("/api/projects");
}

export async function scanProjects(dir: string): Promise<ProjectInfo[]> {
  const inv = await getInvoke();
  if (inv) {
    try { return (await inv("scan_projects", { dir })) as ProjectInfo[]; } catch {}
  }
  return api<ProjectInfo[]>(`/api/projects`);
}

// ── Pixel Agents ──

export async function getPixelEvents(projectPath: string): Promise<PixelEventsResponse> {
  return api<PixelEventsResponse>(`/api/pixel-events?project=${encodeURIComponent(projectPath)}`);
}

// ── Chat ──

export async function sendChatMessage(
  agent: string,
  message: string,
  projectPath: string
): Promise<ChatResponse> {
  return apiPost<ChatResponse>(`/api/chat`, { agent, message, project: projectPath });
}

// ── Onboarding ──

export async function initProject(
  path: string,
  template?: string,
  dryRun = true
): Promise<DetectedProject> {
  return apiPost<DetectedProject>(`/api/init-project`, { path, template, dry_run: dryRun });
}

// ── Streaming output (SSE) ──

export function streamOutput(
  projectPath: string,
  onChunk: (text: string) => void,
  onEnd?: () => void
): () => void {
  const url = `${API_BASE}/api/stream/output?project=${encodeURIComponent(projectPath)}`;
  const es = new EventSource(url);

  es.onmessage = (ev) => {
    try {
      const data = JSON.parse(ev.data) as { chunk?: string };
      if (data.chunk) onChunk(data.chunk);
    } catch {
      // ignore malformed
    }
  };

  es.addEventListener("end", () => {
    es.close();
    if (onEnd) onEnd();
  });

  es.onerror = () => {
    es.close();
    if (onEnd) onEnd();
  };

  return () => es.close();
}
