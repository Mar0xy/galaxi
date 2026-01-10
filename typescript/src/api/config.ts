import * as fs from 'fs';
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

  static load(): Config {
    const configPath = getConfigFilePath();
    if (fs.existsSync(configPath)) {
      try {
        const content = fs.readFileSync(configPath, 'utf-8');
        const data = JSON.parse(content);
        const config = new Config();
        Object.assign(config, data);
        // Convert paused_downloads object to Map
        if (data.paused_downloads && typeof data.paused_downloads === 'object') {
          config.paused_downloads = new Map(Object.entries(data.paused_downloads).map(([k, v]) => [k, v as number]));
        }
        return config;
      } catch (e) {
        return new Config();
      }
    }
    return new Config();
  }

  static loadFromDb(): Config {
    // Will be implemented when database module is ready
    const config = new Config();
    // Load from database using get_config_value
    return config;
  }

  save(): void {
    this.saveToFile();
    this.saveToDb();
  }

  private saveToFile(): void {
    const configPath = getConfigFilePath();
    const dir = path.dirname(configPath);
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
    // Convert Map to object for JSON serialization
    const data = { ...this };
    (data as any).paused_downloads = Object.fromEntries(this.paused_downloads);
    const content = JSON.stringify(data, null, 2);
    fs.writeFileSync(configPath, content, 'utf-8');
  }

  saveToDb(): void {
    // Will be implemented when database module is ready
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
