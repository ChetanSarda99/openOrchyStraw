import type { Agent, AgentsConfig, CycleStatus, LogEntry, ProjectInfo } from "@/types";

let invoke: ((cmd: string, args?: Record<string, unknown>) => Promise<unknown>) | null = null;

async function getInvoke() {
  if (invoke) return invoke;
  try {
    const mod = await import("@tauri-apps/api/core");
    invoke = mod.invoke;
    return invoke;
  } catch {
    return null;
  }
}

function isTauri(): boolean {
  return typeof window !== "undefined" && "__TAURI_INTERNALS__" in window;
}

// --- Placeholder data for development outside Tauri ---

const PLACEHOLDER_AGENTS: Agent[] = [
  { id: "00-cofounder", prompt_path: "prompts/00-cofounder/", ownership: "agents.conf docs/operations/", interval: 2, label: "Co-Founder" },
  { id: "01-ceo", prompt_path: "prompts/01-ceo/", ownership: "docs/strategy/", interval: 3, label: "CEO" },
  { id: "02-cto", prompt_path: "prompts/02-cto/", ownership: "docs/architecture/", interval: 2, label: "CTO" },
  { id: "03-pm", prompt_path: "prompts/03-pm/", ownership: "prompts/ docs/", interval: 0, label: "PM" },
  { id: "06-backend", prompt_path: "prompts/06-backend/", ownership: "scripts/ src/core/", interval: 1, label: "Backend" },
  { id: "08-pixel", prompt_path: "prompts/08-pixel/", ownership: "src/pixel/", interval: 2, label: "Pixel Agents" },
  { id: "09-qa-code", prompt_path: "prompts/09-qa-code/", ownership: "tests/ reports/", interval: 3, label: "QA Code" },
  { id: "09-qa-visual", prompt_path: "prompts/09-qa-visual/", ownership: "reports/visual/", interval: 3, label: "QA Visual" },
  { id: "10-security", prompt_path: "prompts/10-security/", ownership: "(read-only)", interval: 5, label: "Security" },
  { id: "11-web", prompt_path: "prompts/11-web/", ownership: "site/", interval: 1, label: "Web Dev" },
  { id: "12-designer", prompt_path: "prompts/12-designer/", ownership: "assets/ images/", interval: 3, label: "Designer" },
  { id: "13-hr", prompt_path: "prompts/13-hr/", ownership: "docs/team/", interval: 3, label: "HR" },
];

const PLACEHOLDER_CYCLE: CycleStatus = {
  running: false,
  cycle_number: 42,
  agents_run: 12,
  last_cycle_time: "2026-04-08T14:30:00Z",
  project_path: "~/Projects/openOrchyStraw",
};

const PLACEHOLDER_LOGS: LogEntry[] = [
  { timestamp: "2026-04-08T14:30:12Z", agent_id: "06-backend", level: "info", message: "Refactored cycle-state module for clarity", cycle: 42 },
  { timestamp: "2026-04-08T14:29:45Z", agent_id: "09-qa-code", level: "warn", message: "Test coverage dropped below 80% threshold", cycle: 42 },
  { timestamp: "2026-04-08T14:28:30Z", agent_id: "11-web", level: "info", message: "Updated hero section copy and CTA", cycle: 42 },
  { timestamp: "2026-04-08T14:27:00Z", agent_id: "10-security", level: "error", message: "Found hardcoded path in config-validator.sh", cycle: 42 },
  { timestamp: "2026-04-08T14:25:15Z", agent_id: "02-cto", level: "info", message: "Approved architecture for Tauri desktop app", cycle: 42 },
  { timestamp: "2026-04-08T14:24:00Z", agent_id: "00-cofounder", level: "info", message: "Adjusted intervals: backend 1->1, web 2->1", cycle: 41 },
  { timestamp: "2026-04-08T14:22:30Z", agent_id: "03-pm", level: "info", message: "Created 3 GitHub issues from QA findings", cycle: 41 },
  { timestamp: "2026-04-08T14:20:00Z", agent_id: "12-designer", level: "info", message: "Generated social preview image 1200x630", cycle: 41 },
];

const PLACEHOLDER_PROJECTS: ProjectInfo[] = [
  { name: "openOrchyStraw", path: "~/Projects/openOrchyStraw", agents_count: 12, last_run: "2026-04-08T14:30:00Z" },
  { name: "Klaro", path: "~/Projects/Klaro", agents_count: 8, last_run: "2026-04-08T12:00:00Z" },
  { name: "AIVA", path: "~/Projects/AIVA", agents_count: 10, last_run: "2026-04-07T18:00:00Z" },
  { name: "InstagramAutomation", path: "~/Projects/InstagramAutomation", agents_count: 10, last_run: "2026-04-07T10:00:00Z" },
  { name: "LinkedInAutomation", path: "~/Projects/LinkedInAutomation", agents_count: 8, last_run: "2026-04-06T22:00:00Z" },
  { name: "FreelanceWorker", path: "~/Projects/FreelanceWorker", agents_count: 7, last_run: "2026-04-06T16:00:00Z" },
  { name: "macro-news-alpha", path: "~/Projects/macro-news-alpha", agents_count: 5, last_run: "2026-04-05T09:00:00Z" },
];

// --- Tauri command wrappers ---

export async function listAgents(configPath: string): Promise<Agent[]> {
  const inv = await getInvoke();
  if (!inv || !isTauri()) return PLACEHOLDER_AGENTS;
  try {
    return (await inv("list_agents", { configPath })) as Agent[];
  } catch {
    return PLACEHOLDER_AGENTS;
  }
}

export async function getCycleStatus(): Promise<CycleStatus> {
  const inv = await getInvoke();
  if (!inv || !isTauri()) return PLACEHOLDER_CYCLE;
  try {
    return (await inv("get_cycle_status")) as CycleStatus;
  } catch {
    return PLACEHOLDER_CYCLE;
  }
}

export async function startCycle(projectPath: string, cycles: number): Promise<CycleStatus> {
  const inv = await getInvoke();
  if (!inv || !isTauri()) return { ...PLACEHOLDER_CYCLE, running: true, cycle_number: PLACEHOLDER_CYCLE.cycle_number + 1 };
  try {
    return (await inv("start_cycle", { projectPath, cycles })) as CycleStatus;
  } catch {
    return { ...PLACEHOLDER_CYCLE, running: true };
  }
}

export async function stopCycle(): Promise<void> {
  const inv = await getInvoke();
  if (!inv || !isTauri()) return;
  try {
    await inv("stop_cycle");
  } catch {
    // noop in dev
  }
}

export async function getCycleLogs(cycleNumber: number): Promise<LogEntry[]> {
  const inv = await getInvoke();
  if (!inv || !isTauri()) return PLACEHOLDER_LOGS.filter((l) => l.cycle === cycleNumber);
  try {
    return (await inv("get_cycle_logs", { cycleNumber })) as LogEntry[];
  } catch {
    return PLACEHOLDER_LOGS.filter((l) => l.cycle === cycleNumber);
  }
}

export async function getLatestLogs(limit: number): Promise<LogEntry[]> {
  const inv = await getInvoke();
  if (!inv || !isTauri()) return PLACEHOLDER_LOGS.slice(0, limit);
  try {
    return (await inv("get_latest_logs", { limit })) as LogEntry[];
  } catch {
    return PLACEHOLDER_LOGS.slice(0, limit);
  }
}

export async function readAgentsConf(path: string): Promise<AgentsConfig> {
  const inv = await getInvoke();
  if (!inv || !isTauri()) return { agents: PLACEHOLDER_AGENTS, raw: "# agents.conf placeholder" };
  try {
    return (await inv("read_agents_conf", { path })) as AgentsConfig;
  } catch {
    return { agents: PLACEHOLDER_AGENTS, raw: "" };
  }
}

export async function writeAgentsConf(path: string, config: AgentsConfig): Promise<void> {
  const inv = await getInvoke();
  if (!inv || !isTauri()) return;
  try {
    await inv("write_agents_conf", { path, config });
  } catch {
    // noop in dev
  }
}

export async function listProjects(): Promise<ProjectInfo[]> {
  const inv = await getInvoke();
  if (!inv || !isTauri()) return PLACEHOLDER_PROJECTS;
  try {
    return (await inv("list_projects")) as ProjectInfo[];
  } catch {
    return PLACEHOLDER_PROJECTS;
  }
}

export async function scanProjects(dir: string): Promise<ProjectInfo[]> {
  const inv = await getInvoke();
  if (!inv || !isTauri()) return PLACEHOLDER_PROJECTS;
  try {
    return (await inv("scan_projects", { dir })) as ProjectInfo[];
  } catch {
    return PLACEHOLDER_PROJECTS;
  }
}
