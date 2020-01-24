variable "environment" {}
variable "prometheus_config_bucket" {}
variable "alerts_path" {}
variable "private_zone_id" {}
variable "private_subdomain" {}

variable "prom_private_ips" {
  type = list(string)
}

