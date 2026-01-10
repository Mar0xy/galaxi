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
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.DownloadManager = exports.DownloadStatus = void 0;
const fs = __importStar(require("fs"));
const path = __importStar(require("path"));
const axios_1 = __importDefault(require("axios"));
const error_1 = require("./error");
var DownloadStatus;
(function (DownloadStatus) {
    DownloadStatus["Downloading"] = "Downloading";
    DownloadStatus["Paused"] = "Paused";
    DownloadStatus["Completed"] = "Completed";
    DownloadStatus["Failed"] = "Failed";
})(DownloadStatus || (exports.DownloadStatus = DownloadStatus = {}));
class DownloadManager {
    constructor() {
        this.downloads = new Map();
    }
    async downloadFile(game, url, destination, onProgress) {
        const fileName = path.basename(destination);
        const progress = {
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
            const response = await (0, axios_1.default)({
                method: 'GET',
                url,
                responseType: 'stream',
                headers: startByte > 0 ? { Range: `bytes=${startByte}-` } : {},
            });
            progress.total = parseInt(response.headers['content-length'] || '0') + startByte;
            const writer = fs.createWriteStream(destination, { flags: startByte > 0 ? 'a' : 'w' });
            response.data.on('data', (chunk) => {
                progress.downloaded += chunk.length;
                if (onProgress) {
                    onProgress(progress);
                }
            });
            await new Promise((resolve, reject) => {
                writer.on('finish', resolve);
                writer.on('error', reject);
                response.data.pipe(writer);
            });
            progress.status = DownloadStatus.Completed;
            if (onProgress) {
                onProgress(progress);
            }
        }
        catch (error) {
            progress.status = DownloadStatus.Failed;
            if (onProgress) {
                onProgress(progress);
            }
            throw new error_1.GalaxiError(`Download failed: ${error.message}`, error_1.GalaxiErrorType.DownloadError);
        }
    }
    getProgress(gameId) {
        return this.downloads.get(gameId);
    }
    pauseDownload(gameId) {
        const progress = this.downloads.get(gameId);
        if (progress) {
            progress.status = DownloadStatus.Paused;
        }
    }
    resumeDownload(gameId) {
        const progress = this.downloads.get(gameId);
        if (progress) {
            progress.status = DownloadStatus.Downloading;
        }
    }
    cancelDownload(gameId) {
        this.downloads.delete(gameId);
    }
}
exports.DownloadManager = DownloadManager;
//# sourceMappingURL=download.js.map