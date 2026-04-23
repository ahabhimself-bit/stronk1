use serde::Deserialize;
use std::fmt::Write;
use tokio::process::Command;

fn url_encode(input: &str) -> String {
    let mut encoded = String::with_capacity(input.len() * 3);
    for byte in input.bytes() {
        match byte {
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'-' | b'_' | b'.' | b'~' => {
                encoded.push(byte as char);
            }
            _ => {
                let _ = write!(encoded, "%{:02X}", byte);
            }
        }
    }
    encoded
}

#[derive(Debug, Clone, Deserialize)]
pub struct AppInfo {
    #[serde(rename = "flatpakAppId")]
    pub app_id: String,
    pub name: String,
    pub summary: Option<String>,
    pub description: Option<String>,
    #[serde(rename = "iconDesktopUrl")]
    pub icon_url: Option<String>,
    #[serde(rename = "currentReleaseVersion")]
    pub version: Option<String>,
    #[serde(rename = "developerName")]
    pub developer: Option<String>,
    #[serde(rename = "categories")]
    pub categories: Option<Vec<Category>>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct Category {
    pub name: String,
}

#[derive(Debug, Clone, Deserialize)]
struct SearchResponse {
    hits: Vec<AppInfo>,
}

const FLATHUB_API: &str = "https://flathub.org/api/v2";

async fn fetch_json(url: &str) -> Result<String, String> {
    let output = Command::new("curl")
        .args(["-sS", "--max-time", "10", url])
        .output()
        .await
        .map_err(|e| format!("Network error: {}", e))?;

    if !output.status.success() {
        return Err(format!(
            "HTTP error: {}",
            String::from_utf8_lossy(&output.stderr)
        ));
    }

    String::from_utf8(output.stdout).map_err(|e| format!("Invalid UTF-8: {}", e))
}

pub async fn search(query: String) -> Result<Vec<AppInfo>, String> {
    let url = format!("{}/search?q={}&locale=en", FLATHUB_API, url_encode(&query));
    let json = fetch_json(&url).await?;
    let response: SearchResponse =
        serde_json::from_str(&json).map_err(|e| format!("Parse error: {}", e))?;
    Ok(response.hits)
}

pub async fn fetch_popular() -> Result<Vec<AppInfo>, String> {
    let url = format!("{}/popular?locale=en", FLATHUB_API);
    let json = fetch_json(&url).await?;
    let apps: Vec<AppInfo> =
        serde_json::from_str(&json).map_err(|e| format!("Parse error: {}", e))?;
    Ok(apps)
}

pub async fn fetch_category(category: String) -> Result<Vec<AppInfo>, String> {
    let url = format!("{}/category/{}", FLATHUB_API, url_encode(&category));
    let json = fetch_json(&url).await?;
    let apps: Vec<AppInfo> =
        serde_json::from_str(&json).map_err(|e| format!("Parse error: {}", e))?;
    Ok(apps)
}

pub async fn fetch_app_detail(app_id: &str) -> Result<AppInfo, String> {
    let url = format!("{}/appstream/{}", FLATHUB_API, url_encode(app_id));
    let json = fetch_json(&url).await?;
    serde_json::from_str(&json).map_err(|e| format!("Parse error: {}", e))
}

pub const CATEGORIES: &[&str] = &[
    "AudioVideo",
    "Development",
    "Education",
    "Game",
    "Graphics",
    "Network",
    "Office",
    "Science",
    "System",
    "Utility",
];
