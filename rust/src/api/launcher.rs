use std::env;
use std::fs;
use std::path::PathBuf;
use std::process::{Command, Stdio};
use serde::{Deserialize, Serialize};
use super::config::BINARY_NAMES_TO_IGNORE;
use super::error::{MinigalaxyError, Result};
use super::game::Game;

/// Wine launch options
#[flutter_rust_bridge::frb(ignore)]
#[derive(Debug, Clone, Default)]
pub struct WineLaunchOptions {
    pub wine_executable: Option<String>,
    pub disable_ntsync: bool,
}

/// Launcher type for a game
#[derive(Debug, Clone, PartialEq)]
pub enum LauncherType {
    StartScript,
    Windows,
    Wine,
    DosBox,
    ScummVM,
    FinalResort,
    Unknown,
}

/// Launch result
#[flutter_rust_bridge::frb(non_opaque)]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LaunchResult {
    pub success: bool,
    pub error_message: Option<String>,
    pub pid: Option<u32>,
}

#[flutter_rust_bridge::frb(ignore)]
pub fn get_wine_path(game: &Game) -> String {
    get_wine_path_with_fallback(game, None)
}

#[flutter_rust_bridge::frb(ignore)]
pub fn get_wine_path_with_fallback(game: &Game, global_wine_executable: Option<&str>) -> String {
    // Priority: per-game setting > global setting > default "wine"
    game.get_info("custom_wine")
        .ok()
        .flatten()
        .or_else(|| global_wine_executable.filter(|s| !s.is_empty()).map(|s| s.to_string()))
        .unwrap_or_else(|| "wine".to_string())
}

#[flutter_rust_bridge::frb(ignore)]
pub fn determine_launcher_type(game: &Game) -> LauncherType {
    if !game.is_installed() {
        return LauncherType::Unknown;
    }

    let install_dir = PathBuf::from(&game.install_dir);
    
    if install_dir.join("unins000.exe").exists() {
        return LauncherType::Windows;
    }
    
    if install_dir.join("dosbox").exists() {
        if which::which("dosbox").is_ok() {
            return LauncherType::DosBox;
        }
    }
    
    if install_dir.join("scummvm").exists() {
        if which::which("scummvm").is_ok() {
            return LauncherType::ScummVM;
        }
    }
    
    if install_dir.join("start.sh").exists() {
        return LauncherType::StartScript;
    }
    
    if install_dir.join("wine_prefix").exists() {
        if which::which("wine").is_ok() {
            return LauncherType::Wine;
        }
    }
    
    if install_dir.join("game").exists() {
        return LauncherType::FinalResort;
    }
    
    LauncherType::Unknown
}

#[flutter_rust_bridge::frb(ignore)]
pub fn get_execute_command(game: &Game) -> Result<Vec<String>> {
    let launcher_type = determine_launcher_type(game);
    let install_dir = PathBuf::from(&game.install_dir);
    
    let mut exe_cmd = match launcher_type {
        LauncherType::StartScript => {
            vec![install_dir.join("start.sh").to_string_lossy().to_string()]
        }
        LauncherType::Wine => {
            get_wine_start_command(game)?
        }
        LauncherType::Windows => {
            get_windows_exe_cmd(game)?
        }
        LauncherType::DosBox => {
            get_dosbox_cmd(game)?
        }
        LauncherType::ScummVM => {
            get_scummvm_cmd(game)?
        }
        LauncherType::FinalResort => {
            get_final_resort_cmd(game)?
        }
        LauncherType::Unknown => {
            return Err(MinigalaxyError::LaunchError(
                format!("No executable found in {}", game.install_dir)
            ));
        }
    };
    
    if let Ok(Some(use_gamemode)) = game.get_info("use_gamemode") {
        if use_gamemode == "true" {
            exe_cmd.insert(0, "gamemoderun".to_string());
        }
    }
    
    if let Ok(Some(use_mangohud)) = game.get_info("use_mangohud") {
        if use_mangohud == "true" {
            exe_cmd.insert(0, "--dlsym".to_string());
            exe_cmd.insert(0, "mangohud".to_string());
        }
    }
    
    if let Ok(Some(variable)) = game.get_info("variable") {
        if !variable.is_empty() {
            let vars: Vec<String> = variable.split_whitespace().map(|s| s.to_string()).collect();
            if !vars.is_empty() && vars[0] != "env" {
                exe_cmd.insert(0, "env".to_string());
            }
            for (i, var) in vars.into_iter().enumerate() {
                exe_cmd.insert(i + 1, var);
            }
        }
    }
    
    if let Ok(Some(command)) = game.get_info("command") {
        if !command.is_empty() {
            let cmds: Vec<String> = command.split_whitespace().map(|s| s.to_string()).collect();
            exe_cmd.extend(cmds);
        }
    }
    
    Ok(exe_cmd)
}

fn get_wine_start_command(game: &Game) -> Result<Vec<String>> {
    let install_dir = PathBuf::from(&game.install_dir);
    let prefix = install_dir.join("wine_prefix");
    let _wine = get_wine_path(game);
    
    if install_dir.join("start.sh").exists() {
        return Ok(vec![install_dir.join("start.sh").to_string_lossy().to_string()]);
    }
    
    let mut exe_cmd = get_windows_exe_cmd(game)?;
    exe_cmd.insert(0, format!("WINEPREFIX={}", prefix.to_string_lossy()));
    exe_cmd.insert(0, "env".to_string());
    
    Ok(exe_cmd)
}

fn get_windows_exe_cmd(game: &Game) -> Result<Vec<String>> {
    let install_dir = PathBuf::from(&game.install_dir);
    let prefix = install_dir.join("wine_prefix");
    let wine = get_wine_path(game);
    
    let goggame_file = install_dir.join(format!("goggame-{}.info", game.id));
    if goggame_file.exists() {
        if let Ok(content) = fs::read_to_string(&goggame_file) {
            if let Ok(info) = serde_json::from_str::<serde_json::Value>(&content) {
                if let Some(tasks) = info.get("playTasks").and_then(|t| t.as_array()) {
                    for task in tasks {
                        if task.get("isPrimary").and_then(|p| p.as_bool()).unwrap_or(false) {
                            if let Some(path) = task.get("path").and_then(|p| p.as_str()) {
                                let working_dir = task.get("workingDir")
                                    .and_then(|w| w.as_str())
                                    .unwrap_or(".");
                                
                                let mut cmd = vec![
                                    "env".to_string(),
                                    format!("WINEPREFIX={}", prefix.to_string_lossy()),
                                    wine.clone(),
                                    "start".to_string(),
                                    "/b".to_string(),
                                    "/wait".to_string(),
                                    "/d".to_string(),
                                    format!("c:\\game\\{}", working_dir),
                                    format!("c:\\game\\{}", path),
                                ];
                                
                                if let Some(args) = task.get("arguments").and_then(|a| a.as_str()) {
                                    cmd.extend(args.split_whitespace().map(|s| s.to_string()));
                                }
                                
                                return Ok(cmd);
                            }
                        }
                    }
                }
            }
        }
    }
    
    if let Ok(entries) = fs::read_dir(&install_dir) {
        for entry in entries.flatten() {
            let name = entry.file_name().to_string_lossy().to_string();
            if name.starts_with("Launch ") && name.ends_with(".lnk") {
                return Ok(vec![
                    "env".to_string(),
                    format!("WINEPREFIX={}", prefix.to_string_lossy()),
                    wine,
                    entry.path().to_string_lossy().to_string(),
                ]);
            }
        }
    }
    
    if let Ok(entries) = fs::read_dir(&install_dir) {
        for entry in entries.flatten() {
            let name = entry.file_name().to_string_lossy().to_string();
            let upper = name.to_uppercase();
            
            if !upper.ends_with(".EXE") && !upper.ends_with(".LNK") {
                continue;
            }
            
            if BINARY_NAMES_TO_IGNORE.contains(&name.as_str()) {
                continue;
            }
            
            return Ok(vec![
                "env".to_string(),
                format!("WINEPREFIX={}", prefix.to_string_lossy()),
                wine,
                entry.path().to_string_lossy().to_string(),
            ]);
        }
    }
    
    Err(MinigalaxyError::LaunchError(
        "No Windows executable found".to_string()
    ))
}

fn get_dosbox_cmd(game: &Game) -> Result<Vec<String>> {
    let install_dir = PathBuf::from(&game.install_dir);
    
    let mut config_file = String::new();
    let mut single_config = String::new();
    
    if let Ok(entries) = fs::read_dir(&install_dir) {
        for entry in entries.flatten() {
            let name = entry.file_name().to_string_lossy().to_string();
            if name.starts_with("dosbox") && name.ends_with(".conf") {
                if name.contains("single") {
                    single_config = name;
                } else {
                    config_file = name;
                }
            }
        }
    }
    
    Ok(vec![
        "dosbox".to_string(),
        "-conf".to_string(),
        config_file,
        "-conf".to_string(),
        single_config,
        "-no-console".to_string(),
        "-c".to_string(),
        "exit".to_string(),
    ])
}

fn get_scummvm_cmd(game: &Game) -> Result<Vec<String>> {
    let install_dir = PathBuf::from(&game.install_dir);
    
    let mut config_file = String::new();
    
    if let Ok(entries) = fs::read_dir(&install_dir) {
        for entry in entries.flatten() {
            let name = entry.file_name().to_string_lossy().to_string();
            if name.ends_with(".ini") {
                config_file = name;
                break;
            }
        }
    }
    
    Ok(vec![
        "scummvm".to_string(),
        "-c".to_string(),
        config_file,
    ])
}

fn get_final_resort_cmd(game: &Game) -> Result<Vec<String>> {
    let install_dir = PathBuf::from(&game.install_dir);
    let game_dir = install_dir.join("game");
    
    if let Ok(entries) = fs::read_dir(&game_dir) {
        for entry in entries.flatten() {
            let name = entry.file_name().to_string_lossy().to_string();
            if name.starts_with("goggame-") && name.ends_with(".info") {
                if let Ok(content) = fs::read_to_string(entry.path()) {
                    if let Ok(info) = serde_json::from_str::<serde_json::Value>(&content) {
                        if let Some(tasks) = info.get("playTasks").and_then(|t| t.as_array()) {
                            if let Some(path) = tasks.first()
                                .and_then(|t| t.get("path"))
                                .and_then(|p| p.as_str()) {
                                return Ok(vec![format!("./{}", path)]);
                            }
                        }
                    }
                }
            }
        }
    }
    
    Err(MinigalaxyError::LaunchError(
        "No executable found in game directory".to_string()
    ))
}

fn set_fps_display(game: &Game) {
    if let Ok(Some(show_fps)) = game.get_info("show_fps") {
        if show_fps == "true" {
            env::set_var("__GL_SHOW_GRAPHICS_OSD", "1");
            env::set_var("GALLIUM_HUD", "simple,fps");
            env::set_var("VK_INSTANCE_LAYERS", "VK_LAYER_MESA_overlay");
        } else {
            env::set_var("__GL_SHOW_GRAPHICS_OSD", "0");
            env::set_var("GALLIUM_HUD", "");
            env::set_var("VK_INSTANCE_LAYERS", "");
        }
    }
}

#[flutter_rust_bridge::frb(ignore)]
pub fn start_game(game: &Game) -> Result<LaunchResult> {
    start_game_with_options(game, WineLaunchOptions::default())
}

#[flutter_rust_bridge::frb(ignore)]
pub fn start_game_with_options(game: &Game, wine_options: WineLaunchOptions) -> Result<LaunchResult> {
    if !game.is_installed() {
        return Ok(LaunchResult {
            success: false,
            error_message: Some("Game is not installed".to_string()),
            pid: None,
        });
    }
    
    set_fps_display(game);
    
    let exe_cmd = get_execute_command(game)?;
    
    if exe_cmd.is_empty() {
        return Ok(LaunchResult {
            success: false,
            error_message: Some("No execute command found".to_string()),
            pid: None,
        });
    }
    
    let install_dir = PathBuf::from(&game.install_dir);
    
    let mut cmd = Command::new(&exe_cmd[0]);
    for arg in exe_cmd.iter().skip(1) {
        cmd.arg(arg);
    }
    
    // Apply NTSYNC disable if requested (for Wine games)
    if wine_options.disable_ntsync {
        cmd.env("WINE_DISABLE_FAST_SYNC", "1");
    }
    
    cmd.current_dir(&install_dir)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped());
    
    match cmd.spawn() {
        Ok(child) => {
            Ok(LaunchResult {
                success: true,
                error_message: None,
                pid: Some(child.id()),
            })
        }
        Err(e) => {
            Ok(LaunchResult {
                success: false,
                error_message: Some(e.to_string()),
                pid: None,
            })
        }
    }
}

#[flutter_rust_bridge::frb(ignore)]
pub fn config_game(game: &Game) -> Result<()> {
    if !game.is_installed() {
        return Err(MinigalaxyError::LaunchError("Game is not installed".to_string()));
    }
    
    let prefix = PathBuf::from(&game.install_dir).join("wine_prefix");
    let wine = get_wine_path(game);
    
    Command::new("env")
        .arg(format!("WINEPREFIX={}", prefix.to_string_lossy()))
        .arg(&wine)
        .arg("winecfg")
        .spawn()
        .map_err(|e| MinigalaxyError::LaunchError(e.to_string()))?;
    
    Ok(())
}

#[flutter_rust_bridge::frb(ignore)]
pub fn regedit_game(game: &Game) -> Result<()> {
    if !game.is_installed() {
        return Err(MinigalaxyError::LaunchError("Game is not installed".to_string()));
    }
    
    let prefix = PathBuf::from(&game.install_dir).join("wine_prefix");
    let wine = get_wine_path(game);
    
    Command::new("env")
        .arg(format!("WINEPREFIX={}", prefix.to_string_lossy()))
        .arg(&wine)
        .arg("regedit")
        .spawn()
        .map_err(|e| MinigalaxyError::LaunchError(e.to_string()))?;
    
    Ok(())
}

#[flutter_rust_bridge::frb(ignore)]
pub fn winetricks_game(game: &Game) -> Result<()> {
    if !game.is_installed() {
        return Err(MinigalaxyError::LaunchError("Game is not installed".to_string()));
    }
    
    let prefix = PathBuf::from(&game.install_dir).join("wine_prefix");
    
    Command::new("env")
        .arg(format!("WINEPREFIX={}", prefix.to_string_lossy()))
        .arg("winetricks")
        .spawn()
        .map_err(|e| MinigalaxyError::LaunchError(e.to_string()))?;
    
    Ok(())
}
