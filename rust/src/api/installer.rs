use std::fs;
use std::path::PathBuf;
use std::process::Command;
use super::error::{MinigalaxyError, Result};
use super::game::Game;

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
        let install_path = PathBuf::from(install_dir).join(game.get_install_directory_name());
        
        fs::create_dir_all(&install_path)?;
        
        let file_name = installer_path
            .file_name()
            .map(|s| s.to_string_lossy().to_string())
            .unwrap_or_default();

        if file_name.ends_with(".sh") {
            Self::install_linux_game(installer_path, &install_path)?;
        } else if file_name.ends_with(".exe") {
            Self::install_windows_game(installer_path, &install_path, game)?;
        } else {
            return Err(MinigalaxyError::InstallError(
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
            .map_err(|e| MinigalaxyError::InstallError(e.to_string()))?;

        let output = Command::new(installer_path)
            .arg("--")
            .arg("--noreadme")
            .arg("--nooptions")
            .arg("--noprompt")
            .arg("--destination")
            .arg(install_path)
            .output()
            .map_err(|e| MinigalaxyError::InstallError(e.to_string()))?;

        if !output.status.success() {
            return Err(MinigalaxyError::InstallError(
                String::from_utf8_lossy(&output.stderr).to_string()
            ));
        }

        Ok(())
    }

    fn install_windows_game(
        installer_path: &PathBuf,
        install_path: &PathBuf,
        game: &Game,
    ) -> Result<()> {
        // Per-game Wine prefix is stored inside the game's install directory
        let prefix_path = install_path.join("wine_prefix");
        fs::create_dir_all(&prefix_path)?;

        let dosdevices_path = prefix_path.join("dosdevices").join("c:").join("game");
        if !dosdevices_path.exists() {
            if let Some(parent) = dosdevices_path.parent() {
                fs::create_dir_all(parent)?;
            }
            #[cfg(unix)]
            std::os::unix::fs::symlink(install_path, &dosdevices_path)
                .map_err(|e| MinigalaxyError::InstallError(e.to_string()))?;
        }

        // Get per-game Wine executable if set, otherwise use default "wine"
        let wine_path = game.get_info("custom_wine")
            .ok()
            .flatten()
            .unwrap_or_else(|| "wine".to_string());

        let output = Command::new(&wine_path)
            .env("WINEPREFIX", &prefix_path)
            .arg(installer_path)
            .arg("/VERYSILENT")
            .arg("/NORESTART")
            .arg("/SUPPRESSMSGBOXES")
            .arg("/DIR=c:\\game")
            .output();

        match output {
            Ok(o) if o.status.success() => Ok(()),
            _ => {
                let output = Command::new(&wine_path)
                    .env("WINEPREFIX", &prefix_path)
                    .arg(installer_path)
                    .output()
                    .map_err(|e| MinigalaxyError::InstallError(e.to_string()))?;

                if !output.status.success() {
                    return Err(MinigalaxyError::InstallError(
                        "Wine installation failed".to_string()
                    ));
                }
                Ok(())
            }
        }
    }
    
    /// Get the per-game Wine prefix path
    pub fn get_game_wine_prefix(game: &Game) -> PathBuf {
        PathBuf::from(&game.install_dir).join("wine_prefix")
    }

    pub fn uninstall_game(game: &Game) -> Result<()> {
        if !game.is_installed() {
            return Err(MinigalaxyError::InstallError(
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
        if !game.is_installed() {
            return Err(MinigalaxyError::InstallError(
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
            Self::install_windows_game(dlc_installer_path, &install_path, game)?;
        }

        Ok(())
    }
}

#[flutter_rust_bridge::frb(ignore)]
pub fn verify_game_files(game: &Game) -> Result<bool> {
    if !game.is_installed() {
        return Err(MinigalaxyError::InstallError(
            "Game is not installed".to_string()
        ));
    }

    let install_path = PathBuf::from(&game.install_dir);
    
    let has_start_script = install_path.join("start.sh").exists();
    let has_game_info = install_path.join("gameinfo").exists();
    let has_gog_info = install_path.join(format!("goggame-{}.info", game.id)).exists();

    Ok(has_start_script || has_game_info || has_gog_info)
}
