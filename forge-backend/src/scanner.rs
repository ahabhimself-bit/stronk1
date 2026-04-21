use std::net::ToSocketAddrs;
use std::path::Path;
use tokio::process::Command;
use tracing::{info, warn};

use crate::models::ScanResult;

const FORBIDDEN_PERMISSIONS: &[&str] = &[
    "filesystem=host",
    "filesystem=home",
    "filesystem=host-etc",
    "filesystem=host-os",
];

const SUSPICIOUS_PERMISSIONS: &[&str] = &[
    "filesystem=/",
    "device=all",
];

pub async fn scan_flatpak_bundle(
    bundle_path: &Path,
    clamav_addr: String,
) -> Result<ScanResult, String> {
    let mut violations = Vec::new();

    let clamav_clean = scan_clamav(bundle_path, clamav_addr).await?;
    if !clamav_clean {
        violations.push("ClamAV detected malware in the submitted bundle".to_string());
    }

    let permissions = extract_permissions(bundle_path).await?;
    let permissions_clean = check_permissions(&permissions, &mut violations);

    let passed = clamav_clean && permissions_clean;

    Ok(ScanResult {
        passed,
        clamav_clean,
        permissions_clean,
        violations,
        detected_permissions: permissions,
    })
}

async fn scan_clamav(path: &Path, addr: String) -> Result<bool, String> {
    let socket_addr = addr
        .to_socket_addrs()
        .map_err(|e| format!("Invalid ClamAV address '{}': {}", addr, e))?
        .next()
        .ok_or_else(|| format!("ClamAV address '{}' did not resolve", addr))?;
    let tcp = clamav_client::tokio::Tcp { host_address: socket_addr };

    let response = clamav_client::tokio::scan_file(path, tcp, None)
        .await
        .map_err(|e| format!("ClamAV scan failed: {}", e))?;

    let clean = clamav_client::clean(&response)
        .map_err(|e| format!("ClamAV response parse failed: {}", e))?;

    if clean {
        info!("ClamAV scan clean: {}", path.display());
    } else {
        warn!("ClamAV detected threat in: {}", path.display());
    }
    Ok(clean)
}

async fn extract_permissions(bundle_path: &Path) -> Result<Vec<String>, String> {
    let output = Command::new("flatpak")
        .args([
            "info",
            "--show-permissions",
            "--file-access",
            bundle_path.to_str().ok_or("Invalid path")?,
        ])
        .output()
        .await
        .map_err(|e| format!("Failed to extract permissions: {}", e))?;

    let stdout = String::from_utf8_lossy(&output.stdout);
    Ok(stdout
        .lines()
        .map(|l| l.trim().to_string())
        .filter(|l| !l.is_empty())
        .collect())
}

fn check_permissions(permissions: &[String], violations: &mut Vec<String>) -> bool {
    let mut clean = true;

    for perm in permissions {
        let normalized = perm.to_lowercase();

        for forbidden in FORBIDDEN_PERMISSIONS {
            if normalized.contains(forbidden) {
                violations.push(format!(
                    "Forbidden permission: {} — Stronk does not allow apps to access the host filesystem",
                    perm
                ));
                clean = false;
            }
        }

        for suspicious in SUSPICIOUS_PERMISSIONS {
            if normalized.contains(suspicious) {
                violations.push(format!(
                    "Suspicious permission: {} — requires manual review",
                    perm
                ));
                clean = false;
            }
        }
    }

    clean
}

pub fn extract_permissions_metadata(raw_permissions: &[String]) -> serde_json::Value {
    let mut categorized = serde_json::Map::new();

    let mut filesystem = Vec::new();
    let mut network = Vec::new();
    let mut device = Vec::new();
    let mut other = Vec::new();

    for perm in raw_permissions {
        if perm.starts_with("filesystem=") || perm.starts_with("[Session Bus Policy]") {
            filesystem.push(perm.clone());
        } else if perm.contains("network") || perm.starts_with("share=network") {
            network.push(perm.clone());
        } else if perm.starts_with("device=") {
            device.push(perm.clone());
        } else {
            other.push(perm.clone());
        }
    }

    if !filesystem.is_empty() {
        categorized.insert("filesystem".to_string(), serde_json::json!(filesystem));
    }
    if !network.is_empty() {
        categorized.insert("network".to_string(), serde_json::json!(network));
    }
    if !device.is_empty() {
        categorized.insert("device".to_string(), serde_json::json!(device));
    }
    if !other.is_empty() {
        categorized.insert("other".to_string(), serde_json::json!(other));
    }

    serde_json::Value::Object(categorized)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rejects_filesystem_host() {
        let perms = vec!["filesystem=host".to_string()];
        let mut violations = Vec::new();
        assert!(!check_permissions(&perms, &mut violations));
        assert_eq!(violations.len(), 1);
        assert!(violations[0].contains("Forbidden permission"));
    }

    #[test]
    fn rejects_filesystem_home() {
        let perms = vec!["filesystem=home".to_string()];
        let mut violations = Vec::new();
        assert!(!check_permissions(&perms, &mut violations));
        assert!(violations[0].contains("filesystem=home"));
    }

    #[test]
    fn allows_safe_permissions() {
        let perms = vec![
            "share=network".to_string(),
            "share=ipc".to_string(),
            "filesystem=xdg-download".to_string(),
            "socket=wayland".to_string(),
        ];
        let mut violations = Vec::new();
        assert!(check_permissions(&perms, &mut violations));
        assert!(violations.is_empty());
    }

    #[test]
    fn rejects_host_etc() {
        let perms = vec!["filesystem=host-etc".to_string()];
        let mut violations = Vec::new();
        assert!(!check_permissions(&perms, &mut violations));
    }

    #[test]
    fn flags_device_all() {
        let perms = vec!["device=all".to_string()];
        let mut violations = Vec::new();
        assert!(!check_permissions(&perms, &mut violations));
        assert!(violations[0].contains("Suspicious permission"));
    }
}
