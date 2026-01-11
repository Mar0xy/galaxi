import { Config } from './config';
import { GogApi } from './gog_api';
import { DownloadManager } from './download';
import { GameInstaller } from './installer';
import { Game } from './game';
import { Account, fetchUserAvatar } from './account';
import { launchGame } from './launcher';
import { initDatabase, accountsDb, gamesDb } from './database';
import {
  AccountDto,
  UserDataDto,
  GameDto,
  ConfigDto,
  LaunchResultDto,
  GameInfoDto,
  GamesDbInfoDto,
  DownloadProgressDto,
} from './dto';
import { GalaxiError, GalaxiErrorType } from './error';
import * as fs from 'fs';
import * as path from 'path';
import { spawn } from 'child_process';

// Application state
class AppState {
  config: Config;
  api?: GogApi;
  downloadManager: DownloadManager;
  installer: GameInstaller;
  gamesCache: Map<number, Game> = new Map();

  constructor() {
    // Initialize database first
    try {
      initDatabase();
    } catch (error) {
      console.error('Failed to initialize database:', error);
    }

    // Load config from database or file
    this.config = Config.load();
    this.downloadManager = new DownloadManager();
    this.installer = new GameInstaller(this.downloadManager);
  }
}

const APP_STATE = new AppState();

// Export APP_STATE for internal use by other modules
export { APP_STATE };

// ============================================================================
// Simple API functions
// ============================================================================

export function greet(name: string): string {
  return `Hello, ${name}!`;
}

export function initApp(): void {
  console.log('Galaxi backend initialized');
}

// ============================================================================
// Authentication API
// ============================================================================

export function getLoginUrl(): string {
  return GogApi.getLoginUrl();
}

export function getRedirectUrl(): string {
  return GogApi.getRedirectUrl();
}

export function getSuccessUrl(): string {
  return GogApi.getSuccessUrl();
}

export async function authenticate(loginCode?: string, refreshToken?: string): Promise<string> {
  const api = new GogApi(APP_STATE.config);
  const newRefreshToken = await api.authenticate(loginCode, refreshToken);
  
  APP_STATE.api = api;
  APP_STATE.config.refresh_token = newRefreshToken;
  APP_STATE.config.save();
  
  return newRefreshToken;
}

export async function loginWithCode(code: string): Promise<AccountDto> {
  const refreshToken = await authenticate(code, undefined);
  const account = await addCurrentAccount(refreshToken);
  return account;
}

export async function isLoggedIn(): Promise<boolean> {
  return APP_STATE.api !== undefined;
}

export async function logout(): Promise<void> {
  APP_STATE.api = undefined;
  APP_STATE.config.refresh_token = '';
  APP_STATE.config.username = '';
  APP_STATE.config.save();
}

export async function getUserData(): Promise<UserDataDto> {
  if (!APP_STATE.api) {
    throw new GalaxiError('Not authenticated', GalaxiErrorType.AuthError);
  }
  
  const userData = await APP_STATE.api.getUserInfo();
  return {
    user_id: userData.userId,
    username: userData.username,
    email: userData.email,
  };
}

// ============================================================================
// Account Management API
// ============================================================================

export async function getAllAccounts(): Promise<AccountDto[]> {
  return accountsDb().getAllAccounts();
}

export async function getActiveAccount(): Promise<AccountDto | null> {
  return accountsDb().getActiveAccount();
}

export async function addCurrentAccount(refreshToken: string): Promise<AccountDto> {
  if (!APP_STATE.api) {
    throw new GalaxiError('Not authenticated', GalaxiErrorType.AuthError);
  }
  
  const userData = await APP_STATE.api.getUserInfo();
  const avatar = await fetchUserAvatar(APP_STATE.api, userData.userId);
  
  const account: AccountDto = {
    user_id: userData.userId,
    username: userData.username,
    refresh_token: refreshToken,
    avatar_url: avatar,
  };
  
  // Save to database
  accountsDb().addAccount(account);
  
  // Set as active account
  accountsDb().setActiveAccount(account.user_id);
  
  // Update config
  APP_STATE.config.active_account_id = account.user_id;
  APP_STATE.config.username = account.username;
  APP_STATE.config.save();
  
  return account;
}

export async function switchAccount(userId: string): Promise<boolean> {
  const account = accountsDb().getAccount(userId);
  
  if (account) {
    await authenticate(undefined, account.refresh_token);
    accountsDb().setActiveAccount(userId);
    return true;
  }
  
  return false;
}

export async function removeAccount(userId: string): Promise<void> {
  accountsDb().removeAccount(userId);
}

// ============================================================================
// Library API
// ============================================================================

export async function getLibrary(): Promise<GameDto[]> {
  if (!APP_STATE.api) {
    throw new GalaxiError('Not authenticated', GalaxiErrorType.AuthError);
  }
  
  const games = await APP_STATE.api.getLibrary();
  
  // Load existing games from database to preserve install_dir
  const existingGames = gamesDb().getAllGames();
  const existingMap = new Map(existingGames.map(g => [g.id, g]));
  
  // Update cache and database
  for (const game of games) {
    // Preserve install_dir from existing database record
    const existing = existingMap.get(game.id);
    if (existing && existing.install_dir) {
      game.install_dir = existing.install_dir;
    }
    
    APP_STATE.gamesCache.set(game.id, game);
    
    const gameDto: GameDto = {
      id: game.id,
      name: game.name,
      url: game.url,
      install_dir: game.install_dir,
      image_url: game.image_url,
      platform: game.platform,
      category: game.category,
      dlcs: game.dlcs.map(d => ({
        id: d.id,
        name: d.name,
        title: d.title,
        image_url: d.image_url,
      })),
    };
    
    gamesDb().saveGame(gameDto);
  }
  
  return games.map(g => ({
    id: g.id,
    name: g.name,
    url: g.url,
    install_dir: g.install_dir,
    image_url: g.image_url,
    platform: g.platform,
    category: g.category,
    dlcs: g.dlcs.map(d => ({
      id: d.id,
      name: d.name,
      title: d.title,
      image_url: d.image_url,
    })),
  }));
}

export async function getGameInfo(gameId: number): Promise<GameInfoDto> {
  if (!APP_STATE.api) {
    throw new GalaxiError('Not authenticated', GalaxiErrorType.AuthError);
  }
  
  const game = APP_STATE.gamesCache.get(gameId);
  if (!game) {
    throw new GalaxiError('Game not found in cache', GalaxiErrorType.NotFoundError);
  }
  
  const info = await APP_STATE.api.getInfo(game);
  
  const screenshots = info.screenshots?.map(s =>
    s.formatter_template_url.replace('{formatter}', 'product_card_v2_mobile_slider_639')
  ) || [];
  
  return {
    id: info.id,
    title: info.title,
    description: info.description?.full || info.description?.lead || '',
    changelog: info.changelog || '',
    screenshots,
  };
}

export async function getGamesDbInfo(gameId: number): Promise<GamesDbInfoDto> {
  if (!APP_STATE.api) {
    throw new GalaxiError('Not authenticated', GalaxiErrorType.AuthError);
  }
  
  const info = await APP_STATE.api.getGamesDbInfo(gameId);
  
  return {
    cover: info.cover || '',
    vertical_cover: info.vertical_cover || '',
    background: info.background || '',
    summary: (info.summary && info.summary['*']) || '',
    genre: (info.genre && info.genre['*']) || '',
  };
}

// ============================================================================
// Installation API
// ============================================================================

export async function installGame(gameId: number, installerUrl: string): Promise<GameDto> {
  const game = APP_STATE.gamesCache.get(gameId);
  if (!game) {
    throw new GalaxiError('Game not found', GalaxiErrorType.NotFoundError);
  }
  
  // Use sanitized directory name to avoid special characters in folder names
  const sanitizedName = Game.sanitizeFolderName(game.name);
  const installDir = `${APP_STATE.config.install_dir}/${sanitizedName}`;
  console.log(`Installing game "${game.name}" to sanitized directory: ${installDir}`);
  game.install_dir = installDir;
  
  const wineOptions = {
    prefix: APP_STATE.config.wine_prefix,
    executable: APP_STATE.config.wine_executable,
    debug: APP_STATE.config.wine_debug,
    disable_ntsync: APP_STATE.config.wine_disable_ntsync,
    auto_install_dxvk: APP_STATE.config.wine_auto_install_dxvk,
  };
  
  try {
    await APP_STATE.installer.installGame(game, installerUrl, installDir, wineOptions);
  } catch (error) {
    console.error('Installation failed:', error);
    throw error;
  }
  
  // Update cache and database BEFORE cleanup to ensure game shows as installed
  APP_STATE.gamesCache.set(gameId, game);
  const gameDto: GameDto = {
    id: game.id,
    name: game.name,
    url: game.url,
    install_dir: game.install_dir,
    image_url: game.image_url,
    platform: game.platform,
    category: game.category,
    dlcs: game.dlcs.map(d => ({
      id: d.id,
      name: d.name,
      title: d.title,
      image_url: d.image_url,
    })),
  };
  
  try {
    gamesDb().saveGame(gameDto);
    console.log(`Game "${game.name}" saved to database with install_dir: ${game.install_dir}`);
  } catch (error) {
    console.error('Failed to save game to database:', error);
    // Continue even if database save fails
  }
  
  // Clean up installer files if not keeping them (do this asynchronously in background)
  if (!APP_STATE.config.keep_installers) {
    const downloadsDir = path.join(APP_STATE.config.install_dir, '.downloads');
    // Run cleanup in background, don't wait for it and don't let it crash the app
    setImmediate(async () => {
      try {
        if (fs.existsSync(downloadsDir)) {
          console.log('Cleaning up downloaded installer files...');
          await fs.promises.rm(downloadsDir, { recursive: true, force: true });
          console.log('Installer files cleaned up successfully');
        }
      } catch (error) {
        console.warn('Failed to clean up installer files:', error);
        // Silently ignore cleanup failures
      }
    });
  }
  
  return gameDto;
}

// ============================================================================
// Launch API
// ============================================================================

export async function launchGameById(gameId: number): Promise<LaunchResultDto> {
  const game = APP_STATE.gamesCache.get(gameId);
  if (!game) {
    throw new GalaxiError('Game not found', GalaxiErrorType.NotFoundError);
  }
  
  const wineOptions = {
    wine_prefix: APP_STATE.config.wine_prefix || `${game.install_dir}/wine_prefix`,
    wine_executable: APP_STATE.config.wine_executable,
    wine_debug: APP_STATE.config.wine_debug,
    wine_disable_ntsync: APP_STATE.config.wine_disable_ntsync,
  };
  
  const result = await launchGame(game, game.platform === 'windows' ? wineOptions : undefined);
  
  return result;
}

// ============================================================================
// Config API
// ============================================================================

export async function getConfig(): Promise<ConfigDto> {
  return APP_STATE.config.toDto();
}

export async function setConfigValue(key: string, value: string): Promise<void> {
  (APP_STATE.config as any)[key] = value;
  APP_STATE.config.save();
}

export async function getDarkTheme(): Promise<boolean> {
  return APP_STATE.config.use_dark_theme;
}

export async function setDarkTheme(value: boolean): Promise<void> {
  APP_STATE.config.use_dark_theme = value;
  APP_STATE.config.save();
}

// ============================================================================
// Additional Configuration API
// ============================================================================

export async function getInstallDir(): Promise<string> {
  return APP_STATE.config.install_dir;
}

export async function setInstallDir(dir: string): Promise<void> {
  APP_STATE.config.install_dir = dir;
  APP_STATE.config.save();
}

export async function getLanguage(): Promise<string> {
  return APP_STATE.config.lang;
}

export async function setLanguage(lang: string): Promise<void> {
  APP_STATE.config.lang = lang;
  APP_STATE.config.save();
}

export async function getViewMode(): Promise<string> {
  return APP_STATE.config.view;
}

export async function setViewMode(view: string): Promise<void> {
  APP_STATE.config.view = view;
  APP_STATE.config.save();
}

export async function getShowWindowsGames(): Promise<boolean> {
  return APP_STATE.config.show_windows_games;
}

export async function setShowWindowsGames(enabled: boolean): Promise<void> {
  APP_STATE.config.show_windows_games = enabled;
  APP_STATE.config.save();
}

export async function getShowHiddenGames(): Promise<boolean> {
  return APP_STATE.config.show_hidden_games;
}

export async function setShowHiddenGames(enabled: boolean): Promise<void> {
  APP_STATE.config.show_hidden_games = enabled;
  APP_STATE.config.save();
}

export async function getKeepInstallers(): Promise<boolean> {
  return APP_STATE.config.keep_installers;
}

export async function setKeepInstallers(enabled: boolean): Promise<void> {
  APP_STATE.config.keep_installers = enabled;
  APP_STATE.config.save();
}

export async function getWinePrefix(): Promise<string> {
  return APP_STATE.config.wine_prefix;
}

export async function setWinePrefix(prefix: string): Promise<void> {
  APP_STATE.config.wine_prefix = prefix;
  APP_STATE.config.save();
}

export async function getWineExecutable(): Promise<string> {
  return APP_STATE.config.wine_executable;
}

export async function setWineExecutable(executable: string): Promise<void> {
  APP_STATE.config.wine_executable = executable;
  APP_STATE.config.save();
}

export async function getWineDebug(): Promise<boolean> {
  return APP_STATE.config.wine_debug;
}

export async function setWineDebug(enabled: boolean): Promise<void> {
  APP_STATE.config.wine_debug = enabled;
  APP_STATE.config.save();
}

export async function getWineDisableNtsync(): Promise<boolean> {
  return APP_STATE.config.wine_disable_ntsync;
}

export async function setWineDisableNtsync(enabled: boolean): Promise<void> {
  APP_STATE.config.wine_disable_ntsync = enabled;
  APP_STATE.config.save();
}

export async function getWineAutoInstallDxvk(): Promise<boolean> {
  return APP_STATE.config.wine_auto_install_dxvk;
}

export async function setWineAutoInstallDxvk(enabled: boolean): Promise<void> {
  APP_STATE.config.wine_auto_install_dxvk = enabled;
  APP_STATE.config.save();
}

// ============================================================================
// Additional Library API
// ============================================================================

export async function getCachedGames(): Promise<GameDto[]> {
  const games = Array.from(APP_STATE.gamesCache.values());
  return games.map(g => ({
    id: g.id,
    name: g.name,
    url: g.url,
    install_dir: g.install_dir,
    image_url: g.image_url,
    platform: g.platform,
    category: g.category,
    dlcs: g.dlcs.map(d => ({
      id: d.id,
      name: d.name,
      title: d.title,
      image_url: d.image_url,
    })),
  }));
}

function normalizeDirName(name: string): string {
  return name
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, '')
    .trim();
}

export async function scanForInstalledGames(): Promise<number> {
  const installBase = APP_STATE.config.install_dir;
  
  if (!fs.existsSync(installBase)) {
    return 0;
  }
  
  let updatedCount = 0;
  
  try {
    const entries = await fs.promises.readdir(installBase);
    
    // Process entries in parallel for better performance
    await Promise.all(entries.map(async (entry) => {
      try {
        const fullPath = path.join(installBase, entry);
        const stats = await fs.promises.stat(fullPath);
        
        if (!stats.isDirectory()) {
          return;
        }
        
        // Skip .downloads folder
        if (entry.startsWith('.')) {
          return;
        }
        
        // Check if this directory has wine_prefix/drive_c (Windows game) or a start script (Linux game)
        const winePrefix = path.join(fullPath, 'wine_prefix', 'drive_c');
        const startScript = path.join(fullPath, 'start.sh');
        
        const [winePrefixExists, startScriptExists] = await Promise.all([
          fs.promises.access(winePrefix).then(() => true).catch(() => false),
          fs.promises.access(startScript).then(() => true).catch(() => false)
        ]);
        
        const isInstalled = winePrefixExists || startScriptExists;
        
        if (!isInstalled) {
          return;
        }
        
        // Normalize the directory name for comparison
        const normalizedDir = normalizeDirName(entry);
        
        // Try to find a matching game in the cache
        for (const game of APP_STATE.gamesCache.values()) {
          const gameDir = Game.sanitizeFolderName(game.name);
          const normalizedGameDir = normalizeDirName(gameDir);
          
          // Match by normalized name
          if (normalizedGameDir === normalizedDir && !game.install_dir) {
            // Found a match - update install_dir
            game.install_dir = fullPath;
            gamesDb().saveGame({
              id: game.id,
              name: game.name,
              url: game.url,
              install_dir: game.install_dir,
              image_url: game.image_url,
              platform: game.platform,
              category: game.category,
              dlcs: game.dlcs.map(d => ({
                id: d.id,
                name: d.name,
                title: d.title,
                image_url: d.image_url,
              })),
            });
            updatedCount++;
            break;
          }
        }
      } catch (error) {
        // Skip entries that cause errors (permissions, etc)
        console.warn(`Error processing directory ${entry}:`, error);
      }
    }));
  } catch (error) {
    console.error('Error scanning for installed games:', error);
  }
  
  return updatedCount;
}

// ============================================================================
// Download API
// ============================================================================

function extractFilenameFromUrl(url: string): string {
  const parts = url.split('/');
  const rawName = parts[parts.length - 1].split('?')[0];
  return decodeURIComponent(rawName);
}

export async function startDownload(gameId: number): Promise<string> {
  if (!APP_STATE.api) {
    throw new GalaxiError('Not authenticated', GalaxiErrorType.AuthError);
  }
  
  const game = APP_STATE.gamesCache.get(gameId);
  if (!game) {
    throw new GalaxiError('Game not found', GalaxiErrorType.NotFoundError);
  }
  
  // Get download info
  const info = await APP_STATE.api.getInfo(game);
  
  if (!info.downloads || info.downloads.installers.length === 0) {
    throw new GalaxiError('No installers available', GalaxiErrorType.NoDownloadLinkFound);
  }
  
  // Find installer for the game platform
  const installer = info.downloads.installers.find(i => 
    i.os.toLowerCase() === game.platform.toLowerCase()
  ) || info.downloads.installers[0];
  
  if (!installer.files || installer.files.length === 0) {
    throw new GalaxiError('No download files available', GalaxiErrorType.NoDownloadLinkFound);
  }
  
  // Create downloads directory
  const downloadsDir = path.join(APP_STATE.config.install_dir, '.downloads');
  if (!fs.existsSync(downloadsDir)) {
    fs.mkdirSync(downloadsDir, { recursive: true });
  }
  
  // Pre-compute all download paths and real links
  const downloadTasks: Array<{ realLink: string; savePath: string; needsDownload: boolean }> = [];
  
  for (const file of installer.files) {
    console.log('Installer file downlink:', file.downlink);
    
    if (!file.downlink) {
      throw new GalaxiError('Download link is missing from installer file', GalaxiErrorType.NoDownloadLinkFound);
    }
    
    const realLink = await APP_STATE.api.getDownloadLink(file.downlink);
    console.log('Real download link:', realLink);
    
    if (!realLink || !realLink.startsWith('http')) {
      throw new GalaxiError(`Invalid download URL received: ${realLink}`, GalaxiErrorType.DownloadError);
    }
    
    const fileName = extractFilenameFromUrl(realLink);
    const savePath = path.join(downloadsDir, fileName);
    
    // Check if already downloaded
    const needsDownload = !fs.existsSync(savePath);
    downloadTasks.push({ realLink, savePath, needsDownload });
  }
  
  // Return the first installer path for installation
  const firstInstallerPath = downloadTasks[0].savePath;
  
  // Check if all files are already downloaded
  const allDownloaded = downloadTasks.every(task => !task.needsDownload);
  if (allDownloaded) {
    return firstInstallerPath;
  }
  
  // Start all downloads in background
  setTimeout(async () => {
    try {
      for (const task of downloadTasks) {
        if (!task.needsDownload) {
          console.log('Skipping already downloaded file:', task.savePath);
          continue;
        }
        
        console.log('Starting download:', task.realLink, '->', task.savePath);
        await APP_STATE.downloadManager.downloadFile(game, task.realLink, task.savePath);
      }
    } catch (error) {
      console.error('Download failed:', error);
    }
  }, 0);
  
  return firstInstallerPath;
}

export async function downloadAndInstall(gameId: number): Promise<GameDto> {
  // Start download
  const installerPath = await startDownload(gameId);
  
  // Wait for download to complete
  while (true) {
    const progress = APP_STATE.downloadManager.getProgress(gameId);
    if (!progress) {
      break;
    }
    if (progress.status === 'Completed') {
      break;
    }
    if (progress.status === 'Failed') {
      throw new GalaxiError('Download failed', GalaxiErrorType.DownloadError);
    }
    await new Promise(resolve => setTimeout(resolve, 500));
  }
  
  // Install the game
  const gameDto = await installGame(gameId, installerPath);
  
  // Clean up installer if not keeping them
  if (!APP_STATE.config.keep_installers) {
    
    
    const downloadsDir = path.join(APP_STATE.config.install_dir, '.downloads');
    try {
      fs.rmSync(downloadsDir, { recursive: true, force: true });
    } catch (error) {
      console.error('Failed to clean up installer:', error);
    }
  }
  
  return gameDto;
}

export async function pauseDownload(gameId: number): Promise<void> {
  APP_STATE.downloadManager.pauseDownload(gameId);
}

export async function cancelDownload(gameId: number): Promise<void> {
  APP_STATE.downloadManager.cancelDownload(gameId);
}

export async function getDownloadProgress(gameId: number): Promise<DownloadProgressDto | null> {
  const progress = APP_STATE.downloadManager.getProgress(gameId);
  if (!progress) {
    return null;
  }
  
  return {
    game_id: progress.game_id,
    game_name: progress.file_name,
    downloaded_bytes: progress.downloaded,
    total_bytes: progress.total,
    speed_bytes_per_sec: 0,
    status: progress.status.toString(),
  };
}

export async function getActiveDownloads(): Promise<DownloadProgressDto[]> {
  // Not yet implemented - would need to track multiple downloads
  return [];
}

// ============================================================================
// Installation API (continued)
// ============================================================================

export async function uninstallGame(gameId: number): Promise<void> {
  const game = APP_STATE.gamesCache.get(gameId);
  if (!game) {
    throw new GalaxiError('Game not found', GalaxiErrorType.NotFoundError);
  }
  
  
  
  if (game.install_dir && fs.existsSync(game.install_dir)) {
    try {
      fs.rmSync(game.install_dir, { recursive: true, force: true });
    } catch (error: any) {
      throw new GalaxiError(
        `Failed to uninstall game: ${error.message}`,
        GalaxiErrorType.FileSystemError
      );
    }
  }
  
  game.install_dir = '';
  
  // Update in database
  gamesDb().saveGame({
    id: game.id,
    name: game.name,
    url: game.url,
    install_dir: game.install_dir,
    image_url: game.image_url,
    platform: game.platform,
    category: game.category,
    dlcs: game.dlcs.map(d => ({
      id: d.id,
      name: d.name,
      title: d.title,
      image_url: d.image_url,
    })),
  });
}

export async function installDlc(gameId: number, dlcInstallerPath: string): Promise<void> {
  const game = APP_STATE.gamesCache.get(gameId);
  if (!game) {
    throw new GalaxiError('Game not found', GalaxiErrorType.NotFoundError);
  }
  
  const wineOptions = {
    prefix: APP_STATE.config.wine_prefix,
    executable: APP_STATE.config.wine_executable,
    debug: APP_STATE.config.wine_debug,
    disable_ntsync: APP_STATE.config.wine_disable_ntsync,
    auto_install_dxvk: false, // Don't re-install DXVK for DLC
  };
  
  // Install DLC to the game directory
  await APP_STATE.installer.installGame(game, dlcInstallerPath, game.install_dir, wineOptions);
}

// ============================================================================
// Wine Tools API
// ============================================================================

export async function openWineConfig(gameId: number): Promise<void> {
  const game = APP_STATE.gamesCache.get(gameId);
  if (!game) {
    throw new GalaxiError('Game not found', GalaxiErrorType.NotFoundError);
  }
  
  const winePrefix = APP_STATE.config.wine_prefix || `${game.install_dir}/wine_prefix`;
  const wineExec = APP_STATE.config.wine_executable || 'wine';
  
  
  const env: any = {
    ...process.env,
    WINEPREFIX: winePrefix,
  };
  
  spawn(wineExec, ['winecfg'], {
    env,
    detached: true,
    stdio: 'ignore',
  }).unref();
}

export async function openWineRegedit(gameId: number): Promise<void> {
  const game = APP_STATE.gamesCache.get(gameId);
  if (!game) {
    throw new GalaxiError('Game not found', GalaxiErrorType.NotFoundError);
  }
  
  const winePrefix = APP_STATE.config.wine_prefix || `${game.install_dir}/wine_prefix`;
  const wineExec = APP_STATE.config.wine_executable || 'wine';
  
  
  const env: any = {
    ...process.env,
    WINEPREFIX: winePrefix,
  };
  
  spawn(wineExec, ['regedit'], {
    env,
    detached: true,
    stdio: 'ignore',
  }).unref();
}

export async function openWinetricks(gameId: number): Promise<void> {
  const game = APP_STATE.gamesCache.get(gameId);
  if (!game) {
    throw new GalaxiError('Game not found', GalaxiErrorType.NotFoundError);
  }
  
  const winePrefix = APP_STATE.config.wine_prefix || `${game.install_dir}/wine_prefix`;
  
  
  const env: any = {
    ...process.env,
    WINEPREFIX: winePrefix,
  };
  
  spawn('winetricks', [], {
    env,
    detached: true,
    stdio: 'ignore',
  }).unref();
}

// Export types
export * from './dto';
export * from './error';
