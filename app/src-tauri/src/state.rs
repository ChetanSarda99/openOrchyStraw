use rusqlite::Connection;
use std::process::Child;
use std::sync::Mutex;

/// Application state shared across all Tauri commands.
pub struct AppState {
    /// Path to the currently active project.
    pub current_project: Mutex<Option<String>>,
    /// Handle to a running orchestrator child process.
    pub running_process: Mutex<Option<Child>>,
    /// SQLite connection for preferences and cached data.
    pub db: Mutex<Connection>,
}

impl AppState {
    /// Create a new AppState with an initialized SQLite connection.
    pub fn new(db: Connection) -> Self {
        Self {
            current_project: Mutex::new(None),
            running_process: Mutex::new(None),
            db: Mutex::new(db),
        }
    }
}
