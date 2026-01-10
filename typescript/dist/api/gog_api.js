"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.GogApi = void 0;
const axios_1 = __importDefault(require("axios"));
const config_1 = require("./config");
const error_1 = require("./error");
const game_1 = require("./game");
// GOG API constants
const REDIRECT_URI = 'https://embed.gog.com/on_login_success?origin=client';
const CLIENT_ID = '46899977096215655';
const CLIENT_SECRET = '9d85c43b1482497dbbce61f6e4aa173a433796eeae2ca8c5f6129f2dc4de46d9';
class GogApi {
    constructor(config) {
        this.tokenExpiration = 0;
        this.config = config;
        this.client = axios_1.default.create({
            timeout: 30000,
        });
    }
    static getLoginUrl() {
        return `https://auth.gog.com/auth?client_id=${CLIENT_ID}&redirect_uri=${encodeURIComponent(REDIRECT_URI)}&response_type=code&layout=client2`;
    }
    static getRedirectUrl() {
        return REDIRECT_URI;
    }
    static getSuccessUrl() {
        return 'https://embed.gog.com/on_login_success';
    }
    async authenticate(loginCode, refreshToken) {
        if (refreshToken) {
            return await this.refreshToken(refreshToken);
        }
        else if (loginCode) {
            return await this.getToken(loginCode);
        }
        else {
            throw new error_1.GalaxiError('No authentication method provided', error_1.GalaxiErrorType.AuthError);
        }
    }
    async refreshToken(refreshToken) {
        const params = {
            client_id: CLIENT_ID,
            client_secret: CLIENT_SECRET,
            grant_type: 'refresh_token',
            refresh_token: refreshToken,
        };
        return await this.fetchToken(params);
    }
    async getToken(loginCode) {
        const params = {
            client_id: CLIENT_ID,
            client_secret: CLIENT_SECRET,
            grant_type: 'authorization_code',
            code: loginCode,
            redirect_uri: REDIRECT_URI,
        };
        return await this.fetchToken(params);
    }
    async fetchToken(params) {
        try {
            const response = await this.client.get('https://auth.gog.com/token', { params });
            this.activeToken = response.data.access_token;
            const now = Math.floor(Date.now() / 1000);
            this.tokenExpiration = now + response.data.expires_in;
            return response.data.refresh_token;
        }
        catch (error) {
            throw new error_1.GalaxiError(`Authentication failed: ${error.message}`, error_1.GalaxiErrorType.AuthError);
        }
    }
    async request(url) {
        if (!this.activeToken) {
            throw new error_1.GalaxiError('Not authenticated', error_1.GalaxiErrorType.AuthError);
        }
        try {
            const response = await this.client.get(url, {
                headers: {
                    Authorization: `Bearer ${this.activeToken}`,
                },
            });
            return response.data;
        }
        catch (error) {
            throw new error_1.GalaxiError(`Network error: ${error.message}`, error_1.GalaxiErrorType.NetworkError);
        }
    }
    async getLibrary() {
        const games = [];
        let currentPage = 1;
        while (true) {
            const url = `https://embed.gog.com/account/getFilteredProducts?mediaType=1&page=${currentPage}`;
            const response = await this.request(url);
            for (const product of response.products) {
                if (config_1.IGNORE_GAME_IDS.includes(product.id)) {
                    continue;
                }
                const platform = product.worksOn.Linux ? 'linux' : 'windows';
                const game = new game_1.Game(product.title, product.url || '', product.id, '', product.image, platform, product.category);
                games.push(game);
            }
            if (currentPage >= response.totalPages) {
                break;
            }
            currentPage++;
        }
        return games;
    }
    async getInfo(game) {
        const url = `https://api.gog.com/products/${game.id}?locale=en-US&expand=downloads,expanded_dlcs,description,screenshots,videos,related_products,changelog`;
        return await this.request(url);
    }
    async getUserInfo() {
        return await this.request('https://embed.gog.com/userData.json');
    }
    async getUserProfile(userId) {
        const url = `https://embed.gog.com/users/info/${userId}`;
        return await this.request(url);
    }
    async getGamesDbInfo(gameId) {
        const url = `https://gamesdb.gog.com/platforms/gog/external_releases/${gameId}`;
        return await this.request(url);
    }
    async getDownloadLink(downlink) {
        try {
            const response = await this.request(downlink);
            return response.downlink;
        }
        catch (error) {
            throw new error_1.GalaxiError(`Failed to get download link: ${error.message}`, error_1.GalaxiErrorType.DownloadError);
        }
    }
    getActiveToken() {
        return this.activeToken;
    }
    isTokenExpired() {
        const now = Math.floor(Date.now() / 1000);
        return now >= this.tokenExpiration;
    }
}
exports.GogApi = GogApi;
//# sourceMappingURL=gog_api.js.map