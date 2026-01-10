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
    description: info.description?.full,
    changelog: info.changelog,
    screenshots,
  };
}

export async function getGamesDbInfo(gameId: number): Promise<GamesDbInfoDto> {
  if (!APP_STATE.api) {
    throw new GalaxiError('Not authenticated', GalaxiErrorType.AuthError);
  }
  
  const info = await APP_STATE.api.getGamesDbInfo(gameId);
  
  return {
    cover: info.cover,
    vertical_cover: info.vertical_cover,
    background: info.background,
    summary: info.summary['*'] || '',
    genre: info.genre['*'] || '',
  };
}

// ============================================================================
// Installation API
// ============================================================================

export async function installGame(gameId: number, installerUrl: string): Promise<void> {
  const game = APP_STATE.gamesCache.get(gameId);
  if (!game) {
    throw new GalaxiError('Game not found', GalaxiErrorType.NotFoundError);
  }
  
  const installDir = `${APP_STATE.config.install_dir}/${game.name}`;
  game.install_dir = installDir;
  
  const wineOptions = {
    prefix: APP_STATE.config.wine_prefix,
    executable: APP_STATE.config.wine_executable,
    debug: APP_STATE.config.wine_debug,
    disable_ntsync: APP_STATE.config.wine_disable_ntsync,
    auto_install_dxvk: APP_STATE.config.wine_auto_install_dxvk,
  };
  
  await APP_STATE.installer.installGame(game, installerUrl, installDir, wineOptions);
  
  // Update cache and database
  APP_STATE.gamesCache.set(gameId, game);
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

// Export types
export * from './dto';
export * from './error';
