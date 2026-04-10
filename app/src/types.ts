export interface Agent {
  id: string;
  prompt_path: string;
  ownership: string;
  interval: number;
  label: string;
}

export interface CycleStatus {
  running: boolean;
  cycle_number: number;
  agents_run: number;
  last_cycle_time: string;
  project_path: string;
}

export interface LogEntry {
  timestamp: string;
  agent_id: string;
  level: string;
  message: string;
  cycle: number;
}

export interface ProjectInfo {
  name: string;
  path: string;
  agents_count: number;
  last_run: string;
}

export interface AgentsConfig {
  agents: Agent[];
  raw: string;
}

export type View = "dashboard" | "agents" | "logs" | "config" | "settings" | "chat";

// ── Pixel Agents events ──
export interface PixelAgent {
  agent_id: string;
  label?: string;
  last_tool: string;
  last_message: string | null;
  last_timestamp: string | null;
  alive: boolean;
  state: "idle" | "working";
}

export interface PixelEventsResponse {
  project: string;
  agents: PixelAgent[];
  now: string;
}

// ── Chat ──
export interface ChatMessage {
  id: string;
  role: "user" | "agent";
  agent?: string;
  content: string;
  timestamp: string;
}

export interface ChatResponse {
  agent: string;
  response: string;
  exit_code: number;
}

// ── Project onboarding ──
export type ProjectTemplate = "saas" | "api" | "content" | "yc-startup";

export interface DetectedProject {
  path: string;
  exists: boolean;
  detected_type: string;
  markers_found: string[];
  suggested_template: ProjectTemplate | string;
  template?: string;
  agents_conf_preview?: string;
  dry_run?: boolean;
  initialized?: boolean;
  error?: string;
}
