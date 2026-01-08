use serde::{Deserialize, Serialize};
use std::fs;
use std::path::PathBuf;
use super::config::get_data_dir;
use super::error::Result;
use super::gog_api::{GogApi, UserData, UserProfile};

/// Represents a user account
#[flutter_rust_bridge::frb(non_opaque)]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Account {
    pub user_id: String,
    pub username: String,
    pub email: Option<String>,
    pub avatar_url: Option<String>,
    pub refresh_token: String,
    pub added_at: String,
    pub last_login: Option<String>,
}

/// Account manager for multi-account support
#[flutter_rust_bridge::frb(non_opaque)]
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct AccountManager {
    pub accounts: Vec<Account>,
    pub active_account_id: Option<String>,
}

#[flutter_rust_bridge::frb(ignore)]
impl AccountManager {
    fn get_accounts_file_path() -> PathBuf {
        get_data_dir().join("accounts.json")
    }

    pub fn load() -> Result<Self> {
        let path = Self::get_accounts_file_path();
        if path.exists() {
            let content = fs::read_to_string(&path)?;
            let manager: AccountManager = serde_json::from_str(&content).unwrap_or_default();
            Ok(manager)
        } else {
            Ok(AccountManager::default())
        }
    }

    pub fn save(&self) -> Result<()> {
        let path = Self::get_accounts_file_path();
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent)?;
        }
        let content = serde_json::to_string_pretty(self)?;
        fs::write(&path, content)?;
        Ok(())
    }

    pub fn add_account(&mut self, account: Account) -> Result<()> {
        self.accounts.retain(|a| a.user_id != account.user_id);
        self.accounts.push(account);
        
        if self.active_account_id.is_none() && !self.accounts.is_empty() {
            self.active_account_id = Some(self.accounts[0].user_id.clone());
        }
        
        self.save()
    }

    pub fn remove_account(&mut self, user_id: &str) -> Result<()> {
        self.accounts.retain(|a| a.user_id != user_id);
        
        if self.active_account_id.as_deref() == Some(user_id) {
            self.active_account_id = self.accounts.first().map(|a| a.user_id.clone());
        }
        
        self.save()
    }

    pub fn set_active_account(&mut self, user_id: &str) -> Result<bool> {
        if self.accounts.iter().any(|a| a.user_id == user_id) {
            self.active_account_id = Some(user_id.to_string());
            self.save()?;
            Ok(true)
        } else {
            Ok(false)
        }
    }

    pub fn get_active_account(&self) -> Option<&Account> {
        self.active_account_id.as_ref()
            .and_then(|id| self.accounts.iter().find(|a| &a.user_id == id))
    }

    pub fn get_all_accounts(&self) -> &[Account] {
        &self.accounts
    }

    pub fn get_account(&self, user_id: &str) -> Option<&Account> {
        self.accounts.iter().find(|a| a.user_id == user_id)
    }

    pub fn update_refresh_token(&mut self, user_id: &str, refresh_token: &str) -> Result<()> {
        if let Some(account) = self.accounts.iter_mut().find(|a| a.user_id == user_id) {
            account.refresh_token = refresh_token.to_string();
            account.last_login = Some(chrono::Utc::now().to_rfc3339());
        }
        self.save()
    }

    pub fn update_avatar(&mut self, user_id: &str, avatar_url: &str) -> Result<()> {
        if let Some(account) = self.accounts.iter_mut().find(|a| a.user_id == user_id) {
            account.avatar_url = Some(avatar_url.to_string());
        }
        self.save()
    }
}

#[flutter_rust_bridge::frb(ignore)]
pub fn create_account_from_user_data(
    user_data: &UserData,
    profile: Option<&UserProfile>,
    refresh_token: &str,
) -> Account {
    let avatar_url = profile
        .and_then(|p| p.avatars.as_ref())
        .and_then(|a| a.medium.clone());

    Account {
        user_id: user_data.user_id.clone(),
        username: user_data.username.clone(),
        email: user_data.email.clone(),
        avatar_url,
        refresh_token: refresh_token.to_string(),
        added_at: chrono::Utc::now().to_rfc3339(),
        last_login: Some(chrono::Utc::now().to_rfc3339()),
    }
}

#[flutter_rust_bridge::frb(ignore)]
pub async fn fetch_user_avatar(api: &GogApi, user_id: &str) -> Result<Option<String>> {
    match api.get_user_profile(user_id).await {
        Ok(profile) => {
            // Try to get the medium avatar, falling back to other sizes
            let avatar = profile.avatars.and_then(|a| {
                a.medium
                    .or(a.medium2x)
                    .or(a.large)
                    .or(a.large2x)
                    .or(a.small)
                    .or(a.small2x)
            });
            Ok(avatar)
        }
        Err(e) => {
            // Log the error but don't fail - avatar is optional
            eprintln!("Failed to fetch user avatar for {}: {:?}", user_id, e);
            Ok(None)
        }
    }
}
