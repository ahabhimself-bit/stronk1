use s3::creds::Credentials;
use s3::error::S3Error;
use s3::{Bucket, Region};

use crate::config::Config;

pub struct Storage {
    bucket: Box<Bucket>,
}

impl Storage {
    pub fn new(config: &Config) -> Result<Self, S3Error> {
        let region = Region::Custom {
            region: config.s3_region.clone(),
            endpoint: config.s3_endpoint.clone(),
        };

        let credentials = Credentials::new(
            Some(&config.s3_access_key),
            Some(&config.s3_secret_key),
            None,
            None,
            None,
        )?;

        let bucket = Bucket::new(&config.s3_bucket, region, credentials)?
            .with_path_style();

        Ok(Self { bucket })
    }

    pub async fn upload(&self, key: &str, data: &[u8], content_type: &str) -> Result<String, S3Error> {
        self.bucket.put_object_with_content_type(key, data, content_type).await?;
        Ok(format!("{}/{}", self.bucket.url(), key))
    }

    pub async fn download(&self, key: &str) -> Result<Vec<u8>, S3Error> {
        let response = self.bucket.get_object(key).await?;
        Ok(response.to_vec())
    }

    pub async fn delete(&self, key: &str) -> Result<(), S3Error> {
        self.bucket.delete_object(key).await?;
        Ok(())
    }
}
