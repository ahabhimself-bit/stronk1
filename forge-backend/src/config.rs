use std::env;

pub struct Config {
    pub database_url: String,
    pub listen_addr: String,
    pub s3_endpoint: String,
    pub s3_bucket: String,
    pub s3_region: String,
    pub s3_access_key: String,
    pub s3_secret_key: String,
    pub clamav_addr: String,
    pub allowed_origins: Vec<String>,
}

impl Config {
    pub fn from_env() -> Self {
        Self {
            database_url: env::var("DATABASE_URL")
                .unwrap_or_else(|_| "postgres://forge:forge@localhost/forge".to_string()),
            listen_addr: env::var("LISTEN_ADDR").unwrap_or_else(|_| "0.0.0.0:3000".to_string()),
            s3_endpoint: env::var("S3_ENDPOINT")
                .unwrap_or_else(|_| "http://localhost:9000".to_string()),
            s3_bucket: env::var("S3_BUCKET").unwrap_or_else(|_| "forge-packages".to_string()),
            s3_region: env::var("S3_REGION").unwrap_or_else(|_| "us-east-1".to_string()),
            s3_access_key: env::var("S3_ACCESS_KEY")
                .expect("S3_ACCESS_KEY must be set"),
            s3_secret_key: env::var("S3_SECRET_KEY")
                .expect("S3_SECRET_KEY must be set"),
            clamav_addr: env::var("CLAMAV_ADDR")
                .unwrap_or_else(|_| "localhost:3310".to_string()),
            allowed_origins: env::var("ALLOWED_ORIGINS")
                .unwrap_or_else(|_| "http://localhost:3000".to_string())
                .split(',')
                .map(|s| s.trim().to_string())
                .collect(),
        }
    }
}
