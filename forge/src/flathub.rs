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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn url_encode_passthrough() {
        assert_eq!(url_encode("hello"), "hello");
        assert_eq!(url_encode("A-Z_0.9~test"), "A-Z_0.9~test");
    }

    #[test]
    fn url_encode_special_chars() {
        assert_eq!(url_encode("hello world"), "hello%20world");
        assert_eq!(url_encode("a+b=c"), "a%2Bb%3Dc");
        assert_eq!(url_encode("100%"), "100%25");
    }

    #[test]
    fn url_encode_unicode() {
        let encoded = url_encode("café");
        assert!(encoded.starts_with("caf"));
        assert!(encoded.contains('%'));
    }

    #[test]
    fn url_encode_empty() {
        assert_eq!(url_encode(""), "");
    }

    #[test]
    fn deserialize_app_info() {
        let json = r#"{
            "flatpakAppId": "org.test.App",
            "name": "Test App",
            "summary": "A test",
            "description": "<p>Full description</p>",
            "iconDesktopUrl": "https://example.com/icon.png",
            "currentReleaseVersion": "1.0",
            "developerName": "Test Dev",
            "categories": [{"name": "Utility"}]
        }"#;
        let app: AppInfo = serde_json::from_str(json).unwrap();
        assert_eq!(app.app_id, "org.test.App");
        assert_eq!(app.name, "Test App");
        assert_eq!(app.summary.as_deref(), Some("A test"));
        assert_eq!(app.developer.as_deref(), Some("Test Dev"));
        assert_eq!(app.categories.as_ref().unwrap()[0].name, "Utility");
    }

    #[test]
    fn deserialize_app_info_minimal() {
        let json = r#"{"flatpakAppId": "org.test.App", "name": "App"}"#;
        let app: AppInfo = serde_json::from_str(json).unwrap();
        assert_eq!(app.app_id, "org.test.App");
        assert!(app.summary.is_none());
        assert!(app.version.is_none());
    }

    #[test]
    fn deserialize_search_response() {
        let json = r#"{"hits": [
            {"flatpakAppId": "org.a.A", "name": "A"},
            {"flatpakAppId": "org.b.B", "name": "B"}
        ]}"#;
        let resp: SearchResponse = serde_json::from_str(json).unwrap();
        assert_eq!(resp.hits.len(), 2);
        assert_eq!(resp.hits[0].app_id, "org.a.A");
    }
}
