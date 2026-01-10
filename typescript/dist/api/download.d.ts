import { Game } from './game';
export declare enum DownloadStatus {
    Downloading = "Downloading",
    Paused = "Paused",
    Completed = "Completed",
    Failed = "Failed"
}
export interface DownloadProgress {
    game_id: number;
    file_name: string;
    downloaded: number;
    total: number;
    status: DownloadStatus;
}
export declare class DownloadManager {
    private downloads;
    downloadFile(game: Game, url: string, destination: string, onProgress?: (progress: DownloadProgress) => void): Promise<void>;
    getProgress(gameId: number): DownloadProgress | undefined;
    pauseDownload(gameId: number): void;
    resumeDownload(gameId: number): void;
    cancelDownload(gameId: number): void;
}
//# sourceMappingURL=download.d.ts.map