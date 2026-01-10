import { Config } from './config';
import { Game } from './game';
export interface TokenResponse {
    access_token: string;
    expires_in: number;
    refresh_token: string;
}
export interface UserData {
    userId: string;
    username: string;
    galaxyUserId?: string;
    email?: string;
    avatar?: string;
    isLoggedIn: boolean;
}
export interface UserProfile {
    id: string;
    username: string;
    created_date?: string;
    avatars?: UserAvatars;
}
export interface UserAvatars {
    small?: string;
    small2x?: string;
    medium?: string;
    medium2x?: string;
    large?: string;
    large2x?: string;
}
export interface GameInfoResponse {
    id: number;
    title: string;
    description?: GameDescription;
    downloads?: GameDownloads;
    expanded_dlcs?: ExpandedDlc[];
    changelog?: string;
    screenshots?: Screenshot[];
}
export interface Screenshot {
    image_id: string;
    formatter_template_url: string;
}
export interface GameDescription {
    lead?: string;
    full?: string;
}
export interface GameDownloads {
    installers: Installer[];
}
export interface Installer {
    id: string;
    name: string;
    os: string;
    language: string;
    version?: string;
    files: InstallerFile[];
}
export interface InstallerFile {
    id: string;
    size: number;
    downlink: string;
}
export interface ExpandedDlc {
    id: number;
    title: string;
    downloads?: GameDownloads;
}
export interface GamesDbInfo {
    cover: string;
    vertical_cover: string;
    background: string;
    summary: Record<string, string>;
    genre: Record<string, string>;
}
export interface DownloadInfo {
    os: string;
    language: string;
    version?: string;
    total_size: number;
    files: DownloadFile[];
}
export interface DownloadFile {
    size: number;
    downlink: string;
}
export declare class GogApi {
    private config;
    private client;
    private activeToken?;
    private tokenExpiration;
    constructor(config: Config);
    static getLoginUrl(): string;
    static getRedirectUrl(): string;
    static getSuccessUrl(): string;
    authenticate(loginCode?: string, refreshToken?: string): Promise<string>;
    private refreshToken;
    private getToken;
    private fetchToken;
    private request;
    getLibrary(): Promise<Game[]>;
    getInfo(game: Game): Promise<GameInfoResponse>;
    getUserInfo(): Promise<UserData>;
    getUserProfile(userId: string): Promise<UserProfile>;
    getGamesDbInfo(gameId: number): Promise<GamesDbInfo>;
    getDownloadLink(downlink: string): Promise<string>;
    getActiveToken(): string | undefined;
    isTokenExpired(): boolean;
}
//# sourceMappingURL=gog_api.d.ts.map