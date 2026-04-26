use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::Type, PartialEq)]
#[sqlx(type_name = "submission_status", rename_all = "lowercase")]
pub enum SubmissionStatus {
    Pending,
    Scanning,
    Approved,
    Rejected,
}

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct App {
    pub id: Uuid,
    pub flatpak_id: String,
    pub name: String,
    pub summary: Option<String>,
    pub description: Option<String>,
    pub developer_name: String,
    pub developer_email: String,
    pub version: String,
    pub category: String,
    pub icon_url: Option<String>,
    pub download_url: Option<String>,
    pub permissions: serde_json::Value,
    pub status: SubmissionStatus,
    pub scan_passed: Option<bool>,
    pub scan_report: Option<serde_json::Value>,
    pub downloads: i64,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Deserialize)]
pub struct SubmitApp {
    pub flatpak_id: String,
    pub name: String,
    pub summary: Option<String>,
    pub description: Option<String>,
    pub developer_name: String,
    pub developer_email: String,
    pub version: String,
    pub category: String,
}

impl SubmitApp {
    pub fn validate(&self) -> Result<(), String> {
        if self.flatpak_id.is_empty() || self.flatpak_id.len() > 255 {
            return Err("flatpak_id must be 1-255 characters".into());
        }
        let parts: Vec<&str> = self.flatpak_id.split('.').collect();
        if parts.len() < 3 || parts.iter().any(|p| p.is_empty()) {
            return Err("flatpak_id must be reverse-DNS format (e.g. org.example.App)".into());
        }
        if !self.flatpak_id.chars().all(|c| c.is_alphanumeric() || c == '.' || c == '-' || c == '_') {
            return Err("flatpak_id contains invalid characters".into());
        }

        if self.name.trim().is_empty() || self.name.len() > 255 {
            return Err("name must be 1-255 non-blank characters".into());
        }

        if self.developer_name.trim().is_empty() || self.developer_name.len() > 255 {
            return Err("developer_name must be 1-255 non-blank characters".into());
        }

        if !self.developer_email.contains('@')
            || self.developer_email.len() < 5
            || self.developer_email.len() > 255
        {
            return Err("developer_email must be a valid email address".into());
        }

        if self.version.trim().is_empty() || self.version.len() > 128 {
            return Err("version must be 1-128 non-blank characters".into());
        }

        if self.category.trim().is_empty() || self.category.len() > 128 {
            return Err("category must be 1-128 non-blank characters".into());
        }

        if let Some(ref s) = self.summary {
            if s.len() > 1024 {
                return Err("summary must be under 1024 characters".into());
            }
        }

        if let Some(ref d) = self.description {
            if d.len() > 16384 {
                return Err("description must be under 16384 characters".into());
            }
        }

        Ok(())
    }
}

#[derive(Debug, Serialize)]
pub struct AppListing {
    pub id: Uuid,
    pub flatpak_id: String,
    pub name: String,
    pub summary: Option<String>,
    pub developer_name: String,
    pub version: String,
    pub category: String,
    pub icon_url: Option<String>,
    pub permissions: serde_json::Value,
    pub downloads: i64,
}

#[derive(Debug, Serialize)]
pub struct AppDetail {
    pub id: Uuid,
    pub flatpak_id: String,
    pub name: String,
    pub summary: Option<String>,
    pub description: Option<String>,
    pub developer_name: String,
    pub version: String,
    pub category: String,
    pub icon_url: Option<String>,
    pub download_url: Option<String>,
    pub permissions: serde_json::Value,
    pub downloads: i64,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Deserialize)]
pub struct ListQuery {
    pub category: Option<String>,
    pub search: Option<String>,
    pub page: Option<i64>,
    pub per_page: Option<i64>,
}

#[derive(Debug, Serialize)]
pub struct ScanResult {
    pub passed: bool,
    pub clamav_clean: bool,
    pub permissions_clean: bool,
    pub violations: Vec<String>,
    pub detected_permissions: Vec<String>,
}

#[cfg(test)]
mod tests {
    use super::*;

    fn valid_submission() -> SubmitApp {
        SubmitApp {
            flatpak_id: "org.example.TestApp".into(),
            name: "Test App".into(),
            summary: Some("A test app".into()),
            description: None,
            developer_name: "Test Dev".into(),
            developer_email: "dev@example.com".into(),
            version: "1.0.0".into(),
            category: "Utility".into(),
        }
    }

    #[test]
    fn valid_submission_passes() {
        assert!(valid_submission().validate().is_ok());
    }

    #[test]
    fn empty_flatpak_id_rejected() {
        let mut s = valid_submission();
        s.flatpak_id = "".into();
        assert!(s.validate().unwrap_err().contains("flatpak_id"));
    }

    #[test]
    fn short_flatpak_id_rejected() {
        let mut s = valid_submission();
        s.flatpak_id = "org.app".into();
        assert!(s.validate().unwrap_err().contains("reverse-DNS"));
    }

    #[test]
    fn flatpak_id_invalid_chars_rejected() {
        let mut s = valid_submission();
        s.flatpak_id = "org.example.App Name".into();
        assert!(s.validate().unwrap_err().contains("invalid characters"));
    }

    #[test]
    fn empty_name_rejected() {
        let mut s = valid_submission();
        s.name = "   ".into();
        assert!(s.validate().unwrap_err().contains("name"));
    }

    #[test]
    fn invalid_email_rejected() {
        let mut s = valid_submission();
        s.developer_email = "not-an-email".into();
        assert!(s.validate().unwrap_err().contains("email"));
    }

    #[test]
    fn empty_version_rejected() {
        let mut s = valid_submission();
        s.version = "  ".into();
        assert!(s.validate().unwrap_err().contains("version"));
    }

    #[test]
    fn long_summary_rejected() {
        let mut s = valid_submission();
        s.summary = Some("x".repeat(1025));
        assert!(s.validate().unwrap_err().contains("summary"));
    }

    #[test]
    fn long_description_rejected() {
        let mut s = valid_submission();
        s.description = Some("x".repeat(16385));
        assert!(s.validate().unwrap_err().contains("description"));
    }

    #[test]
    fn none_summary_and_description_ok() {
        let mut s = valid_submission();
        s.summary = None;
        s.description = None;
        assert!(s.validate().is_ok());
    }
}
