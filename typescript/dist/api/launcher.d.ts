import { Game } from './game';
export interface WineLaunchOptions {
    wine_prefix: string;
    wine_executable: string;
    wine_debug: boolean;
    wine_disable_ntsync: boolean;
}
export interface LaunchResult {
    success: boolean;
    error_message?: string;
    pid?: number;
}
export declare function launchGame(game: Game, wineOptions?: WineLaunchOptions): Promise<LaunchResult>;
//# sourceMappingURL=launcher.d.ts.map