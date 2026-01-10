use std::fs::{self, File};
use std::io::Write;
use std::path::PathBuf;
use std::sync::Arc;
use tokio::sync::Mutex;
use serde::{Deserialize, Serialize};
use super::config::MINIMUM_RESUME_SIZE;
use super::error::{GalaxiError, Result};

/// Download progress information
#[flutter_rust_bridge::frb(non_opaque)]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DownloadProgress {
    pub game_id: i64,
    pub file_name: String,
    pub downloaded: u64,
    pub total: u64,
    pub percentage: f64,
    pub status: DownloadStatus,
    pub error: Option<String>,
}

/// Download status
#[flutter_rust_bridge::frb(non_opaque)]
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum DownloadStatus {
    Pending,
    Downloading,
    Paused,
    Completed,
    Failed,
    Cancelled,
}

/// Download manager for handling game downloads
#[flutter_rust_bridge::frb(opaque)]
pub struct DownloadManager {
    client: reqwest::Client,
    active_downloads: Arc<Mutex<std::collections::HashMap<i64, DownloadProgress>>>,
}

#[flutter_rust_bridge::frb(ignore)]
impl DownloadManager {
    pub fn new() -> Self {
        DownloadManager {
            client: reqwest::Client::new(),
            active_downloads: Arc::new(Mutex::new(std::collections::HashMap::new())),
        }
    }
    
    /// Create a DownloadManager with a shared active_downloads map
    /// This allows progress to be tracked across different manager instances
    pub fn with_shared_downloads(active_downloads: Arc<Mutex<std::collections::HashMap<i64, DownloadProgress>>>) -> Self {
        DownloadManager {
            client: reqwest::Client::new(),
            active_downloads,
        }
    }
    
    /// Get a clone of the active_downloads Arc for sharing
    pub fn get_active_downloads_arc(&self) -> Arc<Mutex<std::collections::HashMap<i64, DownloadProgress>>> {
        self.active_downloads.clone()
    }

    pub async fn get_active_downloads(&self) -> Vec<DownloadProgress> {
        let downloads = self.active_downloads.lock().await;
        downloads.values().cloned().collect()
    }

    pub async fn download_file(
        &self,
        url: &str,
        save_path: &PathBuf,
        game_id: i64,
        resume: bool,
    ) -> Result<()> {
        if let Some(parent) = save_path.parent() {
            fs::create_dir_all(parent)?;
        }

        let mut downloaded: u64 = 0;
        let temp_path = save_path.with_extension("part");
        
        if resume && temp_path.exists() {
            let metadata = fs::metadata(&temp_path)?;
            if metadata.len() >= MINIMUM_RESUME_SIZE {
                downloaded = metadata.len();
            }
        }

        let head_response = self.client.head(url).send().await?;
        let total_size = head_response
            .headers()
            .get("content-length")
            .and_then(|v| v.to_str().ok())
            .and_then(|s| s.parse::<u64>().ok())
            .unwrap_or(0);

        let progress = DownloadProgress {
            game_id,
            file_name: save_path.file_name()
                .map(|s| s.to_string_lossy().to_string())
                .unwrap_or_default(),
            downloaded,
            total: total_size,
            percentage: if total_size > 0 { (downloaded as f64 / total_size as f64) * 100.0 } else { 0.0 },
            status: DownloadStatus::Downloading,
            error: None,
        };
        
        {
            let mut downloads = self.active_downloads.lock().await;
            downloads.insert(game_id, progress);
        }

        let mut request = self.client.get(url);
        if downloaded > 0 {
            request = request.header("Range", format!("bytes={}-", downloaded));
        }

        let response = request.send().await?;
        
        if !response.status().is_success() && response.status().as_u16() != 206 {
            return Err(GalaxiError::DownloadError(format!(
                "HTTP error: {}",
                response.status()
            )));
        }

        let mut file = if downloaded > 0 {
            fs::OpenOptions::new()
                .write(true)
                .append(true)
                .open(&temp_path)?
        } else {
            File::create(&temp_path)?
        };

        let mut stream = response.bytes_stream();
        use futures_util::StreamExt;
        
        while let Some(chunk_result) = stream.next().await {
            let chunk = chunk_result.map_err(|e| GalaxiError::DownloadError(e.to_string()))?;
            file.write_all(&chunk)?;
            downloaded += chunk.len() as u64;

            {
                let mut downloads = self.active_downloads.lock().await;
                if let Some(progress) = downloads.get_mut(&game_id) {
                    progress.downloaded = downloaded;
                    progress.percentage = if total_size > 0 {
                        (downloaded as f64 / total_size as f64) * 100.0
                    } else {
                        0.0
                    };
                    
                    if progress.status == DownloadStatus::Cancelled {
                        return Err(GalaxiError::DownloadError("Download cancelled".to_string()));
                    }
                }
            }
        }

        fs::rename(&temp_path, save_path)?;

        {
            let mut downloads = self.active_downloads.lock().await;
            if let Some(progress) = downloads.get_mut(&game_id) {
                progress.status = DownloadStatus::Completed;
                progress.percentage = 100.0;
            }
        }

        Ok(())
    }

    pub async fn pause_download(&self, game_id: i64) {
        let mut downloads = self.active_downloads.lock().await;
        if let Some(progress) = downloads.get_mut(&game_id) {
            progress.status = DownloadStatus::Paused;
        }
    }

    pub async fn cancel_download(&self, game_id: i64) {
        let mut downloads = self.active_downloads.lock().await;
        if let Some(progress) = downloads.get_mut(&game_id) {
            progress.status = DownloadStatus::Cancelled;
        }
    }

    pub async fn get_progress(&self, game_id: i64) -> Option<DownloadProgress> {
        let downloads = self.active_downloads.lock().await;
        downloads.get(&game_id).cloned()
    }
}

impl Default for DownloadManager {
    fn default() -> Self {
        Self::new()
    }
}

#[flutter_rust_bridge::frb(ignore)]
pub fn calculate_md5(path: &PathBuf) -> Result<String> {
    let file = fs::read(path)?;
    let digest = md5::compute(&file);
    Ok(format!("{:x}", digest))
}

#[flutter_rust_bridge::frb(ignore)]
pub fn verify_checksum(path: &PathBuf, expected_md5: &str) -> Result<bool> {
    let calculated = calculate_md5(path)?;
    Ok(calculated.to_lowercase() == expected_md5.to_lowercase())
}
