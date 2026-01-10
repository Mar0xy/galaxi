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
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.getDbPath = getDbPath;
exports.initDatabase = initDatabase;
exports.getConfigValue = getConfigValue;
exports.setConfigValue = setConfigValue;
exports.accountsDb = accountsDb;
exports.gamesDb = gamesDb;
exports.closeDatabase = closeDatabase;
const better_sqlite3_1 = __importDefault(require("better-sqlite3"));
const path = __importStar(require("path"));
const fs = __importStar(require("fs"));
const config_1 = require("./config");
const error_1 = require("./error");
let db = null;
function getDbPath() {
    return path.join((0, config_1.getDataDir)(), 'galaxi.db');
}
function initDatabase() {
    const dbPath = getDbPath();
    // Ensure directory exists
    const dir = path.dirname(dbPath);
    if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
    }
    db = new better_sqlite3_1.default(dbPath);
    // Create tables
    db.exec(`
    -- Configuration table
    CREATE TABLE IF NOT EXISTS config (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    );
    
    -- Accounts table
    CREATE TABLE IF NOT EXISTS accounts (
      user_id TEXT PRIMARY KEY,
      username TEXT NOT NULL,
      email TEXT,
      avatar_url TEXT,
      refresh_token TEXT NOT NULL,
      added_at TEXT NOT NULL,
      last_login TEXT,
      is_active INTEGER DEFAULT 0
    );
    
    -- Games cache table
    CREATE TABLE IF NOT EXISTS games (
      id INTEGER PRIMARY KEY,
      name TEXT NOT NULL,
      url TEXT,
      install_dir TEXT,
      image_url TEXT,
      platform TEXT,
      category TEXT,
      version TEXT,
      last_updated TEXT
    );
    
    -- Downloads table
    CREATE TABLE IF NOT EXISTS downloads (
      game_id INTEGER PRIMARY KEY,
      status TEXT NOT NULL,
      progress REAL DEFAULT 0,
      paused_at TEXT
    );
    
    -- DLCs table
    CREATE TABLE IF NOT EXISTS dlcs (
      id INTEGER PRIMARY KEY,
      game_id INTEGER NOT NULL,
      name TEXT NOT NULL,
      title TEXT,
      image_url TEXT,
      installed INTEGER DEFAULT 0,
      FOREIGN KEY (game_id) REFERENCES games(id)
    );
  `);
    // Insert default config values if not exists
    const defaultInstallDir = path.join(require('os').homedir(), 'GOG Games');
    const defaults = [
        ['locale', ''],
        ['lang', 'en'],
        ['view', 'grid'],
        ['install_dir', defaultInstallDir],
        ['keep_installers', 'false'],
        ['stay_logged_in', 'true'],
        ['use_dark_theme', 'false'],
        ['show_hidden_games', 'false'],
        ['show_windows_games', 'false'],
        ['wine_prefix', ''],
        ['wine_executable', ''],
        ['wine_debug', 'false'],
        ['wine_disable_ntsync', 'false'],
        ['wine_auto_install_dxvk', 'true'],
    ];
    const insertStmt = db.prepare('INSERT OR IGNORE INTO config (key, value) VALUES (?, ?)');
    for (const [key, value] of defaults) {
        insertStmt.run(key, value);
    }
}
function getDb() {
    if (!db) {
        throw new error_1.GalaxiError('Database not initialized', error_1.GalaxiErrorType.ConfigError);
    }
    return db;
}
function getConfigValue(key) {
    const db = getDb();
    const row = db.prepare('SELECT value FROM config WHERE key = ?').get(key);
    if (!row) {
        throw new error_1.GalaxiError(`Config key not found: ${key}`, error_1.GalaxiErrorType.ConfigError);
    }
    return row.value;
}
function setConfigValue(key, value) {
    const db = getDb();
    db.prepare('INSERT OR REPLACE INTO config (key, value) VALUES (?, ?)').run(key, value);
}
// Account management
function accountsDb() {
    return {
        addAccount(account) {
            const db = getDb();
            const now = new Date().toISOString();
            db.prepare(`
        INSERT OR REPLACE INTO accounts 
        (user_id, username, email, avatar_url, refresh_token, added_at, last_login, is_active)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      `).run(account.user_id, account.username, null, account.avatar_url || null, account.refresh_token, now, now, 1);
        },
        getAccount(userId) {
            const db = getDb();
            const row = db.prepare(`
        SELECT user_id, username, email, avatar_url, refresh_token, is_active
        FROM accounts WHERE user_id = ?
      `).get(userId);
            if (!row)
                return null;
            return {
                user_id: row.user_id,
                username: row.username,
                avatar_url: row.avatar_url,
                refresh_token: row.refresh_token,
            };
        },
        getAllAccounts() {
            const db = getDb();
            const rows = db.prepare(`
        SELECT user_id, username, email, avatar_url, refresh_token, is_active
        FROM accounts ORDER BY added_at DESC
      `).all();
            return rows.map(row => ({
                user_id: row.user_id,
                username: row.username,
                avatar_url: row.avatar_url,
                refresh_token: row.refresh_token,
            }));
        },
        getActiveAccount() {
            const db = getDb();
            const row = db.prepare(`
        SELECT user_id, username, email, avatar_url, refresh_token
        FROM accounts WHERE is_active = 1
      `).get();
            if (!row)
                return null;
            return {
                user_id: row.user_id,
                username: row.username,
                avatar_url: row.avatar_url,
                refresh_token: row.refresh_token,
            };
        },
        setActiveAccount(userId) {
            const db = getDb();
            db.prepare('UPDATE accounts SET is_active = 0').run();
            db.prepare('UPDATE accounts SET is_active = 1 WHERE user_id = ?').run(userId);
        },
        removeAccount(userId) {
            const db = getDb();
            db.prepare('DELETE FROM accounts WHERE user_id = ?').run(userId);
        },
        updateAvatar(userId, avatarUrl) {
            const db = getDb();
            db.prepare('UPDATE accounts SET avatar_url = ? WHERE user_id = ?').run(avatarUrl, userId);
        },
    };
}
// Game management
function gamesDb() {
    return {
        saveGame(game) {
            const db = getDb();
            const now = new Date().toISOString();
            db.prepare(`
        INSERT OR REPLACE INTO games 
        (id, name, url, install_dir, image_url, platform, category, last_updated)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      `).run(game.id, game.name, game.url, game.install_dir, game.image_url, game.platform, game.category, now);
            // Save DLCs
            db.prepare('DELETE FROM dlcs WHERE game_id = ?').run(game.id);
            const dlcStmt = db.prepare(`
        INSERT INTO dlcs (id, game_id, name, title, image_url)
        VALUES (?, ?, ?, ?, ?)
      `);
            for (const dlc of game.dlcs) {
                dlcStmt.run(dlc.id, game.id, dlc.name, dlc.title, dlc.image_url);
            }
        },
        getGame(gameId) {
            const db = getDb();
            const row = db.prepare(`
        SELECT id, name, url, install_dir, image_url, platform, category
        FROM games WHERE id = ?
      `).get(gameId);
            if (!row)
                return null;
            const dlcs = db.prepare(`
        SELECT id, name, title, image_url
        FROM dlcs WHERE game_id = ?
      `).all(gameId);
            return {
                id: row.id,
                name: row.name,
                url: row.url,
                install_dir: row.install_dir,
                image_url: row.image_url,
                platform: row.platform,
                category: row.category,
                dlcs: dlcs.map(d => ({
                    id: d.id,
                    name: d.name,
                    title: d.title,
                    image_url: d.image_url,
                })),
            };
        },
        getAllGames() {
            const db = getDb();
            const rows = db.prepare(`
        SELECT id, name, url, install_dir, image_url, platform, category
        FROM games ORDER BY name
      `).all();
            return rows.map(row => {
                const dlcs = db.prepare(`
          SELECT id, name, title, image_url
          FROM dlcs WHERE game_id = ?
        `).all(row.id);
                return {
                    id: row.id,
                    name: row.name,
                    url: row.url,
                    install_dir: row.install_dir,
                    image_url: row.image_url,
                    platform: row.platform,
                    category: row.category,
                    dlcs: dlcs.map(d => ({
                        id: d.id,
                        name: d.name,
                        title: d.title,
                        image_url: d.image_url,
                    })),
                };
            });
        },
        clearGames() {
            const db = getDb();
            db.prepare('DELETE FROM games').run();
            db.prepare('DELETE FROM dlcs').run();
        },
    };
}
function closeDatabase() {
    if (db) {
        db.close();
        db = null;
    }
}
//# sourceMappingURL=database.js.map