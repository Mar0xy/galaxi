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
exports.GameInstaller = void 0;
const fs = __importStar(require("fs"));
const path = __importStar(require("path"));
const child_process = __importStar(require("child_process"));
const error_1 = require("./error");
class GameInstaller {
    constructor(downloadManager) {
        this.downloadManager = downloadManager;
    }
    async installGame(game, downloadUrl, installDir, wineOptions) {
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
        }
        else if (game.platform === 'windows' && wineOptions) {
            await this.runWindowsInstaller(installerPath, installDir, wineOptions);
        }
    }
    async runLinuxInstaller(installerPath, installDir) {
        return new Promise((resolve, reject) => {
            const process = child_process.spawn(installerPath, ['--', `--i-agree-to-all-licenses`, `--noreadme`, `--nooptions`, `--noprompt`, `--destination=${installDir}`]);
            process.on('close', (code) => {
                if (code === 0) {
                    resolve();
                }
                else {
                    reject(new error_1.GalaxiError(`Installer exited with code ${code}`, error_1.GalaxiErrorType.InstallError));
                }
            });
            process.on('error', (err) => {
                reject(new error_1.GalaxiError(`Installer failed: ${err.message}`, error_1.GalaxiErrorType.InstallError));
            });
        });
    }
    async runWindowsInstaller(installerPath, installDir, wineOptions) {
        // Set up Wine prefix
        const winePrefix = wineOptions.prefix || path.join(installDir, 'wine_prefix');
        if (!fs.existsSync(winePrefix)) {
            fs.mkdirSync(winePrefix, { recursive: true });
        }
        const env = {
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
                }
                else {
                    reject(new error_1.GalaxiError(`Wine installer exited with code ${code}`, error_1.GalaxiErrorType.InstallError));
                }
            });
            process.on('error', (err) => {
                reject(new error_1.GalaxiError(`Wine installer failed: ${err.message}`, error_1.GalaxiErrorType.InstallError));
            });
        });
    }
    async installDxvk(winePrefix, wineExecutable) {
        // Run winetricks to install DXVK
        return new Promise((resolve, reject) => {
            const env = {
                ...process.env,
                WINEPREFIX: winePrefix,
            };
            const proc = child_process.spawn('winetricks', ['dxvk', 'vkd3d'], { env });
            proc.on('close', (code) => {
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
exports.GameInstaller = GameInstaller;
//# sourceMappingURL=installer.js.map