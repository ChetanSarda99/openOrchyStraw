mod commands;
mod db;
mod models;
mod state;

use state::AppState;
use tauri::Manager;

/// Build and configure the Tauri application.
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .plugin(tauri_plugin_fs::init())
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_notification::init())
        .plugin(tauri_plugin_window_state::Builder::new().build())
        .setup(|app| {
            // Resolve app data directory for SQLite
            let app_dir = app
                .path()
                .app_data_dir()
                .expect("Failed to resolve app data dir");

            std::fs::create_dir_all(&app_dir).expect("Failed to create app data dir");

            let app_dir_str = app_dir.to_string_lossy().to_string();
            let conn = db::init_db(&app_dir_str).expect("Failed to initialize database");

            app.manage(AppState::new(conn));

            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            // Agent commands
            commands::agents::list_agents,
            commands::agents::get_agent_status,
            commands::agents::get_agent_prompt,
            // Cycle commands
            commands::cycles::start_cycle,
            commands::cycles::stop_cycle,
            commands::cycles::get_cycle_status,
            // Config commands
            commands::config::read_agents_conf,
            commands::config::write_agents_conf,
            commands::config::validate_agents_conf,
            // Log commands
            commands::logs::get_cycle_logs,
            commands::logs::get_latest_logs,
            // Project commands
            commands::projects::list_projects,
            commands::projects::get_project_info,
            commands::projects::scan_projects,
        ])
        .run(tauri::generate_context!())
        .expect("Error running OrchyStraw");
}
