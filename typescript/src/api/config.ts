import * as path from 'path';
import * as os from 'os';
import { ConfigDto } from './dto';

// Constants for supported download languages
export const SUPPORTED_DOWNLOAD_LANGUAGES: [string, string][] = [
  ['br', 'Brazilian Portuguese'],
  ['cn', 'Chinese'],
  ['da', 'Danish'],
  ['nl', 'Dutch'],
  ['en', 'English'],
  ['fi', 'Finnish'],
  ['fr', 'French'],
  ['de', 'German'],
  ['hu', 'Hungarian'],
  ['it', 'Italian'],
  ['jp', 'Japanese'],
  ['ko', 'Korean'],
  ['no', 'Norwegian'],
  ['pl', 'Polish'],
  ['pt', 'Portuguese'],
  ['ru', 'Russian'],
  ['es', 'Spanish'],
  ['sv', 'Swedish'],
  ['tr', 'Turkish'],
  ['ro', 'Romanian'],
];

export const SUPPORTED_LOCALES: [string, string][] = [
  ['', 'System default'],
  ['pt_BR', 'Brazilian Portuguese'],
  ['cs_CZ', 'Czech'],
  ['nl', 'Dutch'],
  ['en_US', 'English'],
  ['fi', 'Finnish'],
  ['fr', 'French'],
  ['de', 'German'],
  ['it_IT', 'Italian'],
  ['nb_NO', 'Norwegian Bokmål'],
  ['nn_NO', 'Norwegian Nynorsk'],
  ['pl', 'Polish'],
  ['pt_PT', 'Portuguese'],
  ['ru_RU', 'Russian'],
  ['zh_CN', 'Simplified Chinese'],
  ['es', 'Spanish'],
  ['es_ES', 'Spanish (Spain)'],
  ['sv_SE', 'Swedish'],
  ['zh_TW', 'Traditional Chinese'],
  ['tr', 'Turkish'],
  ['uk', 'Ukrainian'],
  ['el', 'Greek'],
  ['ro', 'Romanian'],
];

export const VIEWS: [string, string][] = [
  ['grid', 'Grid'],
  ['list', 'List'],
];

export const IGNORE_GAME_IDS: number[] = [
  1424856371, // Hotline Miami 2: Wrong Number - Digital Comics
  1980301910, // The Witcher Goodies Collection
  2005648906, // Spring Sale Goodies Collection #1
  1486144755, // Cyberpunk 2077 Goodies Collection
  1581684020, // A Plague Tale Digital Goodies Pack
  1185685769, // CDPR Goodie Pack Content
];

export const MINIMUM_RESUME_SIZE: number = 20 * 1024 * 1024;
export const DEFAULT_DOWNLOAD_THREAD_COUNT: number = 4;

export const BINARY_NAMES_TO_IGNORE: string[] = [
  'unins000.exe',
  'UnityCrashHandler64.exe',
  'nglide_config.exe',
  'ipxconfig.exe',
  'BNUpdate.exe',
  'VidSize.exe',
  'FRED2.exe',
  'FS2.exe',
];

export class Config {
  locale: string = '';
  lang: string = 'en';
  view: string = 'grid';
  install_dir: string;
  username: string = '';
  refresh_token: string = '';
  keep_installers: boolean = false;
  stay_logged_in: boolean = true;
  use_dark_theme: boolean = false;
  show_hidden_games: boolean = false;
  show_windows_games: boolean = false;
  keep_window_maximized: boolean = false;
  installed_filter: boolean = false;
  create_applications_file: boolean = false;
  max_parallel_game_downloads: number = DEFAULT_DOWNLOAD_THREAD_COUNT;
  current_downloads: number[] = [];
  paused_downloads: Map<string, number> = new Map();
  active_account_id?: string;
  wine_prefix: string = '';
  wine_executable: string = '';
  wine_debug: boolean = false;
  wine_disable_ntsync: boolean = false;
  wine_auto_install_dxvk: boolean = true;

  constructor() {
    this.install_dir = getDefaultInstallDir();
  }

  static loadFromDb(): Config {
    const config = new Config();
    try {
      const { getConfigValue } = require('./database');
      
      // Load each config value from the database
      try { config.locale = getConfigValue('locale'); } catch (e) {}
      try { config.lang = getConfigValue('lang'); } catch (e) {}
      try { config.view = getConfigValue('view'); } catch (e) {}
      try { config.install_dir = getConfigValue('install_dir'); } catch (e) {}
      try { config.username = getConfigValue('username'); } catch (e) {}
      try { config.refresh_token = getConfigValue('refresh_token'); } catch (e) {}
      try { config.keep_installers = getConfigValue('keep_installers') === 'true'; } catch (e) {}
      try { config.stay_logged_in = getConfigValue('stay_logged_in') === 'true'; } catch (e) {}
      try { config.use_dark_theme = getConfigValue('use_dark_theme') === 'true'; } catch (e) {}
      try { config.show_hidden_games = getConfigValue('show_hidden_games') === 'true'; } catch (e) {}
      try { config.show_windows_games = getConfigValue('show_windows_games') === 'true'; } catch (e) {}
      try {
        const val = getConfigValue('active_account_id');
        config.active_account_id = val ? val : undefined;
      } catch (e) {}
      // Wine settings
      try { config.wine_prefix = getConfigValue('wine_prefix'); } catch (e) {}
      try { config.wine_executable = getConfigValue('wine_executable'); } catch (e) {}
      try { config.wine_debug = getConfigValue('wine_debug') === 'true'; } catch (e) {}
      try { config.wine_disable_ntsync = getConfigValue('wine_disable_ntsync') === 'true'; } catch (e) {}
      try { config.wine_auto_install_dxvk = getConfigValue('wine_auto_install_dxvk') !== 'false'; } catch (e) {}
    } catch (e) {
      // Database not available, use defaults
    }
    
    return config;
  }

  save(): void {
    this.saveToDb();
  }

  saveToDb(): void {
    try {
      const { setConfigValue } = require('./database');
      
      setConfigValue('locale', this.locale);
      setConfigValue('lang', this.lang);
      setConfigValue('view', this.view);
      setConfigValue('install_dir', this.install_dir);
      setConfigValue('username', this.username);
      setConfigValue('refresh_token', this.refresh_token);
      setConfigValue('keep_installers', this.keep_installers ? 'true' : 'false');
      setConfigValue('stay_logged_in', this.stay_logged_in ? 'true' : 'false');
      setConfigValue('use_dark_theme', this.use_dark_theme ? 'true' : 'false');
      setConfigValue('show_hidden_games', this.show_hidden_games ? 'true' : 'false');
      setConfigValue('show_windows_games', this.show_windows_games ? 'true' : 'false');
      setConfigValue('active_account_id', this.active_account_id || '');
      // Wine settings
      setConfigValue('wine_prefix', this.wine_prefix);
      setConfigValue('wine_executable', this.wine_executable);
      setConfigValue('wine_debug', this.wine_debug ? 'true' : 'false');
      setConfigValue('wine_disable_ntsync', this.wine_disable_ntsync ? 'true' : 'false');
      setConfigValue('wine_auto_install_dxvk', this.wine_auto_install_dxvk ? 'true' : 'false');
    } catch (e) {
      // Database not available
    }
  }

  addOngoingDownload(downloadId: number): void {
    if (!this.current_downloads.includes(downloadId)) {
      this.current_downloads.push(downloadId);
    }
  }

  removeOngoingDownload(downloadId: number): void {
    this.current_downloads = this.current_downloads.filter(id => id !== downloadId);
  }

  addPausedDownload(saveLocation: string, progress: number): void {
    this.paused_downloads.set(saveLocation, progress);
  }

  removePausedDownload(saveLocation: string): void {
    this.paused_downloads.delete(saveLocation);
  }

  toDto(): ConfigDto {
    return {
      locale: this.locale,
      lang: this.lang,
      view: this.view,
      install_dir: this.install_dir,
      keep_installers: this.keep_installers,
      stay_logged_in: this.stay_logged_in,
      use_dark_theme: this.use_dark_theme,
      show_hidden_games: this.show_hidden_games,
      show_windows_games: this.show_windows_games,
      wine_prefix: this.wine_prefix,
      wine_executable: this.wine_executable,
      wine_debug: this.wine_debug,
      wine_disable_ntsync: this.wine_disable_ntsync,
      wine_auto_install_dxvk: this.wine_auto_install_dxvk,
    };
  }
}

function getDefaultInstallDir(): string {
  const homeDir = os.homedir();
  return path.join(homeDir, 'GOG Games');
}

export function getConfigFilePath(): string {
  const configDir = process.env.XDG_CONFIG_HOME || path.join(os.homedir(), '.config');
  return path.join(configDir, 'galaxi', 'config.json');
}

export function getDataDir(): string {
  const dataDir = process.env.XDG_DATA_HOME || path.join(os.homedir(), '.local', 'share');
  return path.join(dataDir, 'galaxi');
}

export function getCacheDir(): string {
  const cacheDir = process.env.XDG_CACHE_HOME || path.join(os.homedir(), '.cache');
  return path.join(cacheDir, 'galaxi');
}

export function getIconDir(): string {
  return path.join(getCacheDir(), 'icons');
}

export function getThumbnailDir(): string {
  return path.join(getCacheDir(), 'thumbnails');
}

export function getConfigGamesDir(): string {
  return path.join(getDataDir(), 'games');
}
