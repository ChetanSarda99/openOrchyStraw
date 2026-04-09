use crate::models::ProjectInfo;
use std::fs;
use std::path::Path;

/// List all registered projects from ~/.orchystraw/registry.jsonl.
#[tauri::command]
pub fn list_projects() -> Result<Vec<ProjectInfo>, String> {
    let home = std::env::var("HOME").map_err(|_| "HOME not set".to_string())?;
    let registry_path = format!("{}/.orchystraw/registry.jsonl", home);

    let content = match fs::read_to_string(&registry_path) {
        Ok(c) => c,
        Err(_) => return Ok(vec![]),
    };

    let projects: Vec<ProjectInfo> = content
        .lines()
        .filter(|line| !line.trim().is_empty())
        .filter_map(|line| {
            let value: serde_json::Value = serde_json::from_str(line).ok()?;
            let path = value.get("path")?.as_str()?.to_string();
            let name = value
                .get("name")
                .and_then(|v| v.as_str())
                .unwrap_or_else(|| {
                    Path::new(&path)
                        .file_name()
                        .and_then(|n| n.to_str())
                        .unwrap_or("unknown")
                })
                .to_string();

            // Count agents if agents.conf exists
            let agents_count = count_agents_in_project(&path);

            Some(ProjectInfo {
                name,
                path,
                agents_count,
                last_run: value
                    .get("last_run")
                    .and_then(|v| v.as_str())
                    .map(|s| s.to_string()),
                registered: true,
            })
        })
        .collect();

    Ok(projects)
}

/// Get detailed info for a single project.
#[tauri::command]
pub fn get_project_info(path: String) -> Result<ProjectInfo, String> {
    let project_path = Path::new(&path);

    if !project_path.exists() {
        return Err(format!("Project path does not exist: {}", path));
    }

    let name = project_path
        .file_name()
        .and_then(|n| n.to_str())
        .unwrap_or("unknown")
        .to_string();

    let agents_count = count_agents_in_project(&path);

    // Check for last run time from .orchystraw/audit.jsonl
    let last_run = read_last_run_time(&path);

    // Check if registered
    let registered = is_project_registered(&path);

    Ok(ProjectInfo {
        name,
        path,
        agents_count,
        last_run,
        registered,
    })
}

/// Scan a directory for subdirectories that contain agents.conf.
#[tauri::command]
pub fn scan_projects(base_dir: String) -> Result<Vec<ProjectInfo>, String> {
    let base = Path::new(&base_dir);
    if !base.is_dir() {
        return Err(format!("Not a directory: {}", base_dir));
    }

    let mut projects = Vec::new();

    let entries =
        fs::read_dir(base).map_err(|e| format!("Failed to read directory: {}", e))?;

    for entry in entries.flatten() {
        let entry_path = entry.path();
        if !entry_path.is_dir() {
            continue;
        }

        let conf_path = entry_path.join("agents.conf");
        if !conf_path.exists() {
            continue;
        }

        let path_str = entry_path.to_string_lossy().to_string();
        let name = entry_path
            .file_name()
            .and_then(|n| n.to_str())
            .unwrap_or("unknown")
            .to_string();

        let agents_count = count_agents_in_project(&path_str);
        let registered = is_project_registered(&path_str);

        projects.push(ProjectInfo {
            name,
            path: path_str,
            agents_count,
            last_run: None,
            registered,
        });
    }

    Ok(projects)
}

/// Count agents in a project's agents.conf.
fn count_agents_in_project(project_path: &str) -> usize {
    let conf_path = format!("{}/agents.conf", project_path);
    match fs::read_to_string(&conf_path) {
        Ok(content) => content
            .lines()
            .filter(|line| {
                let trimmed = line.trim();
                !trimmed.is_empty() && !trimmed.starts_with('#') && trimmed.contains('|')
            })
            .count(),
        Err(_) => 0,
    }
}

/// Read the last run time from .orchystraw/audit.jsonl.
fn read_last_run_time(project_path: &str) -> Option<String> {
    let audit_path = format!("{}/.orchystraw/audit.jsonl", project_path);
    let content = fs::read_to_string(&audit_path).ok()?;
    let last_line = content.lines().rev().find(|l| !l.trim().is_empty())?;
    let value: serde_json::Value = serde_json::from_str(last_line).ok()?;
    value
        .get("timestamp")
        .and_then(|v| v.as_str())
        .map(|s| s.to_string())
}

/// Check if a project is in the global registry.
fn is_project_registered(project_path: &str) -> bool {
    let home = match std::env::var("HOME") {
        Ok(h) => h,
        Err(_) => return false,
    };
    let registry_path = format!("{}/.orchystraw/registry.jsonl", home);
    match fs::read_to_string(&registry_path) {
        Ok(content) => content.lines().any(|line| {
            serde_json::from_str::<serde_json::Value>(line)
                .ok()
                .and_then(|v| v.get("path").and_then(|p| p.as_str()).map(|s| s.to_string()))
                .map(|p| p == project_path)
                .unwrap_or(false)
        }),
        Err(_) => false,
    }
}
