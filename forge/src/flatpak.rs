use serde::Deserialize;
use tokio::process::Command;

#[derive(Debug, Clone, Deserialize)]
pub struct InstalledApp {
    pub app_id: String,
    pub name: String,
    pub version: String,
    pub origin: String,
}

#[derive(Debug, Clone)]
pub struct UpdateInfo {
    pub app_id: String,
    pub name: String,
    pub remote_version: String,
}

pub async fn list_installed() -> Result<Vec<InstalledApp>, String> {
    let output = Command::new("flatpak")
        .args(["list", "--app", "--columns=application,name,version,origin"])
        .output()
        .await
        .map_err(|e| format!("Failed to run flatpak: {}", e))?;

    if !output.status.success() {
        return Err(String::from_utf8_lossy(&output.stderr).to_string());
    }

    let stdout = String::from_utf8_lossy(&output.stdout);
    let apps = stdout
        .lines()
        .filter(|line| !line.is_empty())
        .filter_map(|line| {
            let parts: Vec<&str> = line.split('\t').collect();
            if parts.len() >= 4 {
                Some(InstalledApp {
                    app_id: parts[0].to_string(),
                    name: parts[1].to_string(),
                    version: parts[2].to_string(),
                    origin: parts[3].to_string(),
                })
            } else {
                None
            }
        })
        .collect();

    Ok(apps)
}

pub async fn install(app_id: String) -> Result<String, String> {
    let output = Command::new("flatpak")
        .args(["install", "--user", "-y", "flathub", &app_id])
        .output()
        .await
        .map_err(|e| format!("Failed to run flatpak install: {}", e))?;

    if output.status.success() {
        Ok(app_id)
    } else {
        Err(format!(
            "Install failed: {}",
            String::from_utf8_lossy(&output.stderr)
        ))
    }
}

pub async fn uninstall(app_id: String) -> Result<String, String> {
    let output = Command::new("flatpak")
        .args(["uninstall", "--user", "-y", &app_id])
        .output()
        .await
        .map_err(|e| format!("Failed to run flatpak uninstall: {}", e))?;

    if output.status.success() {
        Ok(app_id)
    } else {
        Err(format!(
            "Uninstall failed: {}",
            String::from_utf8_lossy(&output.stderr)
        ))
    }
}

pub async fn update(app_id: String) -> Result<String, String> {
    let output = Command::new("flatpak")
        .args(["update", "--user", "-y", &app_id])
        .output()
        .await
        .map_err(|e| format!("Failed to run flatpak update: {}", e))?;

    if output.status.success() {
        Ok(app_id)
    } else {
        Err(format!(
            "Update failed: {}",
            String::from_utf8_lossy(&output.stderr)
        ))
    }
}

pub async fn check_updates() -> Result<Vec<UpdateInfo>, String> {
    let output = Command::new("flatpak")
        .args([
            "remote-ls",
            "--user",
            "--updates",
            "--columns=application,name,version",
        ])
        .output()
        .await
        .map_err(|e| format!("Failed to check updates: {}", e))?;

    if !output.status.success() {
        return Err(String::from_utf8_lossy(&output.stderr).to_string());
    }

    let stdout = String::from_utf8_lossy(&output.stdout);
    let updates = stdout
        .lines()
        .filter(|line| !line.is_empty())
        .filter_map(|line| {
            let parts: Vec<&str> = line.split('\t').collect();
            if parts.len() >= 3 {
                Some(UpdateInfo {
                    app_id: parts[0].to_string(),
                    name: parts[1].to_string(),
                    remote_version: parts[2].to_string(),
                })
            } else {
                None
            }
        })
        .collect();

    Ok(updates)
}

pub async fn update_all() -> Result<String, String> {
    let output = Command::new("flatpak")
        .args(["update", "--user", "-y"])
        .output()
        .await
        .map_err(|e| format!("Failed to run flatpak update: {}", e))?;

    if output.status.success() {
        Ok("All apps updated".to_string())
    } else {
        Err(format!(
            "Update failed: {}",
            String::from_utf8_lossy(&output.stderr)
        ))
    }
}

pub async fn get_permissions(app_id: &str) -> Result<Vec<String>, String> {
    let output = Command::new("flatpak")
        .args(["info", "--show-permissions", app_id])
        .output()
        .await
        .map_err(|e| format!("Failed to get permissions: {}", e))?;

    let stdout = String::from_utf8_lossy(&output.stdout);
    Ok(stdout
        .lines()
        .filter(|l| !l.is_empty())
        .map(String::from)
        .collect())
}
