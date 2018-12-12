variable "alertmanager_dns_names" {
  type        = "list"
  default     = []
  description = "alertmanagers to send alerts to on local network (via http)"
}

variable "external_alertmanager_names" {
  type        = "list"
  default     = []
  description = "external alertmanagers to send alerts to (via https)"
}

variable "environment" {}
variable "prometheus_config_bucket" {}
variable "alerts_path" {}
variable "private_zone_id" {}
variable "private_subdomain" {}
variable "prometheus_sg_id" {}

variable "prom_private_ips" {
  type = "list"
}
