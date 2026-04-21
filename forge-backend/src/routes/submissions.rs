use axum::extract::{Multipart, State};
use axum::http::StatusCode;
use axum::Json;
use tempfile::NamedTempFile;
use tokio::io::AsyncWriteExt;
use tracing::{error, info};

use crate::models::{SubmissionStatus, SubmitApp};
use crate::{db, scanner, AppState};

pub async fn submit(
    State(state): State<AppState>,
    mut multipart: Multipart,
) -> Result<Json<serde_json::Value>, StatusCode> {
    let mut metadata: Option<SubmitApp> = None;
    let mut bundle_data: Option<Vec<u8>> = None;

    while let Some(field) = multipart.next_field().await.map_err(|e| {
        error!("Multipart error: {}", e);
        StatusCode::BAD_REQUEST
    })? {
        match field.name() {
            Some("metadata") => {
                let text = field.text().await.map_err(|_| StatusCode::BAD_REQUEST)?;
                metadata =
                    Some(serde_json::from_str(&text).map_err(|_| StatusCode::BAD_REQUEST)?);
            }
            Some("bundle") => {
                bundle_data = Some(field.bytes().await.map_err(|_| StatusCode::BAD_REQUEST)?.to_vec());
            }
            _ => {}
        }
    }

    let metadata = metadata.ok_or(StatusCode::BAD_REQUEST)?;
    let bundle_data = bundle_data.ok_or(StatusCode::BAD_REQUEST)?;

    let app = db::insert_app(&state.db, &metadata)
        .await
        .map_err(|e| {
            error!("DB insert failed: {}", e);
            StatusCode::INTERNAL_SERVER_ERROR
        })?;

    let _ = db::log_audit(
        &state.db,
        app.id,
        "submitted",
        Some(&serde_json::json!({
            "developer": metadata.developer_name,
            "version": metadata.version,
        })),
    )
    .await;

    info!("New submission: {} ({})", app.name, app.flatpak_id);

    let app_id = app.id;
    let flatpak_id = app.flatpak_id.clone();
    let db = state.db.clone();
    let storage = state.storage.clone();
    let clamav_addr = state.config.clamav_addr.clone();

    tokio::spawn(async move {
        let _ = db::set_app_status(&db, app_id, SubmissionStatus::Scanning).await;

        let tmp = match write_temp_bundle(&bundle_data).await {
            Ok(t) => t,
            Err(e) => {
                error!("Failed to write temp bundle: {}", e);
                let _ = db::set_app_status(&db, app_id, SubmissionStatus::Rejected).await;
                return;
            }
        };

        let scan = match scanner::scan_flatpak_bundle(tmp.path(), clamav_addr).await {
            Ok(s) => s,
            Err(e) => {
                error!("Scan failed for {}: {}", flatpak_id, e);
                let _ = db::set_app_status(&db, app_id, SubmissionStatus::Rejected).await;
                return;
            }
        };

        let report = serde_json::to_value(&scan).unwrap_or_default();
        let _ = db::update_scan_result(&db, app_id, scan.passed, &report).await;
        let _ = db::log_audit(
            &db,
            app_id,
            if scan.passed { "scan_passed" } else { "scan_rejected" },
            Some(&report),
        )
        .await;

        if scan.passed {
            let key = format!("bundles/{}/{}.flatpak", flatpak_id, app_id);
            match storage.upload(&key, &bundle_data, "application/vnd.flatpak").await {
                Ok(url) => {
                    let permissions = scanner::extract_permissions_metadata(
                        &extract_perms_from_report(&report),
                    );
                    let _ = db::set_download_url(&db, app_id, &url, &permissions).await;
                    info!("Approved and uploaded: {} → {}", flatpak_id, url);
                }
                Err(e) => {
                    error!("S3 upload failed for {}: {}", flatpak_id, e);
                }
            }
        } else {
            info!(
                "Rejected {}: {} violation(s)",
                flatpak_id,
                scan.violations.len()
            );
        }
    });

    Ok(Json(serde_json::json!({
        "id": app_id,
        "status": "pending",
        "message": "Submission received. Security scan in progress.",
    })))
}

pub async fn status(
    State(state): State<AppState>,
    axum::extract::Path(id): axum::extract::Path<uuid::Uuid>,
) -> Result<Json<serde_json::Value>, StatusCode> {
    let app = db::get_app(&state.db, id)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?
        .ok_or(StatusCode::NOT_FOUND)?;

    Ok(Json(serde_json::json!({
        "id": app.id,
        "flatpak_id": app.flatpak_id,
        "status": app.status,
        "scan_passed": app.scan_passed,
        "scan_report": app.scan_report,
    })))
}

async fn write_temp_bundle(data: &[u8]) -> Result<NamedTempFile, String> {
    let tmp = NamedTempFile::new().map_err(|e| format!("Temp file: {}", e))?;
    let mut file = tokio::fs::File::from_std(tmp.reopen().map_err(|e| e.to_string())?);
    file.write_all(data)
        .await
        .map_err(|e| format!("Write: {}", e))?;
    Ok(tmp)
}

fn extract_perms_from_report(report: &serde_json::Value) -> Vec<String> {
    report
        .get("detected_permissions")
        .and_then(|v| v.as_array())
        .map(|arr| {
            arr.iter()
                .filter_map(|v| v.as_str().map(String::from))
                .collect()
        })
        .unwrap_or_default()
}
