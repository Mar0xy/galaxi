"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.Config = exports.BINARY_NAMES_TO_IGNORE = exports.DEFAULT_DOWNLOAD_THREAD_COUNT = exports.MINIMUM_RESUME_SIZE = exports.IGNORE_GAME_IDS = exports.VIEWS = exports.SUPPORTED_LOCALES = exports.SUPPORTED_DOWNLOAD_LANGUAGES = void 0;
exports.getConfigFilePath = getConfigFilePath;
exports.getDataDir = getDataDir;
exports.getCacheDir = getCacheDir;
exports.getIconDir = getIconDir;
exports.getThumbnailDir = getThumbnailDir;
exports.getConfigGamesDir = getConfigGamesDir;
const fs = __importStar(require("fs"));
const path = __importStar(require("path"));
const os = __importStar(require("os"));
// Constants for supported download languages
exports.SUPPORTED_DOWNLOAD_LANGUAGES = [
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
exports.SUPPORTED_LOCALES = [
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
exports.VIEWS = [
    ['grid', 'Grid'],
    ['list', 'List'],
];
exports.IGNORE_GAME_IDS = [
    1424856371, // Hotline Miami 2: Wrong Number - Digital Comics
    1980301910, // The Witcher Goodies Collection
    2005648906, // Spring Sale Goodies Collection #1
    1486144755, // Cyberpunk 2077 Goodies Collection
    1581684020, // A Plague Tale Digital Goodies Pack
    1185685769, // CDPR Goodie Pack Content
];
exports.MINIMUM_RESUME_SIZE = 20 * 1024 * 1024;
exports.DEFAULT_DOWNLOAD_THREAD_COUNT = 4;
exports.BINARY_NAMES_TO_IGNORE = [
    'unins000.exe',
    'UnityCrashHandler64.exe',
    'nglide_config.exe',
    'ipxconfig.exe',
    'BNUpdate.exe',
    'VidSize.exe',
    'FRED2.exe',
    'FS2.exe',
];
class Config {
    constructor() {
        this.locale = '';
        this.lang = 'en';
        this.view = 'grid';
        this.username = '';
        this.refresh_token = '';
        this.keep_installers = false;
        this.stay_logged_in = true;
        this.use_dark_theme = false;
        this.show_hidden_games = false;
        this.show_windows_games = false;
        this.keep_window_maximized = false;
        this.installed_filter = false;
        this.create_applications_file = false;
        this.max_parallel_game_downloads = exports.DEFAULT_DOWNLOAD_THREAD_COUNT;
        this.current_downloads = [];
        this.paused_downloads = new Map();
        this.wine_prefix = '';
        this.wine_executable = '';
        this.wine_debug = false;
        this.wine_disable_ntsync = false;
        this.wine_auto_install_dxvk = true;
        this.install_dir = getDefaultInstallDir();
    }
    static load() {
        const configPath = getConfigFilePath();
        if (fs.existsSync(configPath)) {
            try {
                const content = fs.readFileSync(configPath, 'utf-8');
                const data = JSON.parse(content);
                const config = new Config();
                Object.assign(config, data);
                // Convert paused_downloads object to Map
                if (data.paused_downloads && typeof data.paused_downloads === 'object') {
                    config.paused_downloads = new Map(Object.entries(data.paused_downloads).map(([k, v]) => [k, v]));
                }
                return config;
            }
            catch (e) {
                return new Config();
            }
        }
        return new Config();
    }
    static loadFromDb() {
        // Will be implemented when database module is ready
        const config = new Config();
        // Load from database using get_config_value
        return config;
    }
    save() {
        this.saveToFile();
        this.saveToDb();
    }
    saveToFile() {
        const configPath = getConfigFilePath();
        const dir = path.dirname(configPath);
        if (!fs.existsSync(dir)) {
            fs.mkdirSync(dir, { recursive: true });
        }
        // Convert Map to object for JSON serialization
        const data = { ...this };
        data.paused_downloads = Object.fromEntries(this.paused_downloads);
        const content = JSON.stringify(data, null, 2);
        fs.writeFileSync(configPath, content, 'utf-8');
    }
    saveToDb() {
        // Will be implemented when database module is ready
    }
    addOngoingDownload(downloadId) {
        if (!this.current_downloads.includes(downloadId)) {
            this.current_downloads.push(downloadId);
        }
    }
    removeOngoingDownload(downloadId) {
        this.current_downloads = this.current_downloads.filter(id => id !== downloadId);
    }
    addPausedDownload(saveLocation, progress) {
        this.paused_downloads.set(saveLocation, progress);
    }
    removePausedDownload(saveLocation) {
        this.paused_downloads.delete(saveLocation);
    }
    toDto() {
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
exports.Config = Config;
function getDefaultInstallDir() {
    const homeDir = os.homedir();
    return path.join(homeDir, 'GOG Games');
}
function getConfigFilePath() {
    const configDir = process.env.XDG_CONFIG_HOME || path.join(os.homedir(), '.config');
    return path.join(configDir, 'galaxi', 'config.json');
}
function getDataDir() {
    const dataDir = process.env.XDG_DATA_HOME || path.join(os.homedir(), '.local', 'share');
    return path.join(dataDir, 'galaxi');
}
function getCacheDir() {
    const cacheDir = process.env.XDG_CACHE_HOME || path.join(os.homedir(), '.cache');
    return path.join(cacheDir, 'galaxi');
}
function getIconDir() {
    return path.join(getCacheDir(), 'icons');
}
function getThumbnailDir() {
    return path.join(getCacheDir(), 'thumbnails');
}
function getConfigGamesDir() {
    return path.join(getDataDir(), 'games');
}
//# sourceMappingURL=config.js.map