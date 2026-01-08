use thiserror::Error;
use serde::{Deserialize, Serialize};

#[derive(Error, Debug, Clone, Serialize, Deserialize)]
pub enum MinigalaxyError {
    #[error("Authentication failed: {0}")]
    AuthError(String),
    
    #[error("Network error: {0}")]
    NetworkError(String),
    
    #[error("Download failed: {0}")]
    DownloadError(String),
    
    #[error("Installation failed: {0}")]
    InstallError(String),
    
    #[error("Game launch failed: {0}")]
    LaunchError(String),
    
    #[error("Configuration error: {0}")]
    ConfigError(String),
    
    #[error("File system error: {0}")]
    FileSystemError(String),
    
    #[error("API error: {0}")]
    ApiError(String),
    
    #[error("No download link found for: {0}")]
    NoDownloadLinkFound(String),
    
    #[error("Not found: {0}")]
    NotFoundError(String),
    
    #[error("Unknown error: {0}")]
    Unknown(String),
}

impl From<reqwest::Error> for MinigalaxyError {
    fn from(err: reqwest::Error) -> Self {
        MinigalaxyError::NetworkError(err.to_string())
    }
}

impl From<std::io::Error> for MinigalaxyError {
    fn from(err: std::io::Error) -> Self {
        MinigalaxyError::FileSystemError(err.to_string())
    }
}

impl From<serde_json::Error> for MinigalaxyError {
    fn from(err: serde_json::Error) -> Self {
        MinigalaxyError::ApiError(err.to_string())
    }
}

pub type Result<T> = std::result::Result<T, MinigalaxyError>;
