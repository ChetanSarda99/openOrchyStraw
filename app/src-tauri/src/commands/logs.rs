use crate::models::LogEntry;
use crate::state::AppState;
use std::fs;
use tauri::State;

/// Get cycle logs from the orchestrator log file.
#[tauri::command]
pub fn get_cycle_logs(
    cycle_number: Option<u32>,
    state: State<AppState>,
) -> Result<Vec<LogEntry>, String> {
    let project = state
        .current_project
        .lock()
        .map_err(|e| format!("Lock error: {}", e))?;

    let project_path = project
        .as_ref()
        .ok_or_else(|| "No project selected".to_string())?;

    let log_path = format!("{}/.orchystraw/orchestrator.log", project_path);
    let content =
        fs::read_to_string(&log_path).map_err(|e| format!("Failed to read log: {}", e))?;

    let entries: Vec<LogEntry> = content
        .lines()
        .filter_map(|line| parse_log_line(line))
        .filter(|entry| match cycle_number {
            Some(c) => entry.cycle == c,
            None => true,
        })
        .collect();

    Ok(entries)
}

/// Get the latest N log entries (tail).
#[tauri::command]
pub fn get_latest_logs(
    limit: usize,
    state: State<AppState>,
) -> Result<Vec<LogEntry>, String> {
    let project = state
        .current_project
        .lock()
        .map_err(|e| format!("Lock error: {}", e))?;

    let project_path = project
        .as_ref()
        .ok_or_else(|| "No project selected".to_string())?;

    let log_path = format!("{}/.orchystraw/orchestrator.log", project_path);

    let content = match fs::read_to_string(&log_path) {
        Ok(c) => c,
        Err(_) => return Ok(vec![]),
    };

    let entries: Vec<LogEntry> = content
        .lines()
        .filter_map(|line| parse_log_line(line))
        .collect();

    // Return the last `limit` entries
    let start = entries.len().saturating_sub(limit);
    Ok(entries[start..].to_vec())
}

/// Parse a single log line into a LogEntry.
///
/// Expected format: `[TIMESTAMP] [LEVEL] [AGENT_ID] [CYCLE:N] message`
/// Falls back to raw line if format doesn't match.
fn parse_log_line(line: &str) -> Option<LogEntry> {
    let trimmed = line.trim();
    if trimmed.is_empty() {
        return None;
    }

    // Try JSONL format first (audit.jsonl style)
    if trimmed.starts_with('{') {
        if let Ok(value) = serde_json::from_str::<serde_json::Value>(trimmed) {
            return Some(LogEntry {
                timestamp: value
                    .get("timestamp")
                    .and_then(|v| v.as_str())
                    .unwrap_or("")
                    .to_string(),
                agent_id: value
                    .get("agent_id")
                    .and_then(|v| v.as_str())
                    .unwrap_or("")
                    .to_string(),
                level: value
                    .get("level")
                    .and_then(|v| v.as_str())
                    .unwrap_or("info")
                    .to_string(),
                message: value
                    .get("message")
                    .and_then(|v| v.as_str())
                    .unwrap_or("")
                    .to_string(),
                cycle: value
                    .get("cycle")
                    .and_then(|v| v.as_u64())
                    .unwrap_or(0) as u32,
            });
        }
    }

    // Fallback: treat the whole line as a message
    Some(LogEntry {
        timestamp: String::new(),
        agent_id: String::new(),
        level: "info".to_string(),
        message: trimmed.to_string(),
        cycle: 0,
    })
}
