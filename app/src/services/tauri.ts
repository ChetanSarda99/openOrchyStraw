import type { Agent, AgentsConfig, CycleStatus, LogEntry, ProjectInfo } from "@/types";

// ── API Configuration ──
// The app server runs locally. Configure via env or defaults.
const API_BASE = import.meta.env.VITE_API_URL || window.location.origin;

async function api<T>(path: string): Promise<T> {
  const res = await fetch(`${API_BASE}${path}`);
  if (!res.ok) throw new Error(`API ${path}: ${res.status}`);
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

export async function stopCycle(): Promise<void> {
  const inv = await getInvoke();
  if (inv) {
    try { await inv("stop_cycle"); } catch {}
  }
  await api("/api/stop");
}

export async function getCycleStatus(): Promise<CycleStatus> {
  const inv = await getInvoke();
  if (inv) {
    try { return (await inv("get_cycle_status")) as CycleStatus; } catch {}
  }
  const status = await api<{ running: boolean; project: string | null; pid: number | null }>("/api/running");
  return {
    running: status.running,
    cycle_number: 0,
    agents_run: 0,
    last_cycle_time: new Date().toISOString(),
    project_path: status.project || "",
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
