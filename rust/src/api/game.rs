use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs;
use std::path::PathBuf;
use super::config::{get_config_games_dir, get_icon_dir, get_thumbnail_dir};
use super::error::Result;

/// Represents a game in the library
#[flutter_rust_bridge::frb(opaque)]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Game {
    pub name: String,
    pub url: String,
    pub md5sum: HashMap<String, String>,
    pub id: i64,
    pub install_dir: String,
    pub image_url: String,
    pub platform: String,
    pub dlcs: Vec<Dlc>,
    pub category: String,
}

/// Represents a DLC for a game
#[flutter_rust_bridge::frb(non_opaque)]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Dlc {
    pub id: i64,
    pub name: String,
    pub title: String,
    pub image_url: String,
}

/// Game information stored in JSON
#[flutter_rust_bridge::frb(non_opaque)]
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct GameInfo {
    pub version: Option<String>,
    pub dlcs: HashMap<String, DlcInfo>,
    pub show_fps: Option<bool>,
    pub use_gamemode: Option<bool>,
    pub use_mangohud: Option<bool>,
    pub variable: Option<String>,
    pub command: Option<String>,
    pub custom_wine: Option<String>,
    pub hidden: Option<bool>,
}

#[flutter_rust_bridge::frb(non_opaque)]
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct DlcInfo {
    pub version: Option<String>,
}

#[flutter_rust_bridge::frb(ignore)]
impl Game {
    pub fn new(name: String, id: i64) -> Self {
        Game {
            name,
            url: String::new(),
            md5sum: HashMap::new(),
            id,
            install_dir: String::new(),
            image_url: String::new(),
            platform: "linux".to_string(),
            dlcs: Vec::new(),
            category: String::new(),
        }
    }

    pub fn get_stripped_name(&self) -> String {
        self.name.chars()
            .filter(|c| c.is_alphanumeric())
            .collect()
    }

    pub fn get_install_directory_name(&self) -> String {
        self.name.chars()
            .filter(|c| c.is_alphanumeric() || c.is_whitespace())
            .collect::<String>()
            .trim()
            .to_string()
    }

    pub fn get_cached_icon_path(&self, dlc_id: Option<i64>) -> PathBuf {
        let icon_dir = get_icon_dir();
        if let Some(dlc) = dlc_id {
            icon_dir.join(format!("{}.jpg", dlc))
        } else {
            icon_dir.join(format!("{}.png", self.id))
        }
    }

    pub fn get_thumbnail_path(&self, use_fallback: bool) -> PathBuf {
        if self.is_installed() {
            let thumbnail_file = PathBuf::from(&self.install_dir).join("thumbnail.jpg");
            if thumbnail_file.exists() || !use_fallback {
                return thumbnail_file;
            }
        }

        let thumbnail_file = get_thumbnail_dir().join(format!("{}.jpg", self.id));
        if thumbnail_file.exists() || use_fallback {
            return thumbnail_file;
        }

        PathBuf::new()
    }

    pub fn get_status_file_path(&self) -> PathBuf {
        let last_install_dir = if !self.install_dir.is_empty() {
            PathBuf::from(&self.install_dir)
                .file_name()
                .map(|s| s.to_string_lossy().to_string())
                .unwrap_or_else(|| self.get_install_directory_name())
        } else {
            self.get_install_directory_name()
        };
        get_config_games_dir().join(format!("{}.json", last_install_dir))
    }

    pub fn load_game_info(&self) -> Result<GameInfo> {
        let status_path = self.get_status_file_path();
        if status_path.exists() {
            let content = fs::read_to_string(&status_path)?;
            let info: GameInfo = serde_json::from_str(&content).unwrap_or_default();
            Ok(info)
        } else {
            Ok(GameInfo::default())
        }
    }

    pub fn save_game_info(&self, info: &GameInfo) -> Result<()> {
        let status_path = self.get_status_file_path();
        if let Some(parent) = status_path.parent() {
            fs::create_dir_all(parent)?;
        }
        let content = serde_json::to_string_pretty(info)?;
        fs::write(&status_path, content)?;
        Ok(())
    }

    pub fn is_installed(&self) -> bool {
        !self.install_dir.is_empty() && PathBuf::from(&self.install_dir).exists()
    }

    pub fn is_dlc_installed(&self, dlc_title: &str) -> Result<bool> {
        let info = self.load_game_info()?;
        if let Some(dlc_info) = info.dlcs.get(dlc_title) {
            Ok(dlc_info.version.is_some())
        } else {
            Ok(false)
        }
    }

    pub fn is_update_available(&self, version_from_api: &str, dlc_title: Option<&str>) -> Result<bool> {
        let info = self.load_game_info()?;
        
        let installed_version = if let Some(dlc) = dlc_title {
            info.dlcs.get(dlc).and_then(|d| d.version.as_ref())
        } else {
            info.version.as_ref()
        };

        if let Some(installed) = installed_version {
            if !installed.is_empty() && !version_from_api.is_empty() && version_from_api != installed {
                return Ok(true);
            }
        }

        Ok(false)
    }

    pub fn get_info(&self, key: &str) -> Result<Option<String>> {
        let info = self.load_game_info()?;
        match key {
            "version" => Ok(info.version),
            "show_fps" => Ok(info.show_fps.map(|b| b.to_string())),
            "use_gamemode" => Ok(info.use_gamemode.map(|b| b.to_string())),
            "use_mangohud" => Ok(info.use_mangohud.map(|b| b.to_string())),
            "variable" => Ok(info.variable),
            "command" => Ok(info.command),
            "custom_wine" => Ok(info.custom_wine),
            "hidden" => Ok(info.hidden.map(|b| b.to_string())),
            _ => Ok(None),
        }
    }

    pub fn set_info(&self, key: &str, value: &str) -> Result<()> {
        let mut info = self.load_game_info()?;
        match key {
            "version" => info.version = Some(value.to_string()),
            "show_fps" => info.show_fps = value.parse().ok(),
            "use_gamemode" => info.use_gamemode = value.parse().ok(),
            "use_mangohud" => info.use_mangohud = value.parse().ok(),
            "variable" => info.variable = Some(value.to_string()),
            "command" => info.command = Some(value.to_string()),
            "custom_wine" => info.custom_wine = Some(value.to_string()),
            "hidden" => info.hidden = value.parse().ok(),
            _ => {}
        }
        self.save_game_info(&info)
    }

    pub fn set_install_dir(&mut self, install_dir: &str) {
        if self.install_dir.is_empty() {
            self.install_dir = PathBuf::from(install_dir)
                .join(self.get_install_directory_name())
                .to_string_lossy()
                .to_string();
        }
    }
}

#[flutter_rust_bridge::frb(ignore)]
impl PartialEq for Game {
    fn eq(&self, other: &Self) -> bool {
        if self.id > 0 && other.id > 0 {
            return self.id == other.id;
        }
        if self.name == other.name {
            return true;
        }
        if self.get_stripped_name().to_lowercase() == other.get_stripped_name().to_lowercase() {
            return true;
        }
        false
    }
}

#[flutter_rust_bridge::frb(ignore)]
impl Eq for Game {}

#[flutter_rust_bridge::frb(ignore)]
impl PartialOrd for Game {
    fn partial_cmp(&self, other: &Self) -> Option<std::cmp::Ordering> {
        Some(self.cmp(other))
    }
}

#[flutter_rust_bridge::frb(ignore)]
impl Ord for Game {
    fn cmp(&self, other: &Self) -> std::cmp::Ordering {
        if self.is_installed() != other.is_installed() {
            if self.is_installed() {
                return std::cmp::Ordering::Less;
            } else {
                return std::cmp::Ordering::Greater;
            }
        }
        self.name.cmp(&other.name)
    }
}
