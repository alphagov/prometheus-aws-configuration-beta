output "prometheus_config_etag" {
  value = aws_s3_bucket_object.prometheus_config.etag
}
