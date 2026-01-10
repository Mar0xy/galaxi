import { Game } from './game';
import { DownloadManager } from './download';
export interface WineOptions {
    prefix: string;
    executable: string;
    debug: boolean;
    disable_ntsync: boolean;
    auto_install_dxvk: boolean;
}
export declare class GameInstaller {
    private downloadManager;
    constructor(downloadManager: DownloadManager);
    installGame(game: Game, downloadUrl: string, installDir: string, wineOptions?: WineOptions): Promise<void>;
    private runLinuxInstaller;
    private runWindowsInstaller;
    private installDxvk;
}
//# sourceMappingURL=installer.d.ts.map