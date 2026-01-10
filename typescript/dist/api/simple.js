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
var __exportStar = (this && this.__exportStar) || function(m, exports) {
    for (var p in m) if (p !== "default" && !Object.prototype.hasOwnProperty.call(exports, p)) __createBinding(exports, m, p);
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.greet = greet;
exports.initApp = initApp;
exports.getLoginUrl = getLoginUrl;
exports.getRedirectUrl = getRedirectUrl;
exports.getSuccessUrl = getSuccessUrl;
exports.authenticate = authenticate;
exports.loginWithCode = loginWithCode;
exports.isLoggedIn = isLoggedIn;
exports.logout = logout;
exports.getUserData = getUserData;
exports.getAllAccounts = getAllAccounts;
exports.getActiveAccount = getActiveAccount;
exports.addCurrentAccount = addCurrentAccount;
exports.switchAccount = switchAccount;
exports.removeAccount = removeAccount;
exports.getLibrary = getLibrary;
exports.getGameInfo = getGameInfo;
exports.getGamesDbInfo = getGamesDbInfo;
exports.installGame = installGame;
exports.launchGameById = launchGameById;
exports.getConfig = getConfig;
exports.setConfigValue = setConfigValue;
exports.getDarkTheme = getDarkTheme;
exports.setDarkTheme = setDarkTheme;
const config_1 = require("./config");
const gog_api_1 = require("./gog_api");
const download_1 = require("./download");
const installer_1 = require("./installer");
const account_1 = require("./account");
const launcher_1 = require("./launcher");
const database_1 = require("./database");
const error_1 = require("./error");
// Application state
class AppState {
    constructor() {
        this.gamesCache = new Map();
        // Initialize database first
        try {
            (0, database_1.initDatabase)();
        }
        catch (error) {
            console.error('Failed to initialize database:', error);
        }
        // Load config from database or file
        this.config = config_1.Config.load();
        this.downloadManager = new download_1.DownloadManager();
        this.installer = new installer_1.GameInstaller(this.downloadManager);
    }
}
const APP_STATE = new AppState();
// ============================================================================
// Simple API functions
// ============================================================================
function greet(name) {
    return `Hello, ${name}!`;
}
function initApp() {
    console.log('Galaxi backend initialized');
}
// ============================================================================
// Authentication API
// ============================================================================
function getLoginUrl() {
    return gog_api_1.GogApi.getLoginUrl();
}
function getRedirectUrl() {
    return gog_api_1.GogApi.getRedirectUrl();
}
function getSuccessUrl() {
    return gog_api_1.GogApi.getSuccessUrl();
}
async function authenticate(loginCode, refreshToken) {
    const api = new gog_api_1.GogApi(APP_STATE.config);
    const newRefreshToken = await api.authenticate(loginCode, refreshToken);
    APP_STATE.api = api;
    APP_STATE.config.refresh_token = newRefreshToken;
    APP_STATE.config.save();
    return newRefreshToken;
}
async function loginWithCode(code) {
    const refreshToken = await authenticate(code, undefined);
    const account = await addCurrentAccount(refreshToken);
    return account;
}
async function isLoggedIn() {
    return APP_STATE.api !== undefined;
}
async function logout() {
    APP_STATE.api = undefined;
    APP_STATE.config.refresh_token = '';
    APP_STATE.config.username = '';
    APP_STATE.config.save();
}
async function getUserData() {
    if (!APP_STATE.api) {
        throw new error_1.GalaxiError('Not authenticated', error_1.GalaxiErrorType.AuthError);
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
async function getAllAccounts() {
    return (0, database_1.accountsDb)().getAllAccounts();
}
async function getActiveAccount() {
    return (0, database_1.accountsDb)().getActiveAccount();
}
async function addCurrentAccount(refreshToken) {
    if (!APP_STATE.api) {
        throw new error_1.GalaxiError('Not authenticated', error_1.GalaxiErrorType.AuthError);
    }
    const userData = await APP_STATE.api.getUserInfo();
    const avatar = await (0, account_1.fetchUserAvatar)(APP_STATE.api, userData.userId);
    const account = {
        user_id: userData.userId,
        username: userData.username,
        refresh_token: refreshToken,
        avatar_url: avatar,
    };
    // Save to database
    (0, database_1.accountsDb)().addAccount(account);
    // Set as active account
    (0, database_1.accountsDb)().setActiveAccount(account.user_id);
    // Update config
    APP_STATE.config.active_account_id = account.user_id;
    APP_STATE.config.username = account.username;
    APP_STATE.config.save();
    return account;
}
async function switchAccount(userId) {
    const account = (0, database_1.accountsDb)().getAccount(userId);
    if (account) {
        await authenticate(undefined, account.refresh_token);
        (0, database_1.accountsDb)().setActiveAccount(userId);
        return true;
    }
    return false;
}
async function removeAccount(userId) {
    (0, database_1.accountsDb)().removeAccount(userId);
}
// ============================================================================
// Library API
// ============================================================================
async function getLibrary() {
    if (!APP_STATE.api) {
        throw new error_1.GalaxiError('Not authenticated', error_1.GalaxiErrorType.AuthError);
    }
    const games = await APP_STATE.api.getLibrary();
    // Load existing games from database to preserve install_dir
    const existingGames = (0, database_1.gamesDb)().getAllGames();
    const existingMap = new Map(existingGames.map(g => [g.id, g]));
    // Update cache and database
    for (const game of games) {
        // Preserve install_dir from existing database record
        const existing = existingMap.get(game.id);
        if (existing && existing.install_dir) {
            game.install_dir = existing.install_dir;
        }
        APP_STATE.gamesCache.set(game.id, game);
        const gameDto = {
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
        (0, database_1.gamesDb)().saveGame(gameDto);
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
async function getGameInfo(gameId) {
    if (!APP_STATE.api) {
        throw new error_1.GalaxiError('Not authenticated', error_1.GalaxiErrorType.AuthError);
    }
    const game = APP_STATE.gamesCache.get(gameId);
    if (!game) {
        throw new error_1.GalaxiError('Game not found in cache', error_1.GalaxiErrorType.NotFoundError);
    }
    const info = await APP_STATE.api.getInfo(game);
    const screenshots = info.screenshots?.map(s => s.formatter_template_url.replace('{formatter}', 'product_card_v2_mobile_slider_639')) || [];
    return {
        id: info.id,
        title: info.title,
        description: info.description?.full,
        changelog: info.changelog,
        screenshots,
    };
}
async function getGamesDbInfo(gameId) {
    if (!APP_STATE.api) {
        throw new error_1.GalaxiError('Not authenticated', error_1.GalaxiErrorType.AuthError);
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
async function installGame(gameId, installerUrl) {
    const game = APP_STATE.gamesCache.get(gameId);
    if (!game) {
        throw new error_1.GalaxiError('Game not found', error_1.GalaxiErrorType.NotFoundError);
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
    (0, database_1.gamesDb)().saveGame({
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
async function launchGameById(gameId) {
    const game = APP_STATE.gamesCache.get(gameId);
    if (!game) {
        throw new error_1.GalaxiError('Game not found', error_1.GalaxiErrorType.NotFoundError);
    }
    const wineOptions = {
        wine_prefix: APP_STATE.config.wine_prefix || `${game.install_dir}/wine_prefix`,
        wine_executable: APP_STATE.config.wine_executable,
        wine_debug: APP_STATE.config.wine_debug,
        wine_disable_ntsync: APP_STATE.config.wine_disable_ntsync,
    };
    const result = await (0, launcher_1.launchGame)(game, game.platform === 'windows' ? wineOptions : undefined);
    return result;
}
// ============================================================================
// Config API
// ============================================================================
async function getConfig() {
    return APP_STATE.config.toDto();
}
async function setConfigValue(key, value) {
    APP_STATE.config[key] = value;
    APP_STATE.config.save();
}
async function getDarkTheme() {
    return APP_STATE.config.use_dark_theme;
}
async function setDarkTheme(value) {
    APP_STATE.config.use_dark_theme = value;
    APP_STATE.config.save();
}
// Export types
__exportStar(require("./dto"), exports);
__exportStar(require("./error"), exports);
//# sourceMappingURL=simple.js.map