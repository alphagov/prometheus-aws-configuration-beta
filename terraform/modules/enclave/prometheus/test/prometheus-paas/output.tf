output "prometheus_dns" {
  value = "${module.prometheus.prometheus_public_dns}"
}

output "prometheus_id" {
  value = "${element(module.prometheus.prometheus_instance_id, 0)}"
}
