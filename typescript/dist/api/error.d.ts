export declare class GalaxiError extends Error {
    readonly type: GalaxiErrorType;
    constructor(message: string, type: GalaxiErrorType);
}
export declare enum GalaxiErrorType {
    AuthError = "AuthError",
    NetworkError = "NetworkError",
    DownloadError = "DownloadError",
    InstallError = "InstallError",
    LaunchError = "LaunchError",
    ConfigError = "ConfigError",
    FileSystemError = "FileSystemError",
    ApiError = "ApiError",
    NoDownloadLinkFound = "NoDownloadLinkFound",
    NotFoundError = "NotFoundError",
    Unknown = "Unknown"
}
export type Result<T> = {
    success: true;
    value: T;
} | {
    success: false;
    error: GalaxiError;
};
export declare function Ok<T>(value: T): Result<T>;
export declare function Err<T>(error: GalaxiError): Result<T>;
//# sourceMappingURL=error.d.ts.map