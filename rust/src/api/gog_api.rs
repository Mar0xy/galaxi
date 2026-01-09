use reqwest::Client;
use serde::{Deserialize, Serialize};
use std::time::{SystemTime, UNIX_EPOCH};
use super::config::{Config, IGNORE_GAME_IDS};
use super::error::{MinigalaxyError, Result};
use super::game::Game;

/// GOG API client
#[derive(Clone)]
pub struct GogApi {
    config: Config,
    client: Client,
    active_token: Option<String>,
    token_expiration: u64,
}

/// OAuth token response from GOG
#[derive(Debug, Deserialize)]
struct TokenResponse {
    access_token: String,
    expires_in: i64,
    refresh_token: String,
}

/// User data response from GOG
#[flutter_rust_bridge::frb(non_opaque)]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UserData {
    #[serde(rename = "userId")]
    pub user_id: String,
    pub username: String,
    #[serde(rename = "galaxyUserId")]
    pub galaxy_user_id: Option<String>,
    pub email: Option<String>,
    pub avatar: Option<String>,
    #[serde(rename = "isLoggedIn")]
    pub is_logged_in: bool,
}

/// User profile from the users API
#[flutter_rust_bridge::frb(non_opaque)]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UserProfile {
    pub id: String,
    pub username: String,
    #[serde(rename = "created_date")]
    pub created_date: Option<String>,
    pub avatars: Option<UserAvatars>,
}

#[flutter_rust_bridge::frb(non_opaque)]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UserAvatars {
    pub small: Option<String>,
    pub small2x: Option<String>,
    pub medium: Option<String>,
    pub medium2x: Option<String>,
    pub large: Option<String>,
    pub large2x: Option<String>,
}

/// Library response from GOG
#[derive(Debug, Deserialize)]
struct LibraryResponse {
    #[serde(rename = "totalPages")]
    total_pages: i32,
    products: Vec<ProductInfo>,
}

#[derive(Debug, Deserialize)]
struct ProductInfo {
    id: i64,
    title: String,
    url: Option<String>,
    image: String,
    #[serde(rename = "worksOn")]
    works_on: WorksOn,
    category: String,
}

#[derive(Debug, Deserialize)]
struct WorksOn {
    #[serde(rename = "Linux")]
    linux: bool,
    #[serde(rename = "Windows")]
    #[allow(dead_code)]
    windows: bool,
    #[serde(rename = "Mac")]
    #[allow(dead_code)]
    mac: bool,
}

/// Game info response
#[flutter_rust_bridge::frb(non_opaque)]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GameInfoResponse {
    pub id: i64,
    pub title: String,
    pub description: Option<GameDescription>,
    pub downloads: Option<GameDownloads>,
    pub expanded_dlcs: Option<Vec<ExpandedDlc>>,
    pub changelog: Option<String>,
}

#[flutter_rust_bridge::frb(non_opaque)]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GameDescription {
    pub lead: Option<String>,
    pub full: Option<String>,
}

#[flutter_rust_bridge::frb(non_opaque)]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GameDownloads {
    pub installers: Vec<Installer>,
}

#[flutter_rust_bridge::frb(non_opaque)]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Installer {
    pub id: String,
    pub name: String,
    pub os: String,
    pub language: String,
    pub version: Option<String>,
    pub files: Vec<InstallerFile>,
}

#[flutter_rust_bridge::frb(non_opaque)]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InstallerFile {
    pub id: String,
    pub size: i64,
    pub downlink: String,
}

#[flutter_rust_bridge::frb(non_opaque)]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ExpandedDlc {
    pub id: i64,
    pub title: String,
    pub downloads: Option<GameDownloads>,
}

/// Games DB info
#[flutter_rust_bridge::frb(non_opaque)]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GamesDbInfo {
    pub cover: String,
    pub vertical_cover: String,
    pub background: String,
    pub summary: std::collections::HashMap<String, String>,
    pub genre: std::collections::HashMap<String, String>,
}

/// Download info response
#[flutter_rust_bridge::frb(non_opaque)]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DownloadInfo {
    pub os: String,
    pub language: String,
    pub version: Option<String>,
    pub total_size: i64,
    pub files: Vec<DownloadFile>,
}

#[flutter_rust_bridge::frb(non_opaque)]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DownloadFile {
    pub size: i64,
    pub downlink: String,
}

/// Real download link response
#[derive(Debug, Deserialize)]
struct RealDownloadLinkResponse {
    downlink: String,
    #[allow(dead_code)]
    checksum: Option<String>,
}

/// GOG API constants
const REDIRECT_URI: &str = "https://embed.gog.com/on_login_success?origin=client";
const CLIENT_ID: &str = "46899977096215655";
const CLIENT_SECRET: &str = "9d85c43b1482497dbbce61f6e4aa173a433796eeae2ca8c5f6129f2dc4de46d9";

#[flutter_rust_bridge::frb(ignore)]
impl GogApi {
    pub fn new(config: Config) -> Self {
        GogApi {
            config,
            client: Client::new(),
            active_token: None,
            token_expiration: 0,
        }
    }

    pub fn get_login_url() -> String {
        format!(
            "https://auth.gog.com/auth?client_id={}&redirect_uri={}&response_type=code&layout=client2",
            CLIENT_ID,
            urlencoding::encode(REDIRECT_URI)
        )
    }

    pub fn get_redirect_url() -> &'static str {
        REDIRECT_URI
    }

    pub fn get_success_url() -> &'static str {
        "https://embed.gog.com/on_login_success"
    }

    pub async fn authenticate(&mut self, login_code: Option<&str>, refresh_token: Option<&str>) -> Result<String> {
        if let Some(rt) = refresh_token {
            self.refresh_token(rt).await
        } else if let Some(code) = login_code {
            self.get_token(code).await
        } else {
            Err(MinigalaxyError::AuthError("No authentication method provided".to_string()))
        }
    }

    async fn refresh_token(&mut self, refresh_token: &str) -> Result<String> {
        let params = [
            ("client_id", CLIENT_ID),
            ("client_secret", CLIENT_SECRET),
            ("grant_type", "refresh_token"),
            ("refresh_token", refresh_token),
        ];
        self.fetch_token(&params).await
    }

    async fn get_token(&mut self, login_code: &str) -> Result<String> {
        let redirect_uri = REDIRECT_URI.to_string();
        let params = [
            ("client_id", CLIENT_ID),
            ("client_secret", CLIENT_SECRET),
            ("grant_type", "authorization_code"),
            ("code", login_code),
            ("redirect_uri", redirect_uri.as_str()),
        ];
        self.fetch_token(&params).await
    }

    async fn fetch_token(&mut self, params: &[(&str, &str)]) -> Result<String> {
        let response = self.client
            .get("https://auth.gog.com/token")
            .query(params)
            .send()
            .await?
            .json::<TokenResponse>()
            .await?;

        self.active_token = Some(response.access_token);
        
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs();
        self.token_expiration = now + response.expires_in as u64;

        Ok(response.refresh_token)
    }

    async fn request<T: for<'de> Deserialize<'de>>(&self, url: &str) -> Result<T> {
        let token = self.active_token.as_ref()
            .ok_or_else(|| MinigalaxyError::AuthError("Not authenticated".to_string()))?;

        let response = self.client
            .get(url)
            .header("Authorization", format!("Bearer {}", token))
            .send()
            .await?
            .json::<T>()
            .await?;

        Ok(response)
    }

    pub async fn get_library(&self) -> Result<Vec<Game>> {
        let mut games = Vec::new();
        let mut current_page = 1;
        
        loop {
            let url = format!(
                "https://embed.gog.com/account/getFilteredProducts?mediaType=1&page={}",
                current_page
            );
            
            let response: LibraryResponse = self.request(&url).await?;
            
            for product in response.products {
                if IGNORE_GAME_IDS.contains(&product.id) {
                    continue;
                }

                // Determine platform - always include the game, just mark its platform correctly
                let platform = if product.works_on.linux {
                    "linux"
                } else {
                    "windows"
                };

                let game = Game {
                    name: product.title,
                    url: product.url.unwrap_or_default(),
                    md5sum: std::collections::HashMap::new(),
                    id: product.id,
                    install_dir: String::new(),
                    image_url: product.image,
                    platform: platform.to_string(),
                    dlcs: Vec::new(),
                    category: product.category,
                };
                games.push(game);
            }

            if current_page >= response.total_pages {
                break;
            }
            current_page += 1;
        }

        Ok(games)
    }

    pub async fn get_info(&self, game: &Game) -> Result<GameInfoResponse> {
        let url = format!(
            "https://api.gog.com/products/{}?locale=en-US&expand=downloads,expanded_dlcs,description,screenshots,videos,related_products,changelog",
            game.id
        );
        self.request(&url).await
    }

    pub async fn get_user_info(&self) -> Result<UserData> {
        self.request("https://embed.gog.com/userData.json").await
    }

    pub async fn get_user_profile(&self, user_id: &str) -> Result<UserProfile> {
        // Use embed.gog.com/users/info/{id} endpoint
        let url = format!("https://embed.gog.com/users/info/{}", user_id);
        
        let token = self.active_token.as_ref()
            .ok_or_else(|| MinigalaxyError::AuthError("Not authenticated".to_string()))?;
        
        // Parse the response as JSON Value to extract avatars
        let response: serde_json::Value = self.client
            .get(&url)
            .header("Authorization", format!("Bearer {}", token))
            .send()
            .await?
            .json()
            .await?;
        
        let username = response.get("username")
            .and_then(|u| u.as_str())
            .unwrap_or("Unknown")
            .to_string();
        
        // Extract avatars object from the response
        let avatars = response.get("avatars").and_then(|a| {
            Some(UserAvatars {
                small: a.get("small").and_then(|v| v.as_str()).map(|s| s.to_string()),
                small2x: a.get("small2x").and_then(|v| v.as_str()).map(|s| s.to_string()),
                medium: a.get("medium").and_then(|v| v.as_str()).map(|s| s.to_string()),
                medium2x: a.get("medium2x").and_then(|v| v.as_str()).map(|s| s.to_string()),
                large: a.get("large").and_then(|v| v.as_str()).map(|s| s.to_string()),
                large2x: a.get("large2x").and_then(|v| v.as_str()).map(|s| s.to_string()),
            })
        });
        
        Ok(UserProfile {
            id: user_id.to_string(),
            username,
            created_date: None,
            avatars,
        })
    }

    pub async fn get_download_info(&self, game: &Game, os: &str) -> Result<DownloadInfo> {
        let info = self.get_info(game).await?;
        
        let installers = info.downloads
            .ok_or_else(|| MinigalaxyError::NoDownloadLinkFound(game.name.clone()))?
            .installers;

        let os_options: Vec<&str> = if os == "linux" {
            vec!["linux", "windows"]
        } else {
            vec![os]
        };

        let mut possible_downloads: Vec<&Installer> = Vec::new();
        
        for target_os in os_options {
            possible_downloads = installers
                .iter()
                .filter(|i| i.os == target_os)
                .collect();
            
            if !possible_downloads.is_empty() {
                break;
            }
        }

        if possible_downloads.is_empty() {
            return Err(MinigalaxyError::NoDownloadLinkFound(
                format!("{} (id: {})", game.name, game.id)
            ));
        }

        let download = possible_downloads
            .iter()
            .find(|i| i.language == self.config.lang)
            .or_else(|| possible_downloads.iter().find(|i| i.language == "en"))
            .or_else(|| possible_downloads.last())
            .ok_or_else(|| MinigalaxyError::NoDownloadLinkFound(game.name.clone()))?;

        let total_size: i64 = download.files.iter().map(|f| f.size).sum();
        
        Ok(DownloadInfo {
            os: download.os.clone(),
            language: download.language.clone(),
            version: download.version.clone(),
            total_size,
            files: download.files.iter().map(|f| DownloadFile {
                size: f.size,
                downlink: f.downlink.clone(),
            }).collect(),
        })
    }

    pub async fn get_real_download_link(&self, url: &str) -> Result<String> {
        let response: RealDownloadLinkResponse = self.request(url).await?;
        Ok(response.downlink)
    }

    pub async fn get_version(&self, game: &Game) -> Result<String> {
        let info = self.get_info(game).await?;
        
        if let Some(downloads) = info.downloads {
            for installer in downloads.installers {
                if installer.os == game.platform {
                    return Ok(installer.version.unwrap_or_else(|| "0".to_string()));
                }
            }
        }
        
        Ok("0".to_string())
    }

    pub async fn can_connect(&self) -> bool {
        let urls = ["https://embed.gog.com", "https://auth.gog.com"];
        
        for url in urls {
            if self.client.get(url).timeout(std::time::Duration::from_secs(5)).send().await.is_err() {
                return false;
            }
        }
        true
    }

    pub async fn get_gamesdb_info(&self, game: &Game) -> Result<GamesDbInfo> {
        let url = format!("https://gamesdb.gog.com/platforms/gog/external_releases/{}", game.id);
        
        let response: serde_json::Value = self.client
            .get(&url)
            .send()
            .await?
            .json()
            .await?;

        let mut info = GamesDbInfo {
            cover: String::new(),
            vertical_cover: String::new(),
            background: String::new(),
            summary: std::collections::HashMap::new(),
            genre: std::collections::HashMap::new(),
        };

        if let Some(game_data) = response.get("game") {
            if let Some(cover) = game_data.get("cover").and_then(|c| c.get("url_format")).and_then(|u| u.as_str()) {
                info.cover = cover.replace("{formatter}.{ext}", ".png");
            }
            if let Some(vc) = game_data.get("vertical_cover").and_then(|c| c.get("url_format")).and_then(|u| u.as_str()) {
                info.vertical_cover = vc.replace("{formatter}.{ext}", ".png");
            }
            if let Some(bg) = game_data.get("background").and_then(|c| c.get("url_format")).and_then(|u| u.as_str()) {
                info.background = bg.replace("{formatter}.{ext}", ".png");
            }
            if let Some(summary) = game_data.get("summary").and_then(|s| s.as_object()) {
                for (key, value) in summary {
                    if let Some(v) = value.as_str() {
                        info.summary.insert(key.clone(), v.to_string());
                    }
                }
            }
        }

        Ok(info)
    }
}
