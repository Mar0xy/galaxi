use std::fs;
use std::path::PathBuf;
use std::process::Command;
use super::error::{GalaxiError, Result};
use super::game::Game;

/// Wine installation options
#[flutter_rust_bridge::frb(ignore)]
#[derive(Debug, Clone, Default)]
pub struct WineOptions {
    pub wine_executable: Option<String>,
    pub disable_ntsync: bool,
    pub auto_install_dxvk: bool,
}

/// Installer for managing game installations
#[flutter_rust_bridge::frb(opaque)]
pub struct GameInstaller;

#[flutter_rust_bridge::frb(ignore)]
impl GameInstaller {
    pub async fn install_game(
        game: &mut Game,
        installer_path: &PathBuf,
        install_dir: &str,
    ) -> Result<()> {
        Self::install_game_with_wine(game, installer_path, install_dir, WineOptions::default()).await
    }
    
    pub async fn install_game_with_wine(
        game: &mut Game,
        installer_path: &PathBuf,
        install_dir: &str,
        wine_options: WineOptions,
    ) -> Result<()> {
        let install_path = PathBuf::from(install_dir).join(game.get_install_directory_name());
        
        fs::create_dir_all(&install_path)?;
        
        let file_name = installer_path
            .file_name()
            .map(|s| s.to_string_lossy().to_string())
            .unwrap_or_default();

        if file_name.ends_with(".sh") {
            Self::install_linux_game(installer_path, &install_path)?;
        } else if file_name.ends_with(".exe") {
            Self::install_windows_game(installer_path, &install_path, game, &wine_options)?;
        } else {
            return Err(GalaxiError::InstallError(
                format!("Unknown installer format: {}", file_name)
            ));
        }

        game.install_dir = install_path.to_string_lossy().to_string();
        
        Ok(())
    }

    fn install_linux_game(installer_path: &PathBuf, install_path: &PathBuf) -> Result<()> {
        Command::new("chmod")
            .arg("+x")
            .arg(installer_path)
            .output()
            .map_err(|e| GalaxiError::InstallError(e.to_string()))?;

        let output = Command::new(installer_path)
            .arg("--")
            .arg("--noreadme")
            .arg("--nooptions")
            .arg("--noprompt")
            .arg("--destination")
            .arg(install_path)
            .output()
            .map_err(|e| GalaxiError::InstallError(e.to_string()))?;

        if !output.status.success() {
            return Err(GalaxiError::InstallError(
                String::from_utf8_lossy(&output.stderr).to_string()
            ));
        }

        Ok(())
    }

    fn install_windows_game(
        installer_path: &PathBuf,
        install_path: &PathBuf,
        game: &Game,
        wine_options: &WineOptions,
    ) -> Result<()> {
        // Verify installer file exists first
        if !installer_path.exists() {
            return Err(GalaxiError::InstallError(format!(
                "Installer file not found: {}",
                installer_path.display()
            )));
        }
        
        // Per-game Wine prefix is stored inside the game's install directory
        // DO NOT create the prefix directory here - let Wine initialize it properly
        let prefix_path = install_path.join("wine_prefix");

        // Get Wine executable: per-game setting > global setting > default "wine"
        let wine_path = game.get_info("custom_wine")
            .ok()
            .flatten()
            .or_else(|| wine_options.wine_executable.as_ref().filter(|s| !s.is_empty()).cloned())
            .unwrap_or_else(|| "wine".to_string());

        // Check if Wine is available - support both absolute paths and PATH lookup
        let wine_exists = if wine_path.contains('/') {
            // Absolute or relative path - check if file exists and is executable
            let wine_file = std::path::Path::new(&wine_path);
            wine_file.exists()
        } else {
            // Just a command name - use which to find it in PATH
            Command::new("which")
                .arg(&wine_path)
                .output()
                .map(|o| o.status.success())
                .unwrap_or(false)
        };
        
        if !wine_exists {
            return Err(GalaxiError::InstallError(format!(
                "Wine not found: '{}'. Please install Wine or set a valid custom Wine path in Settings.",
                wine_path
            )));
        }

        // If auto_install_dxvk is enabled, run winetricks to install dxvk, vkd3d, and corefonts
        if wine_options.auto_install_dxvk {
            Self::setup_wine_prefix(&prefix_path, &wine_path, wine_options.disable_ntsync)?;
        }

        // Get canonical path to installer to avoid any path resolution issues
        let canonical_installer = installer_path.canonicalize()
            .unwrap_or_else(|_| installer_path.clone());

        // Build the wine command with optional environment variables
        let mut cmd = Command::new(&wine_path);
        cmd.env("WINEPREFIX", &prefix_path);
        
        // Disable NTSYNC if requested (fixes /dev/ntsync not found errors)
        if wine_options.disable_ntsync {
            cmd.env("WINE_DISABLE_FAST_SYNC", "1");
        }
        
        cmd.arg(&canonical_installer)
            .arg("/VERYSILENT")
            .arg("/NORESTART")
            .arg("/SUPPRESSMSGBOXES")
            .arg("/DIR=c:\\game");

        let output = cmd.output();

        match output {
            Ok(o) if o.status.success() => Ok(()),
            Ok(o) => {
                // First attempt failed, try without silent flags
                let mut retry_cmd = Command::new(&wine_path);
                retry_cmd.env("WINEPREFIX", &prefix_path);
                if wine_options.disable_ntsync {
                    retry_cmd.env("WINE_DISABLE_FAST_SYNC", "1");
                }
                retry_cmd.arg(&canonical_installer);
                
                let output = retry_cmd.output()
                    .map_err(|e| GalaxiError::InstallError(format!(
                        "Wine failed to start: {}",
                        e
                    )))?;

                if !output.status.success() {
                    let stderr = String::from_utf8_lossy(&o.stderr);
                    return Err(GalaxiError::InstallError(format!(
                        "Wine installation failed: {}",
                        if stderr.is_empty() { "Unknown error" } else { &stderr }
                    )));
                }
                Ok(())
            }
            Err(e) => {
                Err(GalaxiError::InstallError(format!(
                    "Failed to run Wine: {}",
                    e
                )))
            }
        }
    }
    
    /// Download winetricks if not available and setup Wine prefix with dxvk, vkd3d, corefonts
    fn setup_wine_prefix(prefix_path: &PathBuf, wine_path: &str, disable_ntsync: bool) -> Result<()> {
        // First, initialize the Wine prefix properly using wineboot
        // This creates all the necessary directories and registry
        let mut wineboot_cmd = Command::new(wine_path.replace("wine", "wineboot"));
        wineboot_cmd.env("WINEPREFIX", prefix_path);
        
        if disable_ntsync {
            wineboot_cmd.env("WINE_DISABLE_FAST_SYNC", "1");
        }
        
        // Run wineboot --init to initialize the prefix
        wineboot_cmd.arg("--init");
        
        match wineboot_cmd.output() {
            Ok(output) if !output.status.success() => {
                // Try with just wine instead of wineboot
                let mut init_cmd = Command::new(wine_path);
                init_cmd.env("WINEPREFIX", prefix_path);
                if disable_ntsync {
                    init_cmd.env("WINE_DISABLE_FAST_SYNC", "1");
                }
                init_cmd.arg("wineboot").arg("--init");
                let _ = init_cmd.output();
            }
            Err(_) => {
                // wineboot not found, try wine wineboot
                let mut init_cmd = Command::new(wine_path);
                init_cmd.env("WINEPREFIX", prefix_path);
                if disable_ntsync {
                    init_cmd.env("WINE_DISABLE_FAST_SYNC", "1");
                }
                init_cmd.arg("wineboot").arg("--init");
                let _ = init_cmd.output();
            }
            _ => {}
        }
        
        // Check if winetricks is installed, if not download it
        let winetricks_path = Self::ensure_winetricks()?;
        
        // Run winetricks to install components
        let components = ["corefonts", "dxvk", "vkd3d"];
        
        for component in &components {
            let mut cmd = Command::new(&winetricks_path);
            cmd.env("WINEPREFIX", prefix_path);
            cmd.env("WINE", wine_path);
            
            // Apply NTSYNC disable to winetricks as well
            if disable_ntsync {
                cmd.env("WINE_DISABLE_FAST_SYNC", "1");
            }
            
            // Run in unattended mode
            cmd.arg("-q")
               .arg(component);
            
            // Log winetricks result but don't fail the install if it fails
            match cmd.output() {
                Ok(output) if !output.status.success() => {
                    eprintln!("Warning: winetricks {} failed: {}", component, 
                        String::from_utf8_lossy(&output.stderr));
                }
                Err(e) => {
                    eprintln!("Warning: Failed to run winetricks {}: {}", component, e);
                }
                _ => {}
            }
        }
        
        Ok(())
    }
    
    /// Ensure winetricks is available, downloading if necessary
    fn ensure_winetricks() -> Result<PathBuf> {
        // First check if winetricks is in PATH
        if let Ok(output) = Command::new("which").arg("winetricks").output() {
            if output.status.success() {
                let path = String::from_utf8_lossy(&output.stdout).trim().to_string();
                return Ok(PathBuf::from(path));
            }
        }
        
        // Download winetricks to cache directory
        let cache_dir = super::config::get_cache_dir();
        fs::create_dir_all(&cache_dir)?;
        
        let winetricks_path = cache_dir.join("winetricks");
        
        // If already downloaded and executable, use it
        if winetricks_path.exists() {
            return Ok(winetricks_path);
        }
        
        // Download winetricks
        let url = "https://raw.githubusercontent.com/Winetricks/winetricks/refs/heads/master/src/winetricks";
        
        let output = Command::new("curl")
            .arg("-L")
            .arg("-o")
            .arg(&winetricks_path)
            .arg(url)
            .output()
            .map_err(|e| GalaxiError::InstallError(format!("Failed to download winetricks: {}", e)))?;
        
        if !output.status.success() {
            // Try wget as fallback
            let output = Command::new("wget")
                .arg("-O")
                .arg(&winetricks_path)
                .arg(url)
                .output()
                .map_err(|e| GalaxiError::InstallError(format!("Failed to download winetricks: {}", e)))?;
            
            if !output.status.success() {
                return Err(GalaxiError::InstallError(
                    "Failed to download winetricks. Please install it manually.".to_string()
                ));
            }
        }
        
        // Make executable
        Command::new("chmod")
            .arg("+x")
            .arg(&winetricks_path)
            .output()
            .map_err(|e| GalaxiError::InstallError(format!("Failed to make winetricks executable: {}", e)))?;
        
        Ok(winetricks_path)
    }
    
    /// Get the per-game Wine prefix path
    pub fn get_game_wine_prefix(game: &Game) -> PathBuf {
        PathBuf::from(&game.install_dir).join("wine_prefix")
    }

    pub fn uninstall_game(game: &Game) -> Result<()> {
        if !game.is_installed() {
            return Err(GalaxiError::InstallError(
                "Game is not installed".to_string()
            ));
        }

        fs::remove_dir_all(&game.install_dir)?;

        let status_path = game.get_status_file_path();
        if status_path.exists() {
            fs::remove_file(status_path)?;
        }

        Ok(())
    }

    pub async fn install_dlc(
        game: &Game,
        dlc_installer_path: &PathBuf,
    ) -> Result<()> {
        Self::install_dlc_with_wine(game, dlc_installer_path, WineOptions::default()).await
    }
    
    pub async fn install_dlc_with_wine(
        game: &Game,
        dlc_installer_path: &PathBuf,
        wine_options: WineOptions,
    ) -> Result<()> {
        if !game.is_installed() {
            return Err(GalaxiError::InstallError(
                "Base game must be installed first".to_string()
            ));
        }

        let install_path = PathBuf::from(&game.install_dir);
        let file_name = dlc_installer_path
            .file_name()
            .map(|s| s.to_string_lossy().to_string())
            .unwrap_or_default();

        if file_name.ends_with(".sh") {
            Self::install_linux_game(dlc_installer_path, &install_path)?;
        } else if file_name.ends_with(".exe") {
            Self::install_windows_game(dlc_installer_path, &install_path, game, &wine_options)?;
        }

        Ok(())
    }
}

#[flutter_rust_bridge::frb(ignore)]
pub fn verify_game_files(game: &Game) -> Result<bool> {
    if !game.is_installed() {
        return Err(GalaxiError::InstallError(
            "Game is not installed".to_string()
        ));
    }

    let install_path = PathBuf::from(&game.install_dir);
    
    let has_start_script = install_path.join("start.sh").exists();
    let has_game_info = install_path.join("gameinfo").exists();
    let has_gog_info = install_path.join(format!("goggame-{}.info", game.id)).exists();

    Ok(has_start_script || has_game_info || has_gog_info)
}
