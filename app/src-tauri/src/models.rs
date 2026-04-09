use serde::{Deserialize, Serialize};

/// A single agent entry parsed from agents.conf.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Agent {
    pub id: String,
    pub prompt_path: String,
    pub ownership: String,
    pub interval: u32,
    pub label: String,
}

/// Current cycle execution status.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CycleStatus {
    pub running: bool,
    pub cycle_number: u32,
    pub agents_run: Vec<String>,
    pub last_cycle_time: Option<String>,
    pub project_path: String,
}

/// A single log entry from the orchestrator.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LogEntry {
    pub timestamp: String,
    pub agent_id: String,
    pub level: String,
    pub message: String,
    pub cycle: u32,
}

/// Parsed agents.conf with metadata.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AgentsConfig {
    pub agents: Vec<Agent>,
    pub path: String,
}

/// Result of validating an agents.conf file.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ValidationResult {
    pub valid: bool,
    pub errors: Vec<String>,
}

/// Information about a registered project.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProjectInfo {
    pub name: String,
    pub path: String,
    pub agents_count: usize,
    pub last_run: Option<String>,
    pub registered: bool,
}
