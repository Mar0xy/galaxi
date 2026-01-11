import Database from 'better-sqlite3';
import * as path from 'path';
import * as fs from 'fs';
import { getDataDir } from './config';
import { GalaxiError, GalaxiErrorType } from './error';
import { AccountDto, GameDto } from './dto';

let db: Database.Database | null = null;

export function getDbPath(): string {
  return path.join(getDataDir(), 'galaxi.db');
}

export function initDatabase(): void {
  const dbPath = getDbPath();
  
  // Ensure directory exists
  const dir = path.dirname(dbPath);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
  
  db = new Database(dbPath);
  
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
    
    -- Game playtime tracking table
    CREATE TABLE IF NOT EXISTS game_playtime (
      game_id INTEGER PRIMARY KEY,
      total_playtime_seconds INTEGER DEFAULT 0,
      last_played TEXT,
      FOREIGN KEY (game_id) REFERENCES games(id)
    );
  `);
  
  // Insert default config values if not exists
  const defaultInstallDir = path.join(require('os').homedir(), 'GOG Games');
  
  const defaults: [string, string][] = [
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

function getDb(): Database.Database {
  if (!db) {
    throw new GalaxiError('Database not initialized', GalaxiErrorType.ConfigError);
  }
  return db;
}

export function getConfigValue(key: string): string {
  const db = getDb();
  const row = db.prepare('SELECT value FROM config WHERE key = ?').get(key) as { value: string } | undefined;
  if (!row) {
    throw new GalaxiError(`Config key not found: ${key}`, GalaxiErrorType.ConfigError);
  }
  return row.value;
}

export function setConfigValue(key: string, value: string): void {
  const db = getDb();
  db.prepare('INSERT OR REPLACE INTO config (key, value) VALUES (?, ?)').run(key, value);
}

// Account management
export function accountsDb() {
  return {
    addAccount(account: AccountDto): void {
      const db = getDb();
      const now = new Date().toISOString();
      db.prepare(`
        INSERT OR REPLACE INTO accounts 
        (user_id, username, email, avatar_url, refresh_token, added_at, last_login, is_active)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      `).run(
        account.user_id,
        account.username,
        null,
        account.avatar_url || null,
        account.refresh_token,
        now,
        now,
        1
      );
    },

    getAccount(userId: string): AccountDto | null {
      const db = getDb();
      const row = db.prepare(`
        SELECT user_id, username, email, avatar_url, refresh_token, is_active
        FROM accounts WHERE user_id = ?
      `).get(userId) as any;
      
      if (!row) return null;
      
      return {
        user_id: row.user_id,
        username: row.username,
        avatar_url: row.avatar_url,
        refresh_token: row.refresh_token,
      };
    },

    getAllAccounts(): AccountDto[] {
      const db = getDb();
      const rows = db.prepare(`
        SELECT user_id, username, email, avatar_url, refresh_token, is_active
        FROM accounts ORDER BY added_at DESC
      `).all() as any[];
      
      return rows.map(row => ({
        user_id: row.user_id,
        username: row.username,
        avatar_url: row.avatar_url,
        refresh_token: row.refresh_token,
      }));
    },

    getActiveAccount(): AccountDto | null {
      const db = getDb();
      const row = db.prepare(`
        SELECT user_id, username, email, avatar_url, refresh_token
        FROM accounts WHERE is_active = 1
      `).get() as any;
      
      if (!row) return null;
      
      return {
        user_id: row.user_id,
        username: row.username,
        avatar_url: row.avatar_url,
        refresh_token: row.refresh_token,
      };
    },

    setActiveAccount(userId: string): void {
      const db = getDb();
      db.prepare('UPDATE accounts SET is_active = 0').run();
      db.prepare('UPDATE accounts SET is_active = 1 WHERE user_id = ?').run(userId);
    },

    removeAccount(userId: string): void {
      const db = getDb();
      db.prepare('DELETE FROM accounts WHERE user_id = ?').run(userId);
    },

    updateAvatar(userId: string, avatarUrl: string): void {
      const db = getDb();
      db.prepare('UPDATE accounts SET avatar_url = ? WHERE user_id = ?').run(avatarUrl, userId);
    },
  };
}

// Game management
export function gamesDb() {
  return {
    saveGame(game: GameDto): void {
      const db = getDb();
      const now = new Date().toISOString();
      db.prepare(`
        INSERT OR REPLACE INTO games 
        (id, name, url, install_dir, image_url, platform, category, last_updated)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      `).run(
        game.id,
        game.name,
        game.url,
        game.install_dir,
        game.image_url,
        game.platform,
        game.category,
        now
      );
      
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

    getGame(gameId: number): GameDto | null {
      const db = getDb();
      const row = db.prepare(`
        SELECT id, name, url, install_dir, image_url, platform, category
        FROM games WHERE id = ?
      `).get(gameId) as any;
      
      if (!row) return null;
      
      const dlcs = db.prepare(`
        SELECT id, name, title, image_url
        FROM dlcs WHERE game_id = ?
      `).all(gameId) as any[];
      
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

    getAllGames(): GameDto[] {
      const db = getDb();
      const rows = db.prepare(`
        SELECT id, name, url, install_dir, image_url, platform, category
        FROM games ORDER BY name
      `).all() as any[];
      
      return rows.map(row => {
        const dlcs = db.prepare(`
          SELECT id, name, title, image_url
          FROM dlcs WHERE game_id = ?
        `).all(row.id) as any[];
        
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

    clearGames(): void {
      const db = getDb();
      db.prepare('DELETE FROM games').run();
      db.prepare('DELETE FROM dlcs').run();
    },
  };
}

// Playtime tracking
export function playtimeDb() {
  return {
    savePlaytime(gameId: number, sessionDurationSeconds: number): void {
      const db = getDb();
      const now = new Date().toISOString();
      
      // Get current playtime
      const currentRow = db.prepare(
        'SELECT total_playtime_seconds FROM game_playtime WHERE game_id = ?'
      ).get(gameId) as { total_playtime_seconds: number } | undefined;
      
      const currentTotal = currentRow?.total_playtime_seconds || 0;
      const newTotal = currentTotal + sessionDurationSeconds;
      
      // Insert or update
      db.prepare(`
        INSERT INTO game_playtime (game_id, total_playtime_seconds, last_played)
        VALUES (?, ?, ?)
        ON CONFLICT(game_id) DO UPDATE SET
          total_playtime_seconds = ?,
          last_played = ?
      `).run(gameId, newTotal, now, newTotal, now);
    },
    
    getTotalPlaytime(gameId: number): number {
      const db = getDb();
      const row = db.prepare(
        'SELECT total_playtime_seconds FROM game_playtime WHERE game_id = ?'
      ).get(gameId) as { total_playtime_seconds: number } | undefined;
      
      return row?.total_playtime_seconds || 0;
    },
  };
}

export function closeDatabase(): void {
  if (db) {
    db.close();
    db = null;
  }
}
