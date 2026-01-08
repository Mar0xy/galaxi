// Database module for SQLite storage
// Replaces separate JSON files with a single SQLite database

use rusqlite::{Connection, params};
use std::path::PathBuf;
use std::sync::Mutex;
use super::error::{MinigalaxyError, Result};
use super::config::get_data_dir;

lazy_static::lazy_static! {
    static ref DB_CONNECTION: Mutex<Option<Connection>> = Mutex::new(None);
}

/// Get database path
#[flutter_rust_bridge::frb(ignore)]
pub fn get_db_path() -> PathBuf {
    get_data_dir().join("minigalaxy.db")
}

/// Initialize the database
#[flutter_rust_bridge::frb(ignore)]
pub fn init_database() -> Result<()> {
    let db_path = get_db_path();
    
    // Ensure directory exists
    if let Some(parent) = db_path.parent() {
        std::fs::create_dir_all(parent)?;
    }
    
    let conn = Connection::open(&db_path)
        .map_err(|e| MinigalaxyError::ConfigError(e.to_string()))?;
    
    // Create tables
    conn.execute_batch(
        "
        -- Configuration table
        CREATE TABLE IF NOT EXISTS config (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        );
        
        -- Accounts table
        CREATE TABLE IF NOT EXISTS accounts (
            user_id TEXT PRIMARY KEY,
            username TEXT NOT NULL,
            email TEXT,
            avatar_url TEXT,
            refresh_token TEXT NOT NULL,
            added_at TEXT NOT NULL,
            last_login TEXT,
            is_active INTEGER DEFAULT 0
        );
        
        -- Games cache table
        CREATE TABLE IF NOT EXISTS games (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            url TEXT,
            install_dir TEXT,
            image_url TEXT,
            platform TEXT,
            category TEXT,
            version TEXT,
            last_updated TEXT
        );
        
        -- Downloads table
        CREATE TABLE IF NOT EXISTS downloads (
            game_id INTEGER PRIMARY KEY,
            status TEXT NOT NULL,
            progress REAL DEFAULT 0,
            paused_at TEXT
        );
        
        -- DLCs table
        CREATE TABLE IF NOT EXISTS dlcs (
            id INTEGER PRIMARY KEY,
            game_id INTEGER NOT NULL,
            name TEXT NOT NULL,
            title TEXT,
            image_url TEXT,
            installed INTEGER DEFAULT 0,
            FOREIGN KEY (game_id) REFERENCES games(id)
        );
        "
    ).map_err(|e| MinigalaxyError::ConfigError(e.to_string()))?;
    
    // Insert default config values if not exists
    let default_install_dir = dirs::home_dir()
        .unwrap_or_else(|| PathBuf::from("."))
        .join("GOG Games")
        .to_string_lossy()
        .to_string();
    
    let defaults: Vec<(&str, &str)> = vec![
        ("locale", ""),
        ("lang", "en"),
        ("view", "grid"),
        ("install_dir", &default_install_dir),
        ("keep_installers", "false"),
        ("stay_logged_in", "true"),
        ("use_dark_theme", "false"),
        ("show_hidden_games", "false"),
        ("show_windows_games", "false"),
    ];
    
    for (key, value) in defaults {
        conn.execute(
            "INSERT OR IGNORE INTO config (key, value) VALUES (?1, ?2)",
            params![key, value],
        ).map_err(|e| MinigalaxyError::ConfigError(e.to_string()))?;
    }
    
    *DB_CONNECTION.lock().unwrap() = Some(conn);
    
    Ok(())
}

/// Get a config value
#[flutter_rust_bridge::frb(ignore)]
pub fn get_config_value(key: &str) -> Result<String> {
    let guard = DB_CONNECTION.lock().unwrap();
    let conn = guard.as_ref()
        .ok_or_else(|| MinigalaxyError::ConfigError("Database not initialized".to_string()))?;
    
    let value: String = conn.query_row(
        "SELECT value FROM config WHERE key = ?1",
        params![key],
        |row| row.get(0),
    ).map_err(|e| MinigalaxyError::ConfigError(e.to_string()))?;
    
    Ok(value)
}

/// Set a config value
#[flutter_rust_bridge::frb(ignore)]
pub fn set_config_value(key: &str, value: &str) -> Result<()> {
    let guard = DB_CONNECTION.lock().unwrap();
    let conn = guard.as_ref()
        .ok_or_else(|| MinigalaxyError::ConfigError("Database not initialized".to_string()))?;
    
    conn.execute(
        "INSERT OR REPLACE INTO config (key, value) VALUES (?1, ?2)",
        params![key, value],
    ).map_err(|e| MinigalaxyError::ConfigError(e.to_string()))?;
    
    Ok(())
}

/// Account database operations
pub mod accounts_db {
    use super::*;
    use crate::api::account::Account;
    
    #[flutter_rust_bridge::frb(ignore)]
    pub fn save_account(account: &Account) -> Result<()> {
        let guard = DB_CONNECTION.lock().unwrap();
        let conn = guard.as_ref()
            .ok_or_else(|| MinigalaxyError::ConfigError("Database not initialized".to_string()))?;
        
        conn.execute(
            "INSERT OR REPLACE INTO accounts (user_id, username, email, avatar_url, refresh_token, added_at, last_login) 
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
            params![
                account.user_id,
                account.username,
                account.email,
                account.avatar_url,
                account.refresh_token,
                account.added_at,
                account.last_login,
            ],
        ).map_err(|e| MinigalaxyError::ConfigError(e.to_string()))?;
        
        Ok(())
    }
    
    #[flutter_rust_bridge::frb(ignore)]
    pub fn get_all_accounts() -> Result<Vec<Account>> {
        let guard = DB_CONNECTION.lock().unwrap();
        let conn = guard.as_ref()
            .ok_or_else(|| MinigalaxyError::ConfigError("Database not initialized".to_string()))?;
        
        let mut stmt = conn.prepare(
            "SELECT user_id, username, email, avatar_url, refresh_token, added_at, last_login FROM accounts"
        ).map_err(|e| MinigalaxyError::ConfigError(e.to_string()))?;
        
        let accounts = stmt.query_map([], |row| {
            Ok(Account {
                user_id: row.get(0)?,
                username: row.get(1)?,
                email: row.get(2)?,
                avatar_url: row.get(3)?,
                refresh_token: row.get(4)?,
                added_at: row.get(5)?,
                last_login: row.get(6)?,
            })
        }).map_err(|e| MinigalaxyError::ConfigError(e.to_string()))?;
        
        let mut result = Vec::new();
        for account in accounts {
            result.push(account.map_err(|e| MinigalaxyError::ConfigError(e.to_string()))?);
        }
        
        Ok(result)
    }
    
    #[flutter_rust_bridge::frb(ignore)]
    pub fn get_active_account() -> Result<Option<Account>> {
        let guard = DB_CONNECTION.lock().unwrap();
        let conn = guard.as_ref()
            .ok_or_else(|| MinigalaxyError::ConfigError("Database not initialized".to_string()))?;
        
        let result = conn.query_row(
            "SELECT user_id, username, email, avatar_url, refresh_token, added_at, last_login 
             FROM accounts WHERE is_active = 1",
            [],
            |row| {
                Ok(Account {
                    user_id: row.get(0)?,
                    username: row.get(1)?,
                    email: row.get(2)?,
                    avatar_url: row.get(3)?,
                    refresh_token: row.get(4)?,
                    added_at: row.get(5)?,
                    last_login: row.get(6)?,
                })
            },
        );
        
        match result {
            Ok(account) => Ok(Some(account)),
            Err(rusqlite::Error::QueryReturnedNoRows) => Ok(None),
            Err(e) => Err(MinigalaxyError::ConfigError(e.to_string())),
        }
    }
    
    #[flutter_rust_bridge::frb(ignore)]
    pub fn set_active_account(user_id: &str) -> Result<()> {
        let guard = DB_CONNECTION.lock().unwrap();
        let conn = guard.as_ref()
            .ok_or_else(|| MinigalaxyError::ConfigError("Database not initialized".to_string()))?;
        
        // Deactivate all accounts
        conn.execute("UPDATE accounts SET is_active = 0", [])
            .map_err(|e| MinigalaxyError::ConfigError(e.to_string()))?;
        
        // Activate the specified account
        conn.execute(
            "UPDATE accounts SET is_active = 1 WHERE user_id = ?1",
            params![user_id],
        ).map_err(|e| MinigalaxyError::ConfigError(e.to_string()))?;
        
        Ok(())
    }
    
    #[flutter_rust_bridge::frb(ignore)]
    pub fn remove_account(user_id: &str) -> Result<()> {
        let guard = DB_CONNECTION.lock().unwrap();
        let conn = guard.as_ref()
            .ok_or_else(|| MinigalaxyError::ConfigError("Database not initialized".to_string()))?;
        
        conn.execute(
            "DELETE FROM accounts WHERE user_id = ?1",
            params![user_id],
        ).map_err(|e| MinigalaxyError::ConfigError(e.to_string()))?;
        
        Ok(())
    }
}

/// Games database operations
pub mod games_db {
    use super::*;
    use crate::api::game::Game;
    use std::collections::HashMap;
    
    #[flutter_rust_bridge::frb(ignore)]
    pub fn save_game(game: &Game) -> Result<()> {
        let guard = DB_CONNECTION.lock().unwrap();
        let conn = guard.as_ref()
            .ok_or_else(|| MinigalaxyError::ConfigError("Database not initialized".to_string()))?;
        
        conn.execute(
            "INSERT OR REPLACE INTO games (id, name, url, install_dir, image_url, platform, category, last_updated) 
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, datetime('now'))",
            params![
                game.id,
                game.name,
                game.url,
                game.install_dir,
                game.image_url,
                game.platform,
                game.category,
            ],
        ).map_err(|e| MinigalaxyError::ConfigError(e.to_string()))?;
        
        Ok(())
    }
    
    #[flutter_rust_bridge::frb(ignore)]
    pub fn get_game(game_id: i64) -> Result<Option<Game>> {
        let guard = DB_CONNECTION.lock().unwrap();
        let conn = guard.as_ref()
            .ok_or_else(|| MinigalaxyError::ConfigError("Database not initialized".to_string()))?;
        
        let result = conn.query_row(
            "SELECT id, name, url, install_dir, image_url, platform, category FROM games WHERE id = ?1",
            params![game_id],
            |row| {
                Ok(Game {
                    id: row.get(0)?,
                    name: row.get(1)?,
                    url: row.get::<_, Option<String>>(2)?.unwrap_or_default(),
                    install_dir: row.get::<_, Option<String>>(3)?.unwrap_or_default(),
                    image_url: row.get::<_, Option<String>>(4)?.unwrap_or_default(),
                    platform: row.get::<_, Option<String>>(5)?.unwrap_or_else(|| "linux".to_string()),
                    category: row.get::<_, Option<String>>(6)?.unwrap_or_default(),
                    md5sum: HashMap::new(),
                    dlcs: Vec::new(),
                })
            },
        );
        
        match result {
            Ok(game) => Ok(Some(game)),
            Err(rusqlite::Error::QueryReturnedNoRows) => Ok(None),
            Err(e) => Err(MinigalaxyError::ConfigError(e.to_string())),
        }
    }
    
    #[flutter_rust_bridge::frb(ignore)]
    pub fn get_all_games() -> Result<Vec<Game>> {
        let guard = DB_CONNECTION.lock().unwrap();
        let conn = guard.as_ref()
            .ok_or_else(|| MinigalaxyError::ConfigError("Database not initialized".to_string()))?;
        
        let mut stmt = conn.prepare(
            "SELECT id, name, url, install_dir, image_url, platform, category FROM games"
        ).map_err(|e| MinigalaxyError::ConfigError(e.to_string()))?;
        
        let games = stmt.query_map([], |row| {
            Ok(Game {
                id: row.get(0)?,
                name: row.get(1)?,
                url: row.get::<_, Option<String>>(2)?.unwrap_or_default(),
                install_dir: row.get::<_, Option<String>>(3)?.unwrap_or_default(),
                image_url: row.get::<_, Option<String>>(4)?.unwrap_or_default(),
                platform: row.get::<_, Option<String>>(5)?.unwrap_or_else(|| "linux".to_string()),
                category: row.get::<_, Option<String>>(6)?.unwrap_or_default(),
                md5sum: HashMap::new(),
                dlcs: Vec::new(),
            })
        }).map_err(|e| MinigalaxyError::ConfigError(e.to_string()))?;
        
        let mut result = Vec::new();
        for game in games {
            result.push(game.map_err(|e| MinigalaxyError::ConfigError(e.to_string()))?);
        }
        
        Ok(result)
    }
}
