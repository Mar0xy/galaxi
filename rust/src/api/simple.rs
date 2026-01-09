// Main public API for Flutter
// This module provides the bridge between Flutter and Rust
// Uses DTOs (Data Transfer Objects) to avoid opaque/non-opaque conflicts

use super::account::{fetch_user_avatar, Account as InternalAccount};
use super::config::Config as InternalConfig;
use super::database::{self, accounts_db, games_db};
use super::download::DownloadManager;
use super::dto::{
    GameDto, AccountDto, UserDataDto, DownloadProgressDto, 
    GameInfoDto, GamesDbInfoDto, LaunchResultDto, ConfigDto,
};
use super::error::{MinigalaxyError, Result};
use super::game::Game;
use super::gog_api::GogApi;
use super::installer::{GameInstaller, WineOptions};
use super::launcher::{self, WineLaunchOptions};
use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::Arc;
use tokio::sync::Mutex;

/// URL-decode a filename to handle %XX encoded characters
fn decode_url_filename(filename: &str) -> String {
    urlencoding::decode(filename)
        .map(|s| s.into_owned())
        .unwrap_or_else(|_| filename.to_string())
}

/// Application state (internal, not exposed to Flutter)
struct AppState {
    config: Arc<Mutex<InternalConfig>>,
    api: Arc<Mutex<Option<GogApi>>>,
    download_manager: Arc<Mutex<DownloadManager>>,
    // Cache of games by ID for internal lookups
    games_cache: Arc<Mutex<HashMap<i64, Game>>>,
    #[allow(dead_code)]
    db_initialized: Arc<Mutex<bool>>,
}

impl AppState {
    fn new() -> Self {
        // Initialize database first
        let db_init = database::init_database().is_ok();
        
        // Load config from database if available, otherwise use defaults
        let config = if db_init {
            InternalConfig::load_from_db().unwrap_or_default()
        } else {
            InternalConfig::load().unwrap_or_default()
        };
        
        AppState {
            config: Arc::new(Mutex::new(config)),
            api: Arc::new(Mutex::new(None)),
            download_manager: Arc::new(Mutex::new(DownloadManager::new())),
            games_cache: Arc::new(Mutex::new(HashMap::new())),
            db_initialized: Arc::new(Mutex::new(db_init)),
        }
    }
}

lazy_static::lazy_static! {
    static ref APP_STATE: AppState = AppState::new();
}

// ============================================================================
// Simple API functions for Flutter Rust Bridge
// ============================================================================

#[flutter_rust_bridge::frb(sync)]
pub fn greet(name: String) -> String {
    format!("Hello, {name}!")
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}

// ============================================================================
// Authentication API
// ============================================================================

#[flutter_rust_bridge::frb(sync)]
pub fn get_login_url() -> String {
    GogApi::get_login_url()
}

#[flutter_rust_bridge::frb(sync)]
pub fn get_redirect_url() -> String {
    GogApi::get_redirect_url().to_string()
}

#[flutter_rust_bridge::frb(sync)]
pub fn get_success_url() -> String {
    GogApi::get_success_url().to_string()
}

pub async fn authenticate(login_code: Option<String>, refresh_token: Option<String>) -> Result<String> {
    let config = APP_STATE.config.lock().await.clone();
    let mut api = GogApi::new(config);
    
    let new_refresh_token = api.authenticate(
        login_code.as_deref(),
        refresh_token.as_deref()
    ).await?;
    
    *APP_STATE.api.lock().await = Some(api);
    
    let mut config = APP_STATE.config.lock().await;
    config.refresh_token = new_refresh_token.clone();
    config.save()?;
    
    Ok(new_refresh_token)
}

/// Login with an authorization code from the OAuth redirect
pub async fn login_with_code(code: String) -> Result<AccountDto> {
    // Authenticate using the code
    let refresh_token = authenticate(Some(code), None).await?;
    
    // Get user info and add account
    let account = add_current_account(refresh_token).await?;
    
    Ok(account)
}

pub async fn is_logged_in() -> bool {
    APP_STATE.api.lock().await.is_some()
}

pub async fn logout() -> Result<()> {
    *APP_STATE.api.lock().await = None;
    
    let mut config = APP_STATE.config.lock().await;
    config.refresh_token = String::new();
    config.username = String::new();
    config.save()?;
    
    Ok(())
}

pub async fn get_user_data() -> Result<UserDataDto> {
    let api_guard = APP_STATE.api.lock().await;
    let api = api_guard.as_ref()
        .ok_or_else(|| MinigalaxyError::AuthError("Not authenticated".to_string()))?;
    
    let user_data = api.get_user_info().await?;
    Ok(UserDataDto::from(user_data))
}

// ============================================================================
// Account Management API
// ============================================================================

pub async fn get_all_accounts() -> Result<Vec<AccountDto>> {
    let accounts = accounts_db::get_all_accounts()?;
    Ok(accounts.iter().map(AccountDto::from).collect())
}

pub async fn get_active_account() -> Result<Option<AccountDto>> {
    Ok(accounts_db::get_active_account()?.map(AccountDto::from))
}

pub async fn add_current_account(refresh_token: String) -> Result<AccountDto> {
    let api_guard = APP_STATE.api.lock().await;
    let api = api_guard.as_ref()
        .ok_or_else(|| MinigalaxyError::AuthError("Not authenticated".to_string()))?;
    
    let user_data = api.get_user_info().await?;
    let avatar = fetch_user_avatar(api, &user_data.user_id).await.ok().flatten();
    drop(api_guard);
    
    let account = InternalAccount {
        user_id: user_data.user_id.clone(),
        username: user_data.username.clone(),
        email: user_data.email,
        avatar_url: avatar,
        refresh_token,
        added_at: chrono::Utc::now().to_rfc3339(),
        last_login: Some(chrono::Utc::now().to_rfc3339()),
    };
    
    // Save to database
    accounts_db::save_account(&account)?;
    
    // Set as active account
    accounts_db::set_active_account(&account.user_id)?;
    
    // Update config with active_account_id and username
    {
        let mut config = APP_STATE.config.lock().await;
        config.active_account_id = Some(account.user_id.clone());
        config.username = account.username.clone();
        config.save()?;
    }
    
    Ok(AccountDto::from(account))
}

pub async fn switch_account(user_id: String) -> Result<bool> {
    let accounts = accounts_db::get_all_accounts()?;
    
    if let Some(account) = accounts.iter().find(|a| a.user_id == user_id) {
        let refresh_token = account.refresh_token.clone();
        
        authenticate(None, Some(refresh_token)).await?;
        accounts_db::set_active_account(&user_id)?;
        
        Ok(true)
    } else {
        Ok(false)
    }
}

pub async fn remove_account(user_id: String) -> Result<()> {
    accounts_db::remove_account(&user_id)
}

// ============================================================================
// Library API
// ============================================================================

pub async fn get_library() -> Result<Vec<GameDto>> {
    let api_guard = APP_STATE.api.lock().await;
    let api = api_guard.as_ref()
        .ok_or_else(|| MinigalaxyError::AuthError("Not authenticated".to_string()))?;
    
    let games = api.get_library().await?;
    
    // Cache the games for later lookups (in memory and database)
    let mut cache = APP_STATE.games_cache.lock().await;
    for game in &games {
        cache.insert(game.id, game.clone());
        // Also save to database for persistence
        let _ = games_db::save_game(game);
    }
    
    Ok(games.into_iter().map(GameDto::from).collect())
}

pub async fn get_game_info(game_id: i64) -> Result<GameInfoDto> {
    let api_guard = APP_STATE.api.lock().await;
    let api = api_guard.as_ref()
        .ok_or_else(|| MinigalaxyError::AuthError("Not authenticated".to_string()))?;
    
    let cache = APP_STATE.games_cache.lock().await;
    let game = cache.get(&game_id)
        .ok_or_else(|| MinigalaxyError::NotFoundError("Game not found in cache".to_string()))?;
    
    let info = api.get_info(game).await?;
    Ok(GameInfoDto::from(info))
}

pub async fn get_gamesdb_info(game_id: i64) -> Result<GamesDbInfoDto> {
    let api_guard = APP_STATE.api.lock().await;
    let api = api_guard.as_ref()
        .ok_or_else(|| MinigalaxyError::AuthError("Not authenticated".to_string()))?;
    
    let cache = APP_STATE.games_cache.lock().await;
    let game = cache.get(&game_id)
        .ok_or_else(|| MinigalaxyError::NotFoundError("Game not found in cache".to_string()))?;
    
    let info = api.get_gamesdb_info(game).await?;
    Ok(GamesDbInfoDto::from(info))
}

pub async fn get_game_version(game_id: i64) -> Result<String> {
    let api_guard = APP_STATE.api.lock().await;
    let api = api_guard.as_ref()
        .ok_or_else(|| MinigalaxyError::AuthError("Not authenticated".to_string()))?;
    
    let cache = APP_STATE.games_cache.lock().await;
    let game = cache.get(&game_id)
        .ok_or_else(|| MinigalaxyError::NotFoundError("Game not found in cache".to_string()))?;
    
    api.get_version(game).await
}

pub async fn check_for_update(game_id: i64) -> Result<bool> {
    let version = get_game_version(game_id).await?;
    
    let cache = APP_STATE.games_cache.lock().await;
    let game = cache.get(&game_id)
        .ok_or_else(|| MinigalaxyError::NotFoundError("Game not found in cache".to_string()))?;
    
    game.is_update_available(&version, None)
}

// ============================================================================
// Download API
// ============================================================================

/// Extract and decode a filename from a URL
fn extract_filename_from_url(url: &str) -> String {
    let raw_name = url.split('/').last()
        .and_then(|s| s.split('?').next())
        .unwrap_or("installer");
    decode_url_filename(raw_name)
}

pub async fn start_download(game_id: i64) -> Result<String> {
    let api_guard = APP_STATE.api.lock().await;
    let api = api_guard.as_ref()
        .ok_or_else(|| MinigalaxyError::AuthError("Not authenticated".to_string()))?;
    
    let cache = APP_STATE.games_cache.lock().await;
    let game = cache.get(&game_id)
        .ok_or_else(|| MinigalaxyError::NotFoundError("Game not found in cache".to_string()))?
        .clone();
    drop(cache);
    
    let download_info = api.get_download_info(&game, &game.platform).await?;
    
    let config = APP_STATE.config.lock().await.clone();
    
    // Create the downloads directory if it doesn't exist
    let downloads_dir = PathBuf::from(&config.install_dir).join(".downloads");
    std::fs::create_dir_all(&downloads_dir)?;
    
    // Pre-compute installer paths for all files (using decoded filenames)
    let mut installer_paths: Vec<PathBuf> = Vec::new();
    let mut download_links: Vec<String> = Vec::new();
    let mut needs_download: Vec<bool> = Vec::new();
    
    for file in &download_info.files {
        let real_link = api.get_real_download_link(&file.downlink).await?;
        let file_name = extract_filename_from_url(&real_link);
        let save_path = downloads_dir.join(&file_name);
        
        // Check if installer already exists (skip download if already downloaded)
        let already_downloaded = save_path.exists();
        
        installer_paths.push(save_path);
        download_links.push(real_link);
        needs_download.push(!already_downloaded);
    }
    
    // Return the first installer path for installation
    let installer_path = installer_paths.first()
        .map(|p| p.to_string_lossy().to_string())
        .unwrap_or_default();
    
    // Check if all files are already downloaded
    let all_downloaded = needs_download.iter().all(|&n| !n);
    
    if all_downloaded {
        // All files already downloaded, just return the path
        return Ok(installer_path);
    }
    
    // Spawn download in background task so we can return immediately and let UI poll for progress
    let download_manager = APP_STATE.download_manager.clone();
    
    // Drop the guard before spawning so we don't hold the lock
    drop(api_guard);
    
    // Clone paths for spawned task
    let paths = installer_paths.clone();
    let links = download_links.clone();
    
    tokio::spawn(async move {
        for (idx, real_link) in links.into_iter().enumerate() {
            // Skip if already downloaded
            if !needs_download.get(idx).copied().unwrap_or(true) {
                continue;
            }
            
            let save_path = paths.get(idx).cloned().unwrap_or_else(|| {
                PathBuf::from(".downloads").join(extract_filename_from_url(&real_link))
            });
            
            // Get the download manager, then drop the lock before starting the download
            // This allows progress polling to work while download is in progress
            let dm = download_manager.lock().await;
            // Clone the active_downloads Arc so we can track progress without holding the manager lock
            let active_downloads = dm.get_active_downloads_arc();
            drop(dm);
            
            // Create a temporary download manager with shared active_downloads
            // resume=true will check for .part files and resume from there
            let temp_dm = DownloadManager::with_shared_downloads(active_downloads);
            let _ = temp_dm.download_file(&real_link, &save_path, game_id, true).await;
        }
    });
    
    Ok(installer_path)
}

/// Download and install a game in one operation
pub async fn download_and_install(game_id: i64) -> Result<GameDto> {
    // Start the download
    let installer_path = start_download(game_id).await?;
    
    // Wait for download to complete by polling
    loop {
        let progress = get_download_progress(game_id).await?;
        match progress {
            Some(p) if p.status == "Completed" => break,
            Some(p) if p.status == "Failed" => {
                return Err(MinigalaxyError::DownloadError("Download failed".to_string()));
            }
            Some(p) if p.status == "Cancelled" => {
                return Err(MinigalaxyError::DownloadError("Download cancelled".to_string()));
            }
            Some(_) => {
                tokio::time::sleep(tokio::time::Duration::from_millis(500)).await;
            }
            None => break, // Download finished or never started
        }
    }
    
    // Install the game
    let game = install_game(game_id, installer_path).await?;
    
    // Clean up installer if not keeping them
    let config = APP_STATE.config.lock().await;
    if !config.keep_installers {
        // Delete the installer
        let installer = std::path::PathBuf::from(&game.install_dir)
            .parent()
            .map(|p| p.join(".downloads"));
        if let Some(downloads_dir) = installer {
            let _ = std::fs::remove_dir_all(&downloads_dir);
        }
    }
    
    Ok(game)
}

pub async fn pause_download(game_id: i64) -> Result<()> {
    let download_manager = APP_STATE.download_manager.lock().await;
    download_manager.pause_download(game_id).await;
    Ok(())
}

pub async fn cancel_download(game_id: i64) -> Result<()> {
    let download_manager = APP_STATE.download_manager.lock().await;
    download_manager.cancel_download(game_id).await;
    Ok(())
}

pub async fn get_download_progress(game_id: i64) -> Result<Option<DownloadProgressDto>> {
    let download_manager = APP_STATE.download_manager.lock().await;
    // Clone the active_downloads Arc so we can query it without holding the manager lock
    let active_downloads = download_manager.get_active_downloads_arc();
    drop(download_manager);
    
    let downloads = active_downloads.lock().await;
    Ok(downloads.get(&game_id).map(|p| DownloadProgressDto::from(p)))
}

pub async fn get_active_downloads() -> Result<Vec<DownloadProgressDto>> {
    let download_manager = APP_STATE.download_manager.lock().await;
    // Clone the active_downloads Arc so we can query it without holding the manager lock
    let active_downloads = download_manager.get_active_downloads_arc();
    drop(download_manager);
    
    let downloads = active_downloads.lock().await;
    Ok(downloads.values().map(DownloadProgressDto::from).collect())
}

// ============================================================================
// Installation API
// ============================================================================

pub async fn install_game(game_id: i64, installer_path: String) -> Result<GameDto> {
    let installer = PathBuf::from(&installer_path);
    
    // Verify installer exists - try to get canonical path
    let installer = if installer.exists() {
        installer.canonicalize().unwrap_or(installer)
    } else {
        // Try with the raw path
        if !installer.exists() {
            // List files in the downloads directory to help debug
            if let Some(parent) = installer.parent() {
                if parent.exists() {
                    let files: Vec<String> = std::fs::read_dir(parent)
                        .ok()
                        .map(|entries| {
                            entries
                                .filter_map(|e| e.ok())
                                .map(|e| e.file_name().to_string_lossy().to_string())
                                .collect()
                        })
                        .unwrap_or_default();
                    
                    return Err(MinigalaxyError::InstallError(format!(
                        "Installer file not found: '{}'. Files in directory: {:?}",
                        installer_path,
                        files
                    )));
                }
            }
            return Err(MinigalaxyError::InstallError(format!(
                "Installer file not found: {}",
                installer_path
            )));
        }
        installer
    };
    
    let mut cache = APP_STATE.games_cache.lock().await;
    let game = cache.get_mut(&game_id)
        .ok_or_else(|| MinigalaxyError::NotFoundError("Game not found in cache".to_string()))?;
    
    let config = APP_STATE.config.lock().await.clone();
    
    // Create install directory if it doesn't exist
    std::fs::create_dir_all(&config.install_dir)?;
    
    // Build wine options from config
    let wine_options = WineOptions {
        wine_executable: if config.wine_executable.is_empty() { None } else { Some(config.wine_executable.clone()) },
        disable_ntsync: config.wine_disable_ntsync,
        auto_install_dxvk: config.wine_auto_install_dxvk,
    };
    
    GameInstaller::install_game_with_wine(game, &installer, &config.install_dir, wine_options).await?;
    
    // Update game in database
    games_db::save_game(game)?;
    
    Ok(GameDto::from(&*game))
}

pub async fn uninstall_game(game_id: i64) -> Result<()> {
    let cache = APP_STATE.games_cache.lock().await;
    let game = cache.get(&game_id)
        .ok_or_else(|| MinigalaxyError::NotFoundError("Game not found in cache".to_string()))?;
    
    GameInstaller::uninstall_game(game)
}

pub async fn install_dlc(game_id: i64, dlc_installer_path: String) -> Result<()> {
    let cache = APP_STATE.games_cache.lock().await;
    let game = cache.get(&game_id)
        .ok_or_else(|| MinigalaxyError::NotFoundError("Game not found in cache".to_string()))?;
    
    let config = APP_STATE.config.lock().await.clone();
    let wine_options = WineOptions {
        wine_executable: if config.wine_executable.is_empty() { None } else { Some(config.wine_executable.clone()) },
        disable_ntsync: config.wine_disable_ntsync,
        auto_install_dxvk: false, // Don't re-install dxvk for DLC
    };
    GameInstaller::install_dlc_with_wine(game, &PathBuf::from(dlc_installer_path), wine_options).await
}

// ============================================================================
// Launch API
// ============================================================================

pub fn launch_game(_game_id: i64) -> Result<LaunchResultDto> {
    // We need to get game from cache synchronously, but cache uses async mutex
    // For sync functions, we'll need to use a different approach
    // For now, return an error indicating this should be called via async
    Err(MinigalaxyError::LaunchError("Use launch_game_async instead".to_string()))
}

pub async fn launch_game_async(game_id: i64) -> Result<LaunchResultDto> {
    let cache = APP_STATE.games_cache.lock().await;
    let game = cache.get(&game_id)
        .ok_or_else(|| MinigalaxyError::NotFoundError("Game not found in cache".to_string()))?;
    
    let config = APP_STATE.config.lock().await.clone();
    
    // Build wine launch options from config
    let wine_options = WineLaunchOptions {
        wine_executable: if config.wine_executable.is_empty() { None } else { Some(config.wine_executable.clone()) },
        disable_ntsync: config.wine_disable_ntsync,
    };
    
    let result = launcher::start_game_with_options(game, wine_options)?;
    Ok(LaunchResultDto::from(result))
}

pub async fn open_wine_config(game_id: i64) -> Result<()> {
    let cache = APP_STATE.games_cache.lock().await;
    let game = cache.get(&game_id)
        .ok_or_else(|| MinigalaxyError::NotFoundError("Game not found in cache".to_string()))?;
    
    launcher::config_game(game)
}

pub async fn open_wine_regedit(game_id: i64) -> Result<()> {
    let cache = APP_STATE.games_cache.lock().await;
    let game = cache.get(&game_id)
        .ok_or_else(|| MinigalaxyError::NotFoundError("Game not found in cache".to_string()))?;
    
    launcher::regedit_game(game)
}

pub async fn open_winetricks(game_id: i64) -> Result<()> {
    let cache = APP_STATE.games_cache.lock().await;
    let game = cache.get(&game_id)
        .ok_or_else(|| MinigalaxyError::NotFoundError("Game not found in cache".to_string()))?;
    
    launcher::winetricks_game(game)
}

// ============================================================================
// Configuration API
// ============================================================================

pub async fn get_config() -> Result<ConfigDto> {
    let config = APP_STATE.config.lock().await;
    Ok(ConfigDto::from(&*config))
}

pub async fn get_install_dir() -> Result<String> {
    let config = APP_STATE.config.lock().await;
    Ok(config.install_dir.clone())
}

pub async fn set_install_dir(dir: String) -> Result<()> {
    let mut config = APP_STATE.config.lock().await;
    config.install_dir = dir;
    config.save()
}

pub async fn get_language() -> Result<String> {
    let config = APP_STATE.config.lock().await;
    Ok(config.lang.clone())
}

pub async fn set_language(lang: String) -> Result<()> {
    let mut config = APP_STATE.config.lock().await;
    config.lang = lang;
    config.save()
}

pub async fn get_view_mode() -> Result<String> {
    let config = APP_STATE.config.lock().await;
    Ok(config.view.clone())
}

pub async fn set_view_mode(view: String) -> Result<()> {
    let mut config = APP_STATE.config.lock().await;
    config.view = view;
    config.save()
}

pub async fn get_dark_theme() -> Result<bool> {
    let config = APP_STATE.config.lock().await;
    Ok(config.use_dark_theme)
}

pub async fn set_dark_theme(enabled: bool) -> Result<()> {
    let mut config = APP_STATE.config.lock().await;
    config.use_dark_theme = enabled;
    config.save()
}

pub async fn get_show_windows_games() -> Result<bool> {
    let config = APP_STATE.config.lock().await;
    Ok(config.show_windows_games)
}

pub async fn set_show_windows_games(enabled: bool) -> Result<()> {
    let mut config = APP_STATE.config.lock().await;
    config.show_windows_games = enabled;
    config.save()
}

pub async fn get_keep_installers() -> Result<bool> {
    let config = APP_STATE.config.lock().await;
    Ok(config.keep_installers)
}

pub async fn set_keep_installers(enabled: bool) -> Result<()> {
    let mut config = APP_STATE.config.lock().await;
    config.keep_installers = enabled;
    config.save()
}

// ============================================================================
// Wine Configuration API
// ============================================================================

pub async fn get_wine_prefix() -> Result<String> {
    let config = APP_STATE.config.lock().await;
    Ok(config.wine_prefix.clone())
}

pub async fn set_wine_prefix(prefix: String) -> Result<()> {
    let mut config = APP_STATE.config.lock().await;
    config.wine_prefix = prefix;
    config.save()
}

pub async fn get_wine_executable() -> Result<String> {
    let config = APP_STATE.config.lock().await;
    Ok(config.wine_executable.clone())
}

pub async fn set_wine_executable(executable: String) -> Result<()> {
    let mut config = APP_STATE.config.lock().await;
    config.wine_executable = executable;
    config.save()
}

pub async fn get_wine_debug() -> Result<bool> {
    let config = APP_STATE.config.lock().await;
    Ok(config.wine_debug)
}

pub async fn set_wine_debug(enabled: bool) -> Result<()> {
    let mut config = APP_STATE.config.lock().await;
    config.wine_debug = enabled;
    config.save()
}

pub async fn get_wine_disable_ntsync() -> Result<bool> {
    let config = APP_STATE.config.lock().await;
    Ok(config.wine_disable_ntsync)
}

pub async fn set_wine_disable_ntsync(enabled: bool) -> Result<()> {
    let mut config = APP_STATE.config.lock().await;
    config.wine_disable_ntsync = enabled;
    config.save()
}

pub async fn get_wine_auto_install_dxvk() -> Result<bool> {
    let config = APP_STATE.config.lock().await;
    Ok(config.wine_auto_install_dxvk)
}

pub async fn set_wine_auto_install_dxvk(enabled: bool) -> Result<()> {
    let mut config = APP_STATE.config.lock().await;
    config.wine_auto_install_dxvk = enabled;
    config.save()
}

pub async fn open_wine_config_global() -> Result<()> {
    let config = APP_STATE.config.lock().await;
    let wine_exe = if config.wine_executable.is_empty() {
        "wine".to_string()
    } else {
        config.wine_executable.clone()
    };
    
    let mut cmd = std::process::Command::new(&wine_exe);
    cmd.arg("winecfg");
    
    if !config.wine_prefix.is_empty() {
        cmd.env("WINEPREFIX", &config.wine_prefix);
    }
    
    cmd.spawn()
        .map_err(|e| super::error::MinigalaxyError::LaunchError(format!("Failed to open winecfg: {}", e)))?;
    
    Ok(())
}

pub async fn open_winetricks_global() -> Result<()> {
    let config = APP_STATE.config.lock().await;
    
    let mut cmd = std::process::Command::new("winetricks");
    
    if !config.wine_prefix.is_empty() {
        cmd.env("WINEPREFIX", &config.wine_prefix);
    }
    
    cmd.spawn()
        .map_err(|e| super::error::MinigalaxyError::LaunchError(format!("Failed to open winetricks: {}", e)))?;
    
    Ok(())
}

// ============================================================================
// Utility API
// ============================================================================

pub async fn can_connect() -> Result<bool> {
    let api_guard = APP_STATE.api.lock().await;
    if let Some(api) = api_guard.as_ref() {
        Ok(api.can_connect().await)
    } else {
        let config = APP_STATE.config.lock().await.clone();
        let api = GogApi::new(config);
        Ok(api.can_connect().await)
    }
}

#[flutter_rust_bridge::frb(sync)]
pub fn get_supported_languages() -> Vec<(String, String)> {
    super::config::SUPPORTED_DOWNLOAD_LANGUAGES
        .iter()
        .map(|(code, name)| (code.to_string(), name.to_string()))
        .collect()
}

#[flutter_rust_bridge::frb(sync)]
pub fn get_supported_locales() -> Vec<(String, String)> {
    super::config::SUPPORTED_LOCALES
        .iter()
        .map(|(code, name)| (code.to_string(), name.to_string()))
        .collect()
}

#[flutter_rust_bridge::frb(sync)]
pub fn get_view_modes() -> Vec<(String, String)> {
    super::config::VIEWS
        .iter()
        .map(|(code, name)| (code.to_string(), name.to_string()))
        .collect()
}
