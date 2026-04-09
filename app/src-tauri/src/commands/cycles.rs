use crate::models::CycleStatus;
use crate::state::AppState;
use std::fs;
use std::process::Command;
use tauri::State;

/// Start an orchestration cycle by spawning the orchystraw CLI.
#[tauri::command]
pub fn start_cycle(
    project_path: String,
    cycles: u32,
    review: bool,
    state: State<AppState>,
) -> Result<String, String> {
    // Check if a cycle is already running
    {
        let process = state
            .running_process
            .lock()
            .map_err(|e| format!("Lock error: {}", e))?;
        if process.is_some() {
            return Err("A cycle is already running".to_string());
        }
    }

    let mut cmd = Command::new("orchystraw");
    cmd.arg("run").arg(&project_path);
    cmd.arg("--cycles").arg(cycles.to_string());

    if review {
        cmd.arg("--review");
    }

    let child = cmd
        .stdout(std::process::Stdio::piped())
        .stderr(std::process::Stdio::piped())
        .spawn()
        .map_err(|e| format!("Failed to start orchystraw: {}", e))?;

    let pid = child.id();

    // Store the child process handle
    {
        let mut process = state
            .running_process
            .lock()
            .map_err(|e| format!("Lock error: {}", e))?;
        *process = Some(child);
    }

    // Update current project
    {
        let mut current = state
            .current_project
            .lock()
            .map_err(|e| format!("Lock error: {}", e))?;
        *current = Some(project_path);
    }

    Ok(format!("Cycle started (PID: {})", pid))
}

/// Stop a running cycle by killing the child process.
#[tauri::command]
pub fn stop_cycle(state: State<AppState>) -> Result<String, String> {
    let mut process = state
        .running_process
        .lock()
        .map_err(|e| format!("Lock error: {}", e))?;

    match process.take() {
        Some(mut child) => {
            child
                .kill()
                .map_err(|e| format!("Failed to kill process: {}", e))?;
            child
                .wait()
                .map_err(|e| format!("Failed to wait for process: {}", e))?;
            Ok("Cycle stopped".to_string())
        }
        None => Err("No cycle is running".to_string()),
    }
}

/// Get the current cycle status by reading .orchystraw/audit.jsonl.
#[tauri::command]
pub fn get_cycle_status(state: State<AppState>) -> Result<CycleStatus, String> {
    let project = state
        .current_project
        .lock()
        .map_err(|e| format!("Lock error: {}", e))?;

    let project_path = project
        .as_ref()
        .ok_or_else(|| "No project selected".to_string())?
        .clone();

    let is_running = {
        let process = state
            .running_process
            .lock()
            .map_err(|e| format!("Lock error: {}", e))?;
        process.is_some()
    };

    let audit_path = format!("{}/.orchystraw/audit.jsonl", project_path);

    let (cycle_number, agents_run, last_cycle_time) = match fs::read_to_string(&audit_path) {
        Ok(content) => parse_audit_log(&content),
        Err(_) => (0, vec![], None),
    };

    Ok(CycleStatus {
        running: is_running,
        cycle_number,
        agents_run,
        last_cycle_time,
        project_path,
    })
}

/// Parse the audit.jsonl file to extract cycle information.
fn parse_audit_log(content: &str) -> (u32, Vec<String>, Option<String>) {
    let mut cycle_number: u32 = 0;
    let mut agents_run: Vec<String> = Vec::new();
    let mut last_time: Option<String> = None;

    for line in content.lines().rev() {
        if line.trim().is_empty() {
            continue;
        }
        if let Ok(entry) = serde_json::from_str::<serde_json::Value>(line) {
            if let Some(cycle) = entry.get("cycle").and_then(|c| c.as_u64()) {
                if cycle as u32 > cycle_number {
                    cycle_number = cycle as u32;
                }
            }
            if let Some(agent) = entry.get("agent_id").and_then(|a| a.as_str()) {
                if !agents_run.contains(&agent.to_string()) {
                    agents_run.push(agent.to_string());
                }
            }
            if last_time.is_none() {
                last_time = entry
                    .get("timestamp")
                    .and_then(|t| t.as_str())
                    .map(|s| s.to_string());
            }
        }
    }

    (cycle_number, agents_run, last_time)
}
