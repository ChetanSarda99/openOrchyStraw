use crate::models::Agent;
use crate::state::AppState;
use std::fs;
use tauri::State;

/// Parse an agents.conf file and return the list of agents.
fn parse_agents_conf(content: &str) -> Vec<Agent> {
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

/// List all agents from the project's agents.conf.
#[tauri::command]
pub fn list_agents(state: State<AppState>) -> Result<Vec<Agent>, String> {
    let project = state
        .current_project
        .lock()
        .map_err(|e| format!("Lock error: {}", e))?;

    let project_path = project
        .as_ref()
        .ok_or_else(|| "No project selected".to_string())?;

    let conf_path = format!("{}/agents.conf", project_path);
    let content = fs::read_to_string(&conf_path)
        .map_err(|e| format!("Failed to read {}: {}", conf_path, e))?;

    Ok(parse_agents_conf(&content))
}

/// Get the status of a specific agent from .orchystraw/ state files.
#[tauri::command]
pub fn get_agent_status(
    agent_id: String,
    state: State<AppState>,
) -> Result<serde_json::Value, String> {
    let project = state
        .current_project
        .lock()
        .map_err(|e| format!("Lock error: {}", e))?;

    let project_path = project
        .as_ref()
        .ok_or_else(|| "No project selected".to_string())?;

    let status_path = format!(
        "{}/.orchystraw/agent-status/{}.json",
        project_path, agent_id
    );

    match fs::read_to_string(&status_path) {
        Ok(content) => serde_json::from_str(&content)
            .map_err(|e| format!("Failed to parse agent status: {}", e)),
        Err(_) => Ok(serde_json::json!({
            "agent_id": agent_id,
            "status": "unknown",
            "last_run": null
        })),
    }
}

/// Read the raw prompt file content for a given agent.
#[tauri::command]
pub fn get_agent_prompt(
    agent_id: String,
    state: State<AppState>,
) -> Result<String, String> {
    let project = state
        .current_project
        .lock()
        .map_err(|e| format!("Lock error: {}", e))?;

    let project_path = project
        .as_ref()
        .ok_or_else(|| "No project selected".to_string())?;

    // First, find the agent's prompt path from agents.conf
    let conf_path = format!("{}/agents.conf", project_path);
    let content = fs::read_to_string(&conf_path)
        .map_err(|e| format!("Failed to read agents.conf: {}", e))?;

    let agents = parse_agents_conf(&content);
    let agent = agents
        .iter()
        .find(|a| a.id == agent_id)
        .ok_or_else(|| format!("Agent '{}' not found in agents.conf", agent_id))?;

    let prompt_path = format!("{}/{}", project_path, agent.prompt_path);
    fs::read_to_string(&prompt_path)
        .map_err(|e| format!("Failed to read prompt at {}: {}", prompt_path, e))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_agents_conf() {
        let content = r#"
# Comment line
00-cofounder | prompts/00-cofounder/00-cofounder.txt  | agents.conf docs/ | 2 | Co-Founder Operations
03-pm        | prompts/03-pm/03-pm.txt               | prompts/ docs/    | 0 | PM Coordinator

# Another comment
06-backend   | prompts/06-backend/06-backend.txt     | scripts/ src/     | 1 | Backend Developer
"#;
        let agents = parse_agents_conf(content);
        assert_eq!(agents.len(), 3);
        assert_eq!(agents[0].id, "00-cofounder");
        assert_eq!(agents[0].interval, 2);
        assert_eq!(agents[1].id, "03-pm");
        assert_eq!(agents[1].interval, 0);
        assert_eq!(agents[2].label, "Backend Developer");
    }

    #[test]
    fn test_parse_malformed_line() {
        let content = "bad line without pipes\n";
        let agents = parse_agents_conf(content);
        assert!(agents.is_empty());
    }
}
