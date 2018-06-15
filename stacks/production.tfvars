remote_state_bucket = "prometheus-production"
stack_name = "production"
dev_environment = "false"
prometheus_subdomain = "monitoring"
targets_s3_bucket = "gds-prometheus-targets"
additional_tags = {
  "Environment" = "production"
}
