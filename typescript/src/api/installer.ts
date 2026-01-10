import * as fs from 'fs';
import * as path from 'path';
import * as child_process from 'child_process';
import { GalaxiError, GalaxiErrorType } from './error';
import { Game } from './game';
import { DownloadManager } from './download';

export interface WineOptions {
  prefix: string;
  executable: string;
  debug: boolean;
  disable_ntsync: boolean;
  auto_install_dxvk: boolean;
}

export class GameInstaller {
  private downloadManager: DownloadManager;

  constructor(downloadManager: DownloadManager) {
    this.downloadManager = downloadManager;
  }

  async installGame(
    game: Game,
    downloadUrl: string,
    installDir: string,
    wineOptions?: WineOptions
  ): Promise<void> {
    // Create install directory
    if (!fs.existsSync(installDir)) {
      fs.mkdirSync(installDir, { recursive: true });
    }

    // Download installer
    const installerPath = path.join(installDir, `${game.name}_installer.sh`);
    await this.downloadManager.downloadFile(game, downloadUrl, installerPath);

    // Make executable
    fs.chmodSync(installerPath, 0o755);

    // Run installer if it's a Linux game
    if (game.platform === 'linux') {
      await this.runLinuxInstaller(installerPath, installDir);
    } else if (game.platform === 'windows' && wineOptions) {
      await this.runWindowsInstaller(installerPath, installDir, wineOptions);
    }
  }

  private async runLinuxInstaller(installerPath: string, installDir: string): Promise<void> {
    return new Promise((resolve, reject) => {
      const process = child_process.spawn(installerPath, ['--', `--i-agree-to-all-licenses`, `--noreadme`, `--nooptions`, `--noprompt`, `--destination=${installDir}`]);

      process.on('close', (code) => {
        if (code === 0) {
          resolve();
        } else {
          reject(new GalaxiError(
            `Installer exited with code ${code}`,
            GalaxiErrorType.InstallError
          ));
        }
      });

      process.on('error', (err) => {
        reject(new GalaxiError(
          `Installer failed: ${err.message}`,
          GalaxiErrorType.InstallError
        ));
      });
    });
  }

  private async runWindowsInstaller(
    installerPath: string,
    installDir: string,
    wineOptions: WineOptions
  ): Promise<void> {
    // Set up Wine prefix
    const winePrefix = wineOptions.prefix || path.join(installDir, 'wine_prefix');
    if (!fs.existsSync(winePrefix)) {
      fs.mkdirSync(winePrefix, { recursive: true });
    }

    const env: any = {
      ...process.env,
      WINEPREFIX: winePrefix,
    };

    if (wineOptions.disable_ntsync) {
      env.WINE_DISABLE_FAST_SYNC = '1';
    }

    // Auto-install DXVK if requested
    if (wineOptions.auto_install_dxvk) {
      await this.installDxvk(winePrefix, wineOptions.executable);
    }

    return new Promise((resolve, reject) => {
      const wineExec = wineOptions.executable || 'wine';
      const process = child_process.spawn(wineExec, [installerPath, '/SILENT', `/DIR=${installDir}`], { env });

      process.on('close', (code) => {
        if (code === 0) {
          resolve();
        } else {
          reject(new GalaxiError(
            `Wine installer exited with code ${code}`,
            GalaxiErrorType.InstallError
          ));
        }
      });

      process.on('error', (err) => {
        reject(new GalaxiError(
          `Wine installer failed: ${err.message}`,
          GalaxiErrorType.InstallError
        ));
      });
    });
  }

  private async installDxvk(winePrefix: string, wineExecutable: string): Promise<void> {
    // Run winetricks to install DXVK
    return new Promise((resolve, reject) => {
      const env: any = {
        ...process.env,
        WINEPREFIX: winePrefix,
      };

      const proc = child_process.spawn('winetricks', ['dxvk', 'vkd3d'], { env });

      proc.on('close', (code: number) => {
        // Non-zero exit is okay for winetricks as it may not be available
        resolve();
      });

      proc.on('error', () => {
        // Winetricks not available, that's okay
        resolve();
      });
    });
  }
}
