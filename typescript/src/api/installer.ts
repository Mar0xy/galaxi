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
    installerPath: string,
    installDir: string,
    wineOptions?: WineOptions
  ): Promise<void> {
    // Create install directory
    if (!fs.existsSync(installDir)) {
      fs.mkdirSync(installDir, { recursive: true });
    }

    // Verify installer file exists
    if (!fs.existsSync(installerPath)) {
      throw new GalaxiError(
        `Installer file not found: ${installerPath}`,
        GalaxiErrorType.InstallError
      );
    }

    // Get file extension to determine installer type
    const fileName = path.basename(installerPath);
    
    // Make executable for Linux installers
    if (fileName.endsWith('.sh')) {
      fs.chmodSync(installerPath, 0o755);
      await this.runLinuxInstaller(installerPath, installDir);
    } else if (fileName.endsWith('.exe') && wineOptions) {
      await this.runWindowsInstaller(installerPath, installDir, wineOptions);
    } else {
      throw new GalaxiError(
        `Unsupported installer type: ${fileName}`,
        GalaxiErrorType.InstallError
      );
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
    // Set up Wine prefix inside the game install directory
    const winePrefix = wineOptions.prefix || path.join(installDir, 'wine_prefix');

    const env: any = {
      ...process.env,
      WINEPREFIX: winePrefix,
    };

    if (wineOptions.disable_ntsync) {
      env.WINE_DISABLE_FAST_SYNC = '1';
    }

    // Auto-install DXVK and setup Wine prefix if requested
    if (wineOptions.auto_install_dxvk) {
      await this.setupWinePrefix(winePrefix, wineOptions.executable, wineOptions.disable_ntsync);
    }

    return new Promise((resolve, reject) => {
      const wineExec = wineOptions.executable || 'wine';
      // Install to c:\game inside the Wine prefix (which maps to wine_prefix/drive_c/game)
      const process = child_process.spawn(wineExec, [installerPath, '/VERYSILENT', '/NORESTART', '/SUPPRESSMSGBOXES', '/DIR=c:\\game'], { env });

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

  private async setupWinePrefix(winePrefix: string, wineExecutable: string, disableNtsync: boolean): Promise<void> {
    const env: any = {
      ...process.env,
      WINEPREFIX: winePrefix,
    };

    if (disableNtsync) {
      env.WINE_DISABLE_FAST_SYNC = '1';
    }

    // First, initialize the Wine prefix using wineboot
    console.log('Initializing Wine prefix...');
    await new Promise<void>((resolve) => {
      const wineExec = wineExecutable || 'wine';
      const wineboot = wineExec.replace('wine', 'wineboot');
      
      const proc = child_process.spawn(wineboot, ['--init'], { env });

      proc.on('close', () => {
        resolve();
      });

      proc.on('error', () => {
        // Try with 'wine wineboot' if wineboot is not found
        const fallbackProc = child_process.spawn(wineExec, ['wineboot', '--init'], { env });
        fallbackProc.on('close', () => resolve());
        fallbackProc.on('error', () => resolve());
      });
    });

    // Now run winetricks to install components
    console.log('Running winetricks to install corefonts, dxvk, vkd3d...');
    const components = ['corefonts', 'dxvk', 'vkd3d'];
    
    for (const component of components) {
      await new Promise<void>((resolve) => {
        const winetricksEnv = {
          ...env,
          WINE: wineExecutable || 'wine',
        };

        const proc = child_process.spawn('winetricks', ['-q', component], { env: winetricksEnv });

        proc.on('close', (code: number) => {
          if (code !== 0) {
            console.warn(`Warning: winetricks ${component} failed with code ${code}`);
          }
          resolve();
        });

        proc.on('error', (err) => {
          console.warn(`Warning: Failed to run winetricks ${component}: ${err.message}`);
          resolve();
        });
      });
    }
  }
}
