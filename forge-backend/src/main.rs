mod config;
mod db;
mod models;
mod routes;
mod scanner;
mod storage;

use std::sync::Arc;

use axum::routing::{get, post};
use axum::Router;
use sqlx::PgPool;
use tower_http::cors::CorsLayer;
use tower_http::trace::TraceLayer;
use tracing::info;

use config::Config;
use storage::Storage;

#[derive(Clone)]
pub struct AppState {
    pub db: PgPool,
    pub storage: Arc<Storage>,
    pub config: Arc<Config>,
}

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "forge_backend=info,tower_http=info".into()),
        )
        .init();

    let config = Config::from_env();
    let listen_addr = config.listen_addr.clone();

    let pool = db::connect(&config.database_url)
        .await
        .expect("Failed to connect to database");

    db::run_migrations(&pool)
        .await
        .expect("Failed to run migrations");

    let storage = Storage::new(&config).expect("Failed to initialize S3 storage");

    let state = AppState {
        db: pool,
        storage: Arc::new(storage),
        config: Arc::new(config),
    };

    let app = Router::new()
        .route("/health", get(routes::health::check))
        .route("/api/v1/apps", get(routes::apps::list))
        .route("/api/v1/apps/{id}", get(routes::apps::detail))
        .route("/api/v1/apps/{id}/download", post(routes::apps::download))
        .route("/api/v1/submissions", post(routes::submissions::submit))
        .route(
            "/api/v1/submissions/{id}/status",
            get(routes::submissions::status),
        )
        .layer(TraceLayer::new_for_http())
        .layer(CorsLayer::permissive())
        .with_state(state);

    let listener = tokio::net::TcpListener::bind(&listen_addr)
        .await
        .expect("Failed to bind");

    info!("The Forge backend listening on {}", listen_addr);
    axum::serve(listener, app).await.expect("Server error");
}
