use sqlx::postgres::PgPoolOptions;
use sqlx::PgPool;
use uuid::Uuid;

use crate::models::{App, AppDetail, AppListing, ListQuery, SubmissionStatus, SubmitApp};

pub async fn connect(database_url: &str) -> Result<PgPool, sqlx::Error> {
    PgPoolOptions::new()
        .max_connections(10)
        .connect(database_url)
        .await
}

pub async fn run_migrations(pool: &PgPool) -> Result<(), sqlx::Error> {
    sqlx::raw_sql(include_str!("../migrations/001_initial.sql"))
        .execute(pool)
        .await?;
    Ok(())
}

pub async fn insert_app(pool: &PgPool, submission: &SubmitApp) -> Result<App, sqlx::Error> {
    sqlx::query_as::<_, App>(
        r#"
        INSERT INTO apps (flatpak_id, name, summary, description, developer_name, developer_email, version, category)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
        RETURNING *
        "#,
    )
    .bind(&submission.flatpak_id)
    .bind(&submission.name)
    .bind(&submission.summary)
    .bind(&submission.description)
    .bind(&submission.developer_name)
    .bind(&submission.developer_email)
    .bind(&submission.version)
    .bind(&submission.category)
    .fetch_one(pool)
    .await
}

pub async fn get_app(pool: &PgPool, id: Uuid) -> Result<Option<App>, sqlx::Error> {
    sqlx::query_as::<_, App>("SELECT * FROM apps WHERE id = $1")
        .bind(id)
        .fetch_optional(pool)
        .await
}

pub async fn get_app_detail(pool: &PgPool, id: Uuid) -> Result<Option<AppDetail>, sqlx::Error> {
    let app = get_app(pool, id).await?;
    Ok(app.map(|a| AppDetail {
        id: a.id,
        flatpak_id: a.flatpak_id,
        name: a.name,
        summary: a.summary,
        description: a.description,
        developer_name: a.developer_name,
        version: a.version,
        category: a.category,
        icon_url: a.icon_url,
        download_url: a.download_url,
        permissions: a.permissions,
        downloads: a.downloads,
        created_at: a.created_at,
    }))
}

pub async fn list_apps(pool: &PgPool, query: &ListQuery) -> Result<Vec<AppListing>, sqlx::Error> {
    let page = query.page.unwrap_or(1).max(1);
    let per_page = query.per_page.unwrap_or(50).clamp(1, 100);
    let offset = (page - 1) * per_page;

    let rows = match (&query.category, &query.search) {
        (Some(cat), Some(search)) => {
            let pattern = format!("%{}%", search.replace('%', r"\%").replace('_', r"\_"));
            sqlx::query_as::<_, App>(
                "SELECT * FROM apps WHERE status = 'approved' AND category = $1 AND (name ILIKE $2 OR summary ILIKE $2) ORDER BY downloads DESC LIMIT $3 OFFSET $4",
            )
            .bind(cat)
            .bind(&pattern)
            .bind(per_page)
            .bind(offset)
            .fetch_all(pool)
            .await?
        }
        (Some(cat), None) => {
            sqlx::query_as::<_, App>(
                "SELECT * FROM apps WHERE status = 'approved' AND category = $1 ORDER BY downloads DESC LIMIT $2 OFFSET $3",
            )
            .bind(cat)
            .bind(per_page)
            .bind(offset)
            .fetch_all(pool)
            .await?
        }
        (None, Some(search)) => {
            let pattern = format!("%{}%", search.replace('%', r"\%").replace('_', r"\_"));
            sqlx::query_as::<_, App>(
                "SELECT * FROM apps WHERE status = 'approved' AND (name ILIKE $1 OR summary ILIKE $1) ORDER BY downloads DESC LIMIT $2 OFFSET $3",
            )
            .bind(&pattern)
            .bind(per_page)
            .bind(offset)
            .fetch_all(pool)
            .await?
        }
        (None, None) => {
            sqlx::query_as::<_, App>(
                "SELECT * FROM apps WHERE status = 'approved' ORDER BY downloads DESC LIMIT $1 OFFSET $2",
            )
            .bind(per_page)
            .bind(offset)
            .fetch_all(pool)
            .await?
        }
    };

    Ok(rows
        .into_iter()
        .map(|a| AppListing {
            id: a.id,
            flatpak_id: a.flatpak_id,
            name: a.name,
            summary: a.summary,
            developer_name: a.developer_name,
            version: a.version,
            category: a.category,
            icon_url: a.icon_url,
            permissions: a.permissions,
            downloads: a.downloads,
        })
        .collect())
}

pub async fn update_scan_result(
    pool: &PgPool,
    app_id: Uuid,
    passed: bool,
    report: &serde_json::Value,
) -> Result<(), sqlx::Error> {
    let status = if passed {
        SubmissionStatus::Approved
    } else {
        SubmissionStatus::Rejected
    };

    sqlx::query(
        "UPDATE apps SET scan_passed = $1, scan_report = $2, status = $3, updated_at = now() WHERE id = $4",
    )
    .bind(passed)
    .bind(report)
    .bind(status)
    .bind(app_id)
    .execute(pool)
    .await?;

    Ok(())
}

pub async fn set_app_status(
    pool: &PgPool,
    app_id: Uuid,
    status: SubmissionStatus,
) -> Result<(), sqlx::Error> {
    sqlx::query("UPDATE apps SET status = $1, updated_at = now() WHERE id = $2")
        .bind(status)
        .bind(app_id)
        .execute(pool)
        .await?;
    Ok(())
}

pub async fn set_download_url(
    pool: &PgPool,
    app_id: Uuid,
    url: &str,
    permissions: &serde_json::Value,
) -> Result<(), sqlx::Error> {
    sqlx::query(
        "UPDATE apps SET download_url = $1, permissions = $2, updated_at = now() WHERE id = $3",
    )
    .bind(url)
    .bind(permissions)
    .bind(app_id)
    .execute(pool)
    .await?;
    Ok(())
}

pub async fn log_audit(
    pool: &PgPool,
    app_id: Uuid,
    action: &str,
    details: Option<&serde_json::Value>,
) -> Result<(), sqlx::Error> {
    sqlx::query(
        "INSERT INTO submission_audit_log (app_id, action, details) VALUES ($1, $2, $3)",
    )
    .bind(app_id)
    .bind(action)
    .bind(details)
    .execute(pool)
    .await?;
    Ok(())
}

pub async fn set_upload_failed(pool: &PgPool, app_id: Uuid) -> Result<(), sqlx::Error> {
    sqlx::query(
        "UPDATE apps SET status = 'rejected', download_url = NULL, scan_report = jsonb_build_object('error', 'S3 upload failed after retries'), updated_at = now() WHERE id = $1",
    )
    .bind(app_id)
    .execute(pool)
    .await?;
    Ok(())
}

pub async fn increment_downloads(pool: &PgPool, app_id: Uuid) -> Result<(), sqlx::Error> {
    sqlx::query("UPDATE apps SET downloads = downloads + 1 WHERE id = $1")
        .bind(app_id)
        .execute(pool)
        .await?;
    Ok(())
}
