use crate::models::{Agent, AgentsConfig, ValidationResult};
use std::fs;

/// Read and parse an agents.conf file.
#[tauri::command]
pub fn read_agents_conf(path: String) -> Result<AgentsConfig, String> {
    let content =
        fs::read_to_string(&path).map_err(|e| format!("Failed to read {}: {}", path, e))?;

    let agents = parse_agents_from_content(&content);

    Ok(AgentsConfig {
        agents,
        path,
    })
}

/// Write agents back to an agents.conf file.
#[tauri::command]
pub fn write_agents_conf(path: String, agents: Vec<Agent>) -> Result<String, String> {
    // Compute column widths for alignment
    let id_width = agents.iter().map(|a| a.id.len()).max().unwrap_or(12);
    let prompt_width = agents
        .iter()
        .map(|a| a.prompt_path.len())
        .max()
        .unwrap_or(40);
    let ownership_width = agents
        .iter()
        .map(|a| a.ownership.len())
        .max()
        .unwrap_or(30);

    let mut lines = Vec::new();
    lines.push("# OrchyStraw — agents.conf".to_string());
    lines.push("# Format: id | prompt_path | ownership | interval | label".to_string());
    lines.push(String::new());

    for agent in &agents {
        lines.push(format!(
            "{:<id_w$} | {:<prompt_w$} | {:<own_w$} | {} | {}",
            agent.id,
            agent.prompt_path,
            agent.ownership,
            agent.interval,
            agent.label,
            id_w = id_width,
            prompt_w = prompt_width,
            own_w = ownership_width,
        ));
    }

    // Ensure trailing newline
    let content = lines.join("\n") + "\n";

    fs::write(&path, &content).map_err(|e| format!("Failed to write {}: {}", path, e))?;

    Ok(format!("Wrote {} agents to {}", agents.len(), path))
}

/// Validate an agents.conf file for common errors.
#[tauri::command]
pub fn validate_agents_conf(path: String) -> Result<ValidationResult, String> {
    let content =
        fs::read_to_string(&path).map_err(|e| format!("Failed to read {}: {}", path, e))?;

    let mut errors: Vec<String> = Vec::new();
    let mut seen_ids: Vec<String> = Vec::new();
    let mut coordinator_count = 0;

    for (line_num, line) in content.lines().enumerate() {
        let trimmed = line.trim();
        if trimmed.is_empty() || trimmed.starts_with('#') {
            continue;
        }

        let parts: Vec<&str> = trimmed.split('|').collect();

        if parts.len() < 5 {
            errors.push(format!(
                "Line {}: expected 5 pipe-delimited fields, got {}",
                line_num + 1,
                parts.len()
            ));
            continue;
        }

        let id = parts[0].trim();
        let prompt_path = parts[1].trim();
        let interval_str = parts[3].trim();

        // Check for duplicate IDs
        if seen_ids.contains(&id.to_string()) {
            errors.push(format!("Line {}: duplicate agent ID '{}'", line_num + 1, id));
        }
        seen_ids.push(id.to_string());

        // Check that prompt_path is non-empty
        if prompt_path.is_empty() {
            errors.push(format!(
                "Line {}: agent '{}' has empty prompt_path",
                line_num + 1,
                id
            ));
        }

        // Check that interval is a valid number
        match interval_str.parse::<u32>() {
            Ok(0) => coordinator_count += 1,
            Ok(_) => {}
            Err(_) => {
                errors.push(format!(
                    "Line {}: agent '{}' has invalid interval '{}'",
                    line_num + 1,
                    id,
                    interval_str
                ));
            }
        }
    }

    if coordinator_count > 1 {
        errors.push(format!(
            "Multiple coordinators (interval=0) found: {}. Expected at most 1.",
            coordinator_count
        ));
    }

    Ok(ValidationResult {
        valid: errors.is_empty(),
        errors,
    })
}

/// Parse agents from file content (shared helper).
fn parse_agents_from_content(content: &str) -> Vec<Agent> {
    content
        .lines()
        .filter(|line| {
            let trimmed = line.trim();
            !trimmed.is_empty() && !trimmed.starts_with('#')
        })
        .filter_map(|line| {
            let parts: Vec<&str> = line.split('|').collect();
            if parts.len() < 5 {
                return None;
            }
            Some(Agent {
                id: parts[0].trim().to_string(),
                prompt_path: parts[1].trim().to_string(),
                ownership: parts[2].trim().to_string(),
                interval: parts[3].trim().parse().unwrap_or(1),
                label: parts[4].trim().to_string(),
            })
        })
        .collect()
}
