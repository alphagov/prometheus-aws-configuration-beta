variable "environment" {}
variable "prometheus_config_bucket" {}
variable "alerts_path" {}
variable "private_zone_id" {}

variable "prom_private_ips" {
  type = list(string)
}

variable "extra_scrape_configs" {
  default     = []
  description = "List of scrape configs to append to the Prometheus config"
}
