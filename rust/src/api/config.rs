use serde::{Deserialize, Serialize};
use std::fs;
use std::path::PathBuf;
use super::error::Result;

/// Constants for supported download languages
pub const SUPPORTED_DOWNLOAD_LANGUAGES: &[(&str, &str)] = &[
    ("br", "Brazilian Portuguese"),
    ("cn", "Chinese"),
    ("da", "Danish"),
    ("nl", "Dutch"),
    ("en", "English"),
    ("fi", "Finnish"),
    ("fr", "French"),
    ("de", "German"),
    ("hu", "Hungarian"),
    ("it", "Italian"),
    ("jp", "Japanese"),
    ("ko", "Korean"),
    ("no", "Norwegian"),
    ("pl", "Polish"),
    ("pt", "Portuguese"),
    ("ru", "Russian"),
    ("es", "Spanish"),
    ("sv", "Swedish"),
    ("tr", "Turkish"),
    ("ro", "Romanian"),
];

/// Constants for supported UI locales
pub const SUPPORTED_LOCALES: &[(&str, &str)] = &[
    ("", "System default"),
    ("pt_BR", "Brazilian Portuguese"),
    ("cs_CZ", "Czech"),
    ("nl", "Dutch"),
    ("en_US", "English"),
    ("fi", "Finnish"),
    ("fr", "French"),
    ("de", "German"),
    ("it_IT", "Italian"),
    ("nb_NO", "Norwegian Bokmål"),
    ("nn_NO", "Norwegian Nynorsk"),
    ("pl", "Polish"),
    ("pt_PT", "Portuguese"),
    ("ru_RU", "Russian"),
    ("zh_CN", "Simplified Chinese"),
    ("es", "Spanish"),
    ("es_ES", "Spanish (Spain)"),
    ("sv_SE", "Swedish"),
    ("zh_TW", "Traditional Chinese"),
    ("tr", "Turkish"),
    ("uk", "Ukrainian"),
    ("el", "Greek"),
    ("ro", "Romanian"),
];

/// Views available in the library
pub const VIEWS: &[(&str, &str)] = &[
    ("grid", "Grid"),
    ("list", "List"),
];

/// Game IDs to ignore when received by the API
pub const IGNORE_GAME_IDS: &[i64] = &[
    1424856371,  // Hotline Miami 2: Wrong Number - Digital Comics
    1980301910,  // The Witcher Goodies Collection
    2005648906,  // Spring Sale Goodies Collection #1
    1486144755,  // Cyberpunk 2077 Goodies Collection
    1581684020,  // A Plague Tale Digital Goodies Pack
    1185685769,  // CDPR Goodie Pack Content
];

/// Minimum resume size (20 MB) - below this, restart the download
pub const MINIMUM_RESUME_SIZE: u64 = 20 * 1024 * 1024;

/// Default number of download threads
pub const DEFAULT_DOWNLOAD_THREAD_COUNT: i32 = 4;

/// Windows executables to ignore when launching games
pub const BINARY_NAMES_TO_IGNORE: &[&str] = &[
    "unins000.exe",
    "UnityCrashHandler64.exe",
    "nglide_config.exe",
    "ipxconfig.exe",
    "BNUpdate.exe",
    "VidSize.exe",
    "FRED2.exe",
    "FS2.exe",
];

/// Application configuration
#[flutter_rust_bridge::frb(non_opaque)]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Config {
    pub locale: String,
    pub lang: String,
    pub view: String,
    pub install_dir: String,
    pub username: String,
    pub refresh_token: String,
    pub keep_installers: bool,
    pub stay_logged_in: bool,
    pub use_dark_theme: bool,
    pub show_hidden_games: bool,
    pub show_windows_games: bool,
    pub keep_window_maximized: bool,
    pub installed_filter: bool,
    pub create_applications_file: bool,
    pub max_parallel_game_downloads: i32,
    pub current_downloads: Vec<i64>,
    pub paused_downloads: std::collections::HashMap<String, u64>,
    pub active_account_id: Option<String>,
}

impl Default for Config {
    fn default() -> Self {
        Config {
            locale: String::new(),
            lang: "en".to_string(),
            view: "grid".to_string(),
            install_dir: get_default_install_dir(),
            username: String::new(),
            refresh_token: String::new(),
            keep_installers: false,
            stay_logged_in: true,
            use_dark_theme: false,
            show_hidden_games: false,
            show_windows_games: false,
            keep_window_maximized: false,
            installed_filter: false,
            create_applications_file: false,
            max_parallel_game_downloads: DEFAULT_DOWNLOAD_THREAD_COUNT,
            current_downloads: Vec::new(),
            paused_downloads: std::collections::HashMap::new(),
            active_account_id: None,
        }
    }
}

#[flutter_rust_bridge::frb(ignore)]
impl Config {
    pub fn load() -> Result<Self> {
        let config_path = get_config_file_path();
        if config_path.exists() {
            let content = fs::read_to_string(&config_path)?;
            let config: Config = serde_json::from_str(&content)
                .unwrap_or_else(|_| Config::default());
            Ok(config)
        } else {
            Ok(Config::default())
        }
    }

    pub fn save(&self) -> Result<()> {
        let config_path = get_config_file_path();
        if let Some(parent) = config_path.parent() {
            fs::create_dir_all(parent)?;
        }
        let content = serde_json::to_string_pretty(self)?;
        fs::write(&config_path, content)?;
        Ok(())
    }

    pub fn add_ongoing_download(&mut self, download_id: i64) {
        if !self.current_downloads.contains(&download_id) {
            self.current_downloads.push(download_id);
        }
    }

    pub fn remove_ongoing_download(&mut self, download_id: i64) {
        self.current_downloads.retain(|&id| id != download_id);
    }

    pub fn add_paused_download(&mut self, save_location: String, progress: u64) {
        self.paused_downloads.insert(save_location, progress);
    }

    pub fn remove_paused_download(&mut self, save_location: &str) {
        self.paused_downloads.remove(save_location);
    }
}

fn get_default_install_dir() -> String {
    dirs::home_dir()
        .map(|h| h.join("GOG Games"))
        .unwrap_or_else(|| PathBuf::from("/home/GOG Games"))
        .to_string_lossy()
        .to_string()
}

#[flutter_rust_bridge::frb(ignore)]
pub fn get_config_file_path() -> PathBuf {
    dirs::config_dir()
        .unwrap_or_else(|| PathBuf::from(".config"))
        .join("minigalaxy")
        .join("config.json")
}

#[flutter_rust_bridge::frb(ignore)]
pub fn get_data_dir() -> PathBuf {
    dirs::data_local_dir()
        .unwrap_or_else(|| PathBuf::from(".local/share"))
        .join("minigalaxy")
}

#[flutter_rust_bridge::frb(ignore)]
pub fn get_cache_dir() -> PathBuf {
    dirs::cache_dir()
        .unwrap_or_else(|| PathBuf::from(".cache"))
        .join("minigalaxy")
}

#[flutter_rust_bridge::frb(ignore)]
pub fn get_icon_dir() -> PathBuf {
    get_cache_dir().join("icons")
}

#[flutter_rust_bridge::frb(ignore)]
pub fn get_thumbnail_dir() -> PathBuf {
    get_cache_dir().join("thumbnails")
}

#[flutter_rust_bridge::frb(ignore)]
pub fn get_config_games_dir() -> PathBuf {
    get_data_dir().join("games")
}
