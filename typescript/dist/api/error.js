"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.GalaxiErrorType = exports.GalaxiError = void 0;
exports.Ok = Ok;
exports.Err = Err;
// Error types for Galaxi
class GalaxiError extends Error {
    constructor(message, type) {
        super(message);
        this.type = type;
        this.name = 'GalaxiError';
    }
}
exports.GalaxiError = GalaxiError;
var GalaxiErrorType;
(function (GalaxiErrorType) {
    GalaxiErrorType["AuthError"] = "AuthError";
    GalaxiErrorType["NetworkError"] = "NetworkError";
    GalaxiErrorType["DownloadError"] = "DownloadError";
    GalaxiErrorType["InstallError"] = "InstallError";
    GalaxiErrorType["LaunchError"] = "LaunchError";
    GalaxiErrorType["ConfigError"] = "ConfigError";
    GalaxiErrorType["FileSystemError"] = "FileSystemError";
    GalaxiErrorType["ApiError"] = "ApiError";
    GalaxiErrorType["NoDownloadLinkFound"] = "NoDownloadLinkFound";
    GalaxiErrorType["NotFoundError"] = "NotFoundError";
    GalaxiErrorType["Unknown"] = "Unknown";
})(GalaxiErrorType || (exports.GalaxiErrorType = GalaxiErrorType = {}));
function Ok(value) {
    return { success: true, value };
}
function Err(error) {
    return { success: false, error };
}
//# sourceMappingURL=error.js.map