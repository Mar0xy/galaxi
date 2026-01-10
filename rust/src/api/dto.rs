// Data Transfer Objects for Flutter API
// These are pure data structs without impl blocks to avoid FRB opaque/non-opaque conflicts

use serde::{Deserialize, Serialize};

/// Game data for Flutter UI
#[flutter_rust_bridge::frb(non_opaque)]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GameDto {
    pub id: i64,
    pub name: String,
    pub url: String,
    pub install_dir: String,
    pub image_url: String,
    pub platform: String,
    pub category: String,
    pub dlcs: Vec<DlcDto>,
}

/// DLC data for Flutter UI
#[flutter_rust_bridge::frb(non_opaque)]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DlcDto {
    pub id: i64,
    pub name: String,
    pub title: String,
    pub image_url: String,
}

/// Account data for Flutter UI
#[flutter_rust_bridge::frb(non_opaque)]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AccountDto {
    pub user_id: String,
    pub username: String,
    pub refresh_token: String,
    pub avatar_url: Option<String>,
}

/// User data from GOG
#[flutter_rust_bridge::frb(non_opaque)]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UserDataDto {
    pub user_id: String,
    pub username: String,
    pub email: Option<String>,
}

/// User profile with avatar
#[flutter_rust_bridge::frb(non_opaque)]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UserProfileDto {
    pub user_id: String,
    pub username: String,
    pub avatar_url: Option<String>,
}

/// Download progress for Flutter UI
#[flutter_rust_bridge::frb(non_opaque)]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DownloadProgressDto {
    pub game_id: i64,
    pub game_name: String,
    pub downloaded_bytes: u64,
    pub total_bytes: u64,
    pub speed_bytes_per_sec: u64,
    pub status: String,
}

/// Game info response
#[flutter_rust_bridge::frb(non_opaque)]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GameInfoDto {
    pub id: i64,
    pub title: String,
    pub description: Option<String>,
    pub changelog: Option<String>,
    pub screenshots: Vec<String>,
}

/// Games DB info (covers, backgrounds, etc)
#[flutter_rust_bridge::frb(non_opaque)]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GamesDbInfoDto {
    pub cover: String,
    pub vertical_cover: String,
    pub background: String,
    pub summary: String,
    pub genre: String,
}

/// Launch result
#[flutter_rust_bridge::frb(non_opaque)]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LaunchResultDto {
    pub success: bool,
    pub error_message: Option<String>,
    pub pid: Option<u32>,
}

/// Config settings for Flutter UI
#[flutter_rust_bridge::frb(non_opaque)]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ConfigDto {
    pub locale: String,
    pub lang: String,
    pub view: String,
    pub install_dir: String,
    pub keep_installers: bool,
    pub stay_logged_in: bool,
    pub use_dark_theme: bool,
    pub show_hidden_games: bool,
    pub show_windows_games: bool,
    pub wine_prefix: String,
    pub wine_executable: String,
    pub wine_debug: bool,
    pub wine_disable_ntsync: bool,
    pub wine_auto_install_dxvk: bool,
}

// Conversion implementations
use super::game::{Game, Dlc};
use super::account::Account;
use super::gog_api::{UserData, UserProfile, GamesDbInfo, GameInfoResponse};
use super::download::DownloadProgress;
use super::launcher::LaunchResult;
use super::config::Config;

impl From<&Game> for GameDto {
    fn from(game: &Game) -> Self {
        GameDto {
            id: game.id,
            name: game.name.clone(),
            url: game.url.clone(),
            install_dir: game.install_dir.clone(),
            image_url: game.image_url.clone(),
            platform: game.platform.clone(),
            category: game.category.clone(),
            dlcs: game.dlcs.iter().map(DlcDto::from).collect(),
        }
    }
}

impl From<Game> for GameDto {
    fn from(game: Game) -> Self {
        GameDto::from(&game)
    }
}

impl From<&Dlc> for DlcDto {
    fn from(dlc: &Dlc) -> Self {
        DlcDto {
            id: dlc.id,
            name: dlc.name.clone(),
            title: dlc.title.clone(),
            image_url: dlc.image_url.clone(),
        }
    }
}

impl From<&Account> for AccountDto {
    fn from(account: &Account) -> Self {
        AccountDto {
            user_id: account.user_id.clone(),
            username: account.username.clone(),
            refresh_token: account.refresh_token.clone(),
            avatar_url: account.avatar_url.clone(),
        }
    }
}

impl From<Account> for AccountDto {
    fn from(account: Account) -> Self {
        AccountDto::from(&account)
    }
}

impl From<&UserData> for UserDataDto {
    fn from(data: &UserData) -> Self {
        UserDataDto {
            user_id: data.user_id.clone(),
            username: data.username.clone(),
            email: data.email.clone(),
        }
    }
}

impl From<UserData> for UserDataDto {
    fn from(data: UserData) -> Self {
        UserDataDto::from(&data)
    }
}

impl From<&UserProfile> for UserProfileDto {
    fn from(profile: &UserProfile) -> Self {
        UserProfileDto {
            user_id: profile.id.clone(),
            username: profile.username.clone(),
            avatar_url: profile.avatars.as_ref().and_then(|a| a.medium.clone()),
        }
    }
}

impl From<UserProfile> for UserProfileDto {
    fn from(profile: UserProfile) -> Self {
        UserProfileDto::from(&profile)
    }
}

impl From<&DownloadProgress> for DownloadProgressDto {
    fn from(progress: &DownloadProgress) -> Self {
        DownloadProgressDto {
            game_id: progress.game_id,
            game_name: progress.file_name.clone(),
            downloaded_bytes: progress.downloaded,
            total_bytes: progress.total,
            speed_bytes_per_sec: 0, // Not tracked in original struct
            status: format!("{:?}", progress.status),
        }
    }
}

impl From<&GameInfoResponse> for GameInfoDto {
    fn from(info: &GameInfoResponse) -> Self {
        // Convert screenshots to URLs
        let screenshots: Vec<String> = info.screenshots.as_ref()
            .map(|ss| ss.iter().map(|s| {
                // GOG screenshots use formatter_template_url like "https://images.gog-statics.com/{image_id}_{formatter}.jpg"
                // Common formatters: 1600 (large), 800 (medium), 200 (thumbnail)
                s.formatter_template_url.replace("{formatter}", "product_card_v2_mobile_slider_639")
            }).collect())
            .unwrap_or_default();
        
        GameInfoDto {
            id: info.id,
            title: info.title.clone(),
            description: info.description.as_ref().and_then(|d| d.full.clone()),
            changelog: info.changelog.clone(),
            screenshots,
        }
    }
}

impl From<GameInfoResponse> for GameInfoDto {
    fn from(info: GameInfoResponse) -> Self {
        GameInfoDto::from(&info)
    }
}

impl From<&GamesDbInfo> for GamesDbInfoDto {
    fn from(info: &GamesDbInfo) -> Self {
        GamesDbInfoDto {
            cover: info.cover.clone(),
            vertical_cover: info.vertical_cover.clone(),
            background: info.background.clone(),
            summary: info.summary.get("*").cloned().unwrap_or_default(),
            genre: info.genre.get("*").cloned().unwrap_or_default(),
        }
    }
}

impl From<GamesDbInfo> for GamesDbInfoDto {
    fn from(info: GamesDbInfo) -> Self {
        GamesDbInfoDto::from(&info)
    }
}

impl From<&LaunchResult> for LaunchResultDto {
    fn from(result: &LaunchResult) -> Self {
        LaunchResultDto {
            success: result.success,
            error_message: result.error_message.clone(),
            pid: result.pid,
        }
    }
}

impl From<LaunchResult> for LaunchResultDto {
    fn from(result: LaunchResult) -> Self {
        LaunchResultDto::from(&result)
    }
}

impl From<&Config> for ConfigDto {
    fn from(config: &Config) -> Self {
        ConfigDto {
            locale: config.locale.clone(),
            lang: config.lang.clone(),
            view: config.view.clone(),
            install_dir: config.install_dir.clone(),
            keep_installers: config.keep_installers,
            stay_logged_in: config.stay_logged_in,
            use_dark_theme: config.use_dark_theme,
            show_hidden_games: config.show_hidden_games,
            show_windows_games: config.show_windows_games,
            wine_prefix: config.wine_prefix.clone(),
            wine_executable: config.wine_executable.clone(),
            wine_debug: config.wine_debug,
            wine_disable_ntsync: config.wine_disable_ntsync,
            wine_auto_install_dxvk: config.wine_auto_install_dxvk,
        }
    }
}

impl From<Config> for ConfigDto {
    fn from(config: Config) -> Self {
        ConfigDto::from(&config)
    }
}
