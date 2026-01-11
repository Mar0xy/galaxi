// Error types for Galaxi
export class GalaxiError extends Error {
  constructor(message: string, public readonly type: GalaxiErrorType) {
    super(message);
    this.name = 'GalaxiError';
  }
}

export enum GalaxiErrorType {
  AuthError = 'AuthError',
  NetworkError = 'NetworkError',
  DownloadError = 'DownloadError',
  InstallError = 'InstallError',
  LaunchError = 'LaunchError',
  ConfigError = 'ConfigError',
  FileSystemError = 'FileSystemError',
  ApiError = 'ApiError',
  NoDownloadLinkFound = 'NoDownloadLinkFound',
  NotFoundError = 'NotFoundError',
  Unknown = 'Unknown'
}

export type Result<T> = { success: true; value: T } | { success: false; error: GalaxiError };

export function Ok<T>(value: T): Result<T> {
  return { success: true, value };
}

export function Err<T>(error: GalaxiError): Result<T> {
  return { success: false, error };
}
