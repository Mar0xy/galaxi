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
    // Wine settings
    pub wine_prefix: String,
    pub wine_executable: String,
    pub wine_debug: bool,
    pub wine_disable_ntsync: bool,
    pub wine_auto_install_dxvk: bool,
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
            wine_prefix: String::new(),
            wine_executable: String::new(),
            wine_debug: false,
            wine_disable_ntsync: false,
            wine_auto_install_dxvk: true,
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

    pub fn load_from_db() -> Result<Self> {
        use super::database::get_config_value;
        
        let mut config = Config::default();
        
        // Load each config value from the database
        if let Ok(val) = get_config_value("locale") { config.locale = val; }
        if let Ok(val) = get_config_value("lang") { config.lang = val; }
        if let Ok(val) = get_config_value("view") { config.view = val; }
        if let Ok(val) = get_config_value("install_dir") { config.install_dir = val; }
        if let Ok(val) = get_config_value("username") { config.username = val; }
        if let Ok(val) = get_config_value("refresh_token") { config.refresh_token = val; }
        if let Ok(val) = get_config_value("keep_installers") { config.keep_installers = val == "true"; }
        if let Ok(val) = get_config_value("stay_logged_in") { config.stay_logged_in = val == "true"; }
        if let Ok(val) = get_config_value("use_dark_theme") { config.use_dark_theme = val == "true"; }
        if let Ok(val) = get_config_value("show_hidden_games") { config.show_hidden_games = val == "true"; }
        if let Ok(val) = get_config_value("show_windows_games") { config.show_windows_games = val == "true"; }
        if let Ok(val) = get_config_value("active_account_id") { 
            config.active_account_id = if val.is_empty() { None } else { Some(val) }; 
        }
        // Wine settings
        if let Ok(val) = get_config_value("wine_prefix") { config.wine_prefix = val; }
        if let Ok(val) = get_config_value("wine_executable") { config.wine_executable = val; }
        if let Ok(val) = get_config_value("wine_debug") { config.wine_debug = val == "true"; }
        if let Ok(val) = get_config_value("wine_disable_ntsync") { config.wine_disable_ntsync = val == "true"; }
        if let Ok(val) = get_config_value("wine_auto_install_dxvk") { config.wine_auto_install_dxvk = val != "false"; }
        
        Ok(config)
    }

    pub fn save(&self) -> Result<()> {
        // Save to both JSON file (legacy) and database
        self.save_to_file()?;
        self.save_to_db()?;
        Ok(())
    }

    fn save_to_file(&self) -> Result<()> {
        let config_path = get_config_file_path();
        if let Some(parent) = config_path.parent() {
            fs::create_dir_all(parent)?;
        }
        let content = serde_json::to_string_pretty(self)?;
        fs::write(&config_path, content)?;
        Ok(())
    }

    pub fn save_to_db(&self) -> Result<()> {
        use super::database::set_config_value;
        
        let _ = set_config_value("locale", &self.locale);
        let _ = set_config_value("lang", &self.lang);
        let _ = set_config_value("view", &self.view);
        let _ = set_config_value("install_dir", &self.install_dir);
        let _ = set_config_value("username", &self.username);
        let _ = set_config_value("refresh_token", &self.refresh_token);
        let _ = set_config_value("keep_installers", if self.keep_installers { "true" } else { "false" });
        let _ = set_config_value("stay_logged_in", if self.stay_logged_in { "true" } else { "false" });
        let _ = set_config_value("use_dark_theme", if self.use_dark_theme { "true" } else { "false" });
        let _ = set_config_value("show_hidden_games", if self.show_hidden_games { "true" } else { "false" });
        let _ = set_config_value("show_windows_games", if self.show_windows_games { "true" } else { "false" });
        let _ = set_config_value("active_account_id", self.active_account_id.as_deref().unwrap_or(""));
        // Wine settings
        let _ = set_config_value("wine_prefix", &self.wine_prefix);
        let _ = set_config_value("wine_executable", &self.wine_executable);
        let _ = set_config_value("wine_debug", if self.wine_debug { "true" } else { "false" });
        let _ = set_config_value("wine_disable_ntsync", if self.wine_disable_ntsync { "true" } else { "false" });
        let _ = set_config_value("wine_auto_install_dxvk", if self.wine_auto_install_dxvk { "true" } else { "false" });
        
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
        .join("galaxi")
        .join("config.json")
}

#[flutter_rust_bridge::frb(ignore)]
pub fn get_data_dir() -> PathBuf {
    dirs::data_local_dir()
        .unwrap_or_else(|| PathBuf::from(".local/share"))
        .join("galaxi")
}

#[flutter_rust_bridge::frb(ignore)]
pub fn get_cache_dir() -> PathBuf {
    dirs::cache_dir()
        .unwrap_or_else(|| PathBuf::from(".cache"))
        .join("galaxi")
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
