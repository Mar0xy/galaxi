import axios, { AxiosInstance } from 'axios';
import { Config, IGNORE_GAME_IDS } from './config';
import { GalaxiError, GalaxiErrorType } from './error';
import { Game, Dlc } from './game';

// GOG API constants
const REDIRECT_URI = 'https://embed.gog.com/on_login_success?origin=client';
const CLIENT_ID = '46899977096215655';
const CLIENT_SECRET = '9d85c43b1482497dbbce61f6e4aa173a433796eeae2ca8c5f6129f2dc4de46d9';

// Types
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

interface LibraryResponse {
  totalPages: number;
  products: ProductInfo[];
}

interface ProductInfo {
  id: number;
  title: string;
  url?: string;
  image: string;
  worksOn: WorksOn;
  category: string;
}

interface WorksOn {
  Linux: boolean;
  Windows: boolean;
  Mac: boolean;
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

interface RealDownloadLinkResponse {
  downlink: string;
  checksum?: string;
}

export class GogApi {
  private config: Config;
  private client: AxiosInstance;
  private activeToken?: string;
  private tokenExpiration: number = 0;

  constructor(config: Config) {
    this.config = config;
    this.client = axios.create({
      timeout: 30000,
    });
  }

  static getLoginUrl(): string {
    return `https://auth.gog.com/auth?client_id=${CLIENT_ID}&redirect_uri=${encodeURIComponent(REDIRECT_URI)}&response_type=code&layout=client2`;
  }

  static getRedirectUrl(): string {
    return REDIRECT_URI;
  }

  static getSuccessUrl(): string {
    return 'https://embed.gog.com/on_login_success';
  }

  async authenticate(loginCode?: string, refreshToken?: string): Promise<string> {
    if (refreshToken) {
      return await this.refreshToken(refreshToken);
    } else if (loginCode) {
      return await this.getToken(loginCode);
    } else {
      throw new GalaxiError('No authentication method provided', GalaxiErrorType.AuthError);
    }
  }

  private async refreshToken(refreshToken: string): Promise<string> {
    const params = {
      client_id: CLIENT_ID,
      client_secret: CLIENT_SECRET,
      grant_type: 'refresh_token',
      refresh_token: refreshToken,
    };
    return await this.fetchToken(params);
  }

  private async getToken(loginCode: string): Promise<string> {
    const params = {
      client_id: CLIENT_ID,
      client_secret: CLIENT_SECRET,
      grant_type: 'authorization_code',
      code: loginCode,
      redirect_uri: REDIRECT_URI,
    };
    return await this.fetchToken(params);
  }

  private async fetchToken(params: Record<string, string>): Promise<string> {
    try {
      const response = await this.client.get<TokenResponse>('https://auth.gog.com/token', { params });
      
      this.activeToken = response.data.access_token;
      const now = Math.floor(Date.now() / 1000);
      this.tokenExpiration = now + response.data.expires_in;

      return response.data.refresh_token;
    } catch (error: any) {
      throw new GalaxiError(
        `Authentication failed: ${error.message}`,
        GalaxiErrorType.AuthError
      );
    }
  }

  private async request<T>(url: string): Promise<T> {
    if (!this.activeToken) {
      throw new GalaxiError('Not authenticated', GalaxiErrorType.AuthError);
    }

    try {
      const response = await this.client.get<T>(url, {
        headers: {
          Authorization: `Bearer ${this.activeToken}`,
        },
      });
      return response.data;
    } catch (error: any) {
      throw new GalaxiError(
        `Network error: ${error.message}`,
        GalaxiErrorType.NetworkError
      );
    }
  }

  async getLibrary(): Promise<Game[]> {
    const games: Game[] = [];
    let currentPage = 1;

    while (true) {
      const url = `https://embed.gog.com/account/getFilteredProducts?mediaType=1&page=${currentPage}`;
      const response = await this.request<LibraryResponse>(url);

      for (const product of response.products) {
        if (IGNORE_GAME_IDS.includes(product.id)) {
          continue;
        }

        const platform = product.worksOn.Linux ? 'linux' : 'windows';

        const game = new Game(
          product.title,
          product.url || '',
          product.id,
          '',
          product.image,
          platform,
          product.category
        );
        games.push(game);
      }

      if (currentPage >= response.totalPages) {
        break;
      }
      currentPage++;
    }

    return games;
  }

  async getInfo(game: Game): Promise<GameInfoResponse> {
    const url = `https://api.gog.com/products/${game.id}?locale=en-US&expand=downloads,expanded_dlcs,description,screenshots,videos,related_products,changelog`;
    return await this.request<GameInfoResponse>(url);
  }

  async getUserInfo(): Promise<UserData> {
    return await this.request<UserData>('https://embed.gog.com/userData.json');
  }

  async getUserProfile(userId: string): Promise<UserProfile> {
    const url = `https://embed.gog.com/users/info/${userId}`;
    return await this.request<UserProfile>(url);
  }

  async getGamesDbInfo(gameId: number): Promise<GamesDbInfo> {
    const url = `https://gamesdb.gog.com/platforms/gog/external_releases/${gameId}`;
    const response = await this.request<any>(url);
    
    const info: GamesDbInfo = {
      cover: '',
      vertical_cover: '',
      background: '',
      summary: {},
      genre: {},
    };
    
    // Parse nested game data structure
    if (response.game) {
      const gameData = response.game;
      
      // Extract cover URL
      if (gameData.cover && gameData.cover.url_format) {
        info.cover = gameData.cover.url_format.replace('{formatter}.{ext}', '.png');
      }
      
      // Extract vertical cover URL
      if (gameData.vertical_cover && gameData.vertical_cover.url_format) {
        info.vertical_cover = gameData.vertical_cover.url_format.replace('{formatter}.{ext}', '.png');
      }
      
      // Extract background URL
      if (gameData.background && gameData.background.url_format) {
        info.background = gameData.background.url_format.replace('{formatter}.{ext}', '.png');
      }
      
      // Extract summary (localized strings)
      if (gameData.summary && typeof gameData.summary === 'object') {
        info.summary = gameData.summary;
      }
      
      // Extract genre (localized strings)
      if (gameData.genre && typeof gameData.genre === 'object') {
        info.genre = gameData.genre;
      }
    }
    
    return info;
  }

  async getDownloadLink(downlink: string): Promise<string> {
    try {
      // Ensure downlink is a valid URL
      if (!downlink || downlink.trim() === '') {
        throw new Error('Invalid URL: downlink is empty');
      }
      
      // If downlink is a relative path, prepend the GOG API base URL
      let url = downlink;
      if (!downlink.startsWith('http://') && !downlink.startsWith('https://')) {
        url = `https://api.gog.com${downlink}`;
      }
      
      console.log('Fetching download link from:', url);
      const response = await this.request<RealDownloadLinkResponse>(url);
      console.log('Got download link:', response.downlink);
      return response.downlink;
    } catch (error: any) {
      console.error('Failed to get download link for:', downlink, 'Error:', error.message);
      throw new GalaxiError(
        `Failed to get download link: ${error.message}`,
        GalaxiErrorType.DownloadError
      );
    }
  }

  getActiveToken(): string | undefined {
    return this.activeToken;
  }

  isTokenExpired(): boolean {
    const now = Math.floor(Date.now() / 1000);
    return now >= this.tokenExpiration;
  }
}
