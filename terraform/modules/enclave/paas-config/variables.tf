variable "alertmanager_dns_names" {}
variable "prometheus_config_bucket" {}
variable "environment" {}
variable "alerts_path" {}
variable "private_zone_id" {}
variable "private_subdomain" {}
variable "paas_proxy_sg_id" {}
variable "prometheus_sg_id" {}

variable "prom_private_ips" {
  type = "list"
}

variable "prometheus_dns_names" {
  type = "list"
}
