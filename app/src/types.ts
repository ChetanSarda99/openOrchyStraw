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

export type View = "dashboard" | "agents" | "logs" | "config" | "settings";
