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
