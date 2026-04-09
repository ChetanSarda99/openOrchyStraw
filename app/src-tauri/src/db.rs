use rusqlite::{Connection, Result};

/// Initialize the SQLite database with required tables.
pub fn init_db(app_dir: &str) -> Result<Connection> {
    let db_path = format!("{}/orchystraw.db", app_dir);
    let conn = Connection::open(&db_path)?;

    conn.execute_batch(
        "
        CREATE TABLE IF NOT EXISTS preferences (
            key   TEXT PRIMARY KEY,
            value TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS cached_projects (
            path         TEXT PRIMARY KEY,
            name         TEXT NOT NULL,
            agents_count INTEGER NOT NULL DEFAULT 0,
            last_run     TEXT,
            registered   INTEGER NOT NULL DEFAULT 0,
            updated_at   TEXT NOT NULL DEFAULT (datetime('now'))
        );

        CREATE TABLE IF NOT EXISTS cached_agents (
            project_path TEXT NOT NULL,
            agent_id     TEXT NOT NULL,
            label        TEXT NOT NULL,
            interval     INTEGER NOT NULL DEFAULT 1,
            last_status  TEXT,
            updated_at   TEXT NOT NULL DEFAULT (datetime('now')),
            PRIMARY KEY (project_path, agent_id)
        );

        CREATE TABLE IF NOT EXISTS cycle_history (
            id           INTEGER PRIMARY KEY AUTOINCREMENT,
            project_path TEXT NOT NULL,
            cycle_number INTEGER NOT NULL,
            started_at   TEXT NOT NULL,
            finished_at  TEXT,
            agents_run   TEXT,
            status       TEXT NOT NULL DEFAULT 'running'
        );
        ",
    )?;

    Ok(conn)
}
