use axum::extract::{Path, Query, State};
use axum::http::StatusCode;
use axum::Json;
use tracing::error;
use uuid::Uuid;

use crate::db;
use crate::models::{AppDetail, AppListing, ListQuery};
use crate::AppState;

pub async fn list(
    State(state): State<AppState>,
    Query(query): Query<ListQuery>,
) -> Result<Json<Vec<AppListing>>, StatusCode> {
    let apps = db::list_apps(&state.db, &query).await.map_err(|e| {
        error!("Failed to list apps: {}", e);
        StatusCode::INTERNAL_SERVER_ERROR
    })?;
    Ok(Json(apps))
}

pub async fn detail(
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
) -> Result<Json<AppDetail>, StatusCode> {
    let app = db::get_app_detail(&state.db, id)
        .await
        .map_err(|e| {
            error!("Failed to get app detail {}: {}", id, e);
            StatusCode::INTERNAL_SERVER_ERROR
        })?
        .ok_or(StatusCode::NOT_FOUND)?;
    Ok(Json(app))
}

pub async fn download(
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
) -> Result<Json<serde_json::Value>, StatusCode> {
    let app = db::get_app(&state.db, id)
        .await
        .map_err(|e| {
            error!("Failed to get app {}: {}", id, e);
            StatusCode::INTERNAL_SERVER_ERROR
        })?
        .ok_or(StatusCode::NOT_FOUND)?;

    let url = app.download_url.ok_or(StatusCode::NOT_FOUND)?;

    let _ = db::increment_downloads(&state.db, id).await;

    Ok(Json(serde_json::json!({
        "download_url": url,
        "flatpak_id": app.flatpak_id,
    })))
}
