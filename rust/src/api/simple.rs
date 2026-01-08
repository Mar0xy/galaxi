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
use super::installer::GameInstaller;
use super::launcher;
use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::Arc;
use tokio::sync::Mutex;

/// Application state (internal, not exposed to Flutter)
struct AppState {
    config: Arc<Mutex<InternalConfig>>,
    api: Arc<Mutex<Option<GogApi>>>,
    download_manager: Arc<Mutex<DownloadManager>>,
    // Cache of games by ID for internal lookups
    games_cache: Arc<Mutex<HashMap<i64, Game>>>,
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
    
    // Set as active if no active account exists
    if accounts_db::get_active_account()?.is_none() {
        accounts_db::set_active_account(&account.user_id)?;
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

pub async fn start_download(game_id: i64) -> Result<()> {
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
    let download_manager = APP_STATE.download_manager.lock().await;
    
    for file in download_info.files {
        let real_link = api.get_real_download_link(&file.downlink).await?;
        let file_name = real_link.split('/').last().unwrap_or("installer");
        let save_path = PathBuf::from(&config.install_dir)
            .join(".downloads")
            .join(file_name);
        
        download_manager.download_file(&real_link, &save_path, game.id, true).await?;
    }
    
    Ok(())
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
    Ok(download_manager.get_progress(game_id).await.map(|p| DownloadProgressDto::from(&p)))
}

pub async fn get_active_downloads() -> Result<Vec<DownloadProgressDto>> {
    let download_manager = APP_STATE.download_manager.lock().await;
    Ok(download_manager.get_active_downloads().await.iter().map(DownloadProgressDto::from).collect())
}

// ============================================================================
// Installation API
// ============================================================================

pub async fn install_game(game_id: i64, installer_path: String) -> Result<GameDto> {
    let mut cache = APP_STATE.games_cache.lock().await;
    let game = cache.get_mut(&game_id)
        .ok_or_else(|| MinigalaxyError::NotFoundError("Game not found in cache".to_string()))?;
    
    let config = APP_STATE.config.lock().await.clone();
    GameInstaller::install_game(game, &PathBuf::from(installer_path), &config.install_dir).await?;
    
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
    
    GameInstaller::install_dlc(game, &PathBuf::from(dlc_installer_path)).await
}

// ============================================================================
// Launch API
// ============================================================================

pub fn launch_game(game_id: i64) -> Result<LaunchResultDto> {
    // We need to get game from cache synchronously, but cache uses async mutex
    // For sync functions, we'll need to use a different approach
    // For now, return an error indicating this should be called via async
    Err(MinigalaxyError::LaunchError("Use launch_game_async instead".to_string()))
}

pub async fn launch_game_async(game_id: i64) -> Result<LaunchResultDto> {
    let cache = APP_STATE.games_cache.lock().await;
    let game = cache.get(&game_id)
        .ok_or_else(|| MinigalaxyError::NotFoundError("Game not found in cache".to_string()))?;
    
    let result = launcher::start_game(game)?;
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
