output "prometheus_dns" {
  value = "${module.prometheus.prometheus_public_dns}"
}

output "prometheus_id" {
  value = "${element(module.prometheus.prometheus_instance_id, 0)}"
}

output "prom_s3_config_bucket" {
  value = "${module.prometheus.s3_config_bucket}"
}

output "environment" {
  value = "${local.environment}"
}
