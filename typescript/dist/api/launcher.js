"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.launchGame = launchGame;
const fs = __importStar(require("fs"));
const path = __importStar(require("path"));
const child_process = __importStar(require("child_process"));
const error_1 = require("./error");
const config_1 = require("./config");
async function launchGame(game, wineOptions) {
    try {
        if (game.platform === 'linux') {
            return await launchLinuxGame(game);
        }
        else if (game.platform === 'windows' && wineOptions) {
            return await launchWindowsGame(game, wineOptions);
        }
        else {
            return {
                success: false,
                error_message: 'Unsupported platform or missing Wine options',
            };
        }
    }
    catch (error) {
        return {
            success: false,
            error_message: error.message,
        };
    }
}
async function launchLinuxGame(game) {
    const installDir = game.install_dir;
    if (!fs.existsSync(installDir)) {
        throw new error_1.GalaxiError(`Game not installed at ${installDir}`, error_1.GalaxiErrorType.LaunchError);
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
            }
            catch {
                return false;
            }
        });
        if (!executable) {
            throw new error_1.GalaxiError('No executable found in game directory', error_1.GalaxiErrorType.LaunchError);
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
async function launchWindowsGame(game, wineOptions) {
    const installDir = game.install_dir;
    if (!fs.existsSync(installDir)) {
        throw new error_1.GalaxiError(`Game not installed at ${installDir}`, error_1.GalaxiErrorType.LaunchError);
    }
    // Find Windows executable
    const exeFiles = findExecutables(installDir);
    if (exeFiles.length === 0) {
        throw new error_1.GalaxiError('No Windows executable found', error_1.GalaxiErrorType.LaunchError);
    }
    // Filter out known installer/utility executables
    const filteredExes = exeFiles.filter(exe => {
        const basename = path.basename(exe).toLowerCase();
        return !config_1.BINARY_NAMES_TO_IGNORE.some(ignore => basename === ignore.toLowerCase());
    });
    const exePath = filteredExes[0] || exeFiles[0];
    const winePrefix = wineOptions.wine_prefix || path.join(installDir, 'wine_prefix');
    const env = {
        ...process.env,
        WINEPREFIX: winePrefix,
    };
    if (wineOptions.wine_disable_ntsync) {
        env.WINE_DISABLE_FAST_SYNC = '1';
    }
    if (wineOptions.wine_debug) {
        env.WINEDEBUG = '+all';
    }
    else {
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
function findExecutables(dir, exeFiles = []) {
    const files = fs.readdirSync(dir);
    for (const file of files) {
        const fullPath = path.join(dir, file);
        const stats = fs.statSync(fullPath);
        if (stats.isDirectory()) {
            findExecutables(fullPath, exeFiles);
        }
        else if (stats.isFile() && file.toLowerCase().endsWith('.exe')) {
            exeFiles.push(fullPath);
        }
    }
    return exeFiles;
}
//# sourceMappingURL=launcher.js.map