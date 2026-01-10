import * as fs from 'fs';
import * as path from 'path';
import axios from 'axios';
import { GalaxiError, GalaxiErrorType } from './error';
import { DownloadProgressDto } from './dto';
import { Game } from './game';

export enum DownloadStatus {
  Downloading = 'Downloading',
  Paused = 'Paused',
  Completed = 'Completed',
  Failed = 'Failed',
}

export interface DownloadProgress {
  game_id: number;
  file_name: string;
  downloaded: number;
  total: number;
  status: DownloadStatus;
}

export class DownloadManager {
  private downloads: Map<number, DownloadProgress> = new Map();

  async downloadFile(
    game: Game,
    url: string,
    destination: string,
    onProgress?: (progress: DownloadProgress) => void
  ): Promise<void> {
    const fileName = path.basename(destination);
    
    const progress: DownloadProgress = {
      game_id: game.id,
      file_name: fileName,
      downloaded: 0,
      total: 0,
      status: DownloadStatus.Downloading,
    };

    this.downloads.set(game.id, progress);

    try {
      // Check if file exists and get its size for resume
      let startByte = 0;
      if (fs.existsSync(destination)) {
        startByte = fs.statSync(destination).size;
        progress.downloaded = startByte;
      }

      const response = await axios({
        method: 'GET',
        url,
        responseType: 'stream',
        headers: startByte > 0 ? { Range: `bytes=${startByte}-` } : {},
      });

      progress.total = parseInt(response.headers['content-length'] || '0') + startByte;

      const writer = fs.createWriteStream(destination, { flags: startByte > 0 ? 'a' : 'w' });

      response.data.on('data', (chunk: Buffer) => {
        progress.downloaded += chunk.length;
        if (onProgress) {
          onProgress(progress);
        }
      });

      await new Promise<void>((resolve, reject) => {
        writer.on('finish', resolve);
        writer.on('error', reject);
        response.data.pipe(writer);
      });

      progress.status = DownloadStatus.Completed;
      if (onProgress) {
        onProgress(progress);
      }
    } catch (error: any) {
      progress.status = DownloadStatus.Failed;
      if (onProgress) {
        onProgress(progress);
      }
      throw new GalaxiError(
        `Download failed: ${error.message}`,
        GalaxiErrorType.DownloadError
      );
    }
  }

  getProgress(gameId: number): DownloadProgress | undefined {
    return this.downloads.get(gameId);
  }

  pauseDownload(gameId: number): void {
    const progress = this.downloads.get(gameId);
    if (progress) {
      progress.status = DownloadStatus.Paused;
    }
  }

  resumeDownload(gameId: number): void {
    const progress = this.downloads.get(gameId);
    if (progress) {
      progress.status = DownloadStatus.Downloading;
    }
  }

  cancelDownload(gameId: number): void {
    this.downloads.delete(gameId);
  }
}
