import * as fs from 'fs';
import * as path from 'path';
import * as child_process from 'child_process';
import { GalaxiError, GalaxiErrorType } from './error';
import { Game } from './game';
import { LaunchResultDto } from './dto';
import { BINARY_NAMES_TO_IGNORE } from './config';

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

export async function launchGame(
  game: Game,
  wineOptions?: WineLaunchOptions
): Promise<LaunchResult> {
  try {
    if (game.platform === 'linux') {
      return await launchLinuxGame(game);
    } else if (game.platform === 'windows' && wineOptions) {
      return await launchWindowsGame(game, wineOptions);
    } else {
      return {
        success: false,
        error_message: 'Unsupported platform or missing Wine options',
      };
    }
  } catch (error: any) {
    return {
      success: false,
      error_message: error.message,
    };
  }
}

async function launchLinuxGame(game: Game): Promise<LaunchResult> {
  const installDir = game.install_dir;
  
  if (!fs.existsSync(installDir)) {
    throw new GalaxiError(
      `Game not installed at ${installDir}`,
      GalaxiErrorType.LaunchError
    );
  }

  // Find start script
  const startScript = path.join(installDir, 'start.sh');
  if (!fs.existsSync(startScript)) {
    // Look for any executable
    const files = fs.readdirSync(installDir);
    const executable = files.find(f => {
      const filePath = path.join(installDir, f);
      try {
        const stats = fs.statSync(filePath);
        return stats.isFile() && (stats.mode & 0o111) !== 0;
      } catch {
        return false;
      }
    });

    if (!executable) {
      throw new GalaxiError(
        'No executable found in game directory',
        GalaxiErrorType.LaunchError
      );
    }

    const execPath = path.join(installDir, executable);
    const proc = child_process.spawn(execPath, [], {
      cwd: installDir,
      detached: true,
      stdio: 'ignore',
    });

    proc.unref();

    return {
      success: true,
      pid: proc.pid,
    };
  }

  const proc = child_process.spawn(startScript, [], {
    cwd: installDir,
    detached: true,
    stdio: 'ignore',
  });

  proc.unref();

  return {
    success: true,
    pid: proc.pid,
  };
}

async function launchWindowsGame(
  game: Game,
  wineOptions: WineLaunchOptions
): Promise<LaunchResult> {
  const installDir = game.install_dir;
  
  if (!fs.existsSync(installDir)) {
    throw new GalaxiError(
      `Game not installed at ${installDir}`,
      GalaxiErrorType.LaunchError
    );
  }

  // Windows games are installed to wine_prefix/drive_c/game inside the install directory
  const winePrefix = wineOptions.wine_prefix || path.join(installDir, 'wine_prefix');
  const gameDir = path.join(winePrefix, 'drive_c', 'game');
  
  console.log(`Looking for game executable in: ${gameDir}`);
  
  if (!fs.existsSync(gameDir)) {
    throw new GalaxiError(
      `Game directory not found at ${gameDir}`,
      GalaxiErrorType.LaunchError
    );
  }

  // Find Windows executable
  const exeFiles = findExecutables(gameDir);
  
  if (exeFiles.length === 0) {
    throw new GalaxiError(
      'No Windows executable found',
      GalaxiErrorType.LaunchError
    );
  }

  // Filter out known installer/utility executables
  const filteredExes = exeFiles.filter(exe => {
    const basename = path.basename(exe).toLowerCase();
    return !BINARY_NAMES_TO_IGNORE.some(ignore => basename === ignore.toLowerCase());
  });

  const exePath = filteredExes[0] || exeFiles[0];
  
  console.log(`Launching Windows game: ${game.name}`);
  console.log(`Executable: ${exePath}`);
  console.log(`Wine prefix: ${winePrefix}`);
  
  const env: any = {
    ...process.env,
    WINEPREFIX: winePrefix,
  };

  if (wineOptions.wine_disable_ntsync) {
    env.WINE_DISABLE_FAST_SYNC = '1';
  }

  if (wineOptions.wine_debug) {
    env.WINEDEBUG = '+all';
  } else {
    env.WINEDEBUG = '-all';
  }

  const wineExec = wineOptions.wine_executable || 'wine';
  
  const proc = child_process.spawn(wineExec, [exePath], {
    cwd: path.dirname(exePath),
    env,
    detached: true,
    stdio: 'ignore',
  });

  proc.unref();

  return {
    success: true,
    pid: proc.pid,
  };
}

function findExecutables(dir: string, exeFiles: string[] = []): string[] {
  const files = fs.readdirSync(dir);
  
  for (const file of files) {
    const fullPath = path.join(dir, file);
    const stats = fs.statSync(fullPath);
    
    if (stats.isDirectory()) {
      findExecutables(fullPath, exeFiles);
    } else if (stats.isFile() && file.toLowerCase().endsWith('.exe')) {
      exeFiles.push(fullPath);
    }
  }
  
  return exeFiles;
}
