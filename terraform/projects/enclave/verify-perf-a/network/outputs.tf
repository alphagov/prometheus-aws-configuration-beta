output "availability_zones" {
  value = "${module.network.availability_zones}"
}

output "subnet_ids" {
  value = "${module.network.subnet_ids}"
}

output "security_groups" {
  value = "${module.network.security_groups}"
}

output "endpoint_network_interface_ip" {
  value = "${module.network.endpoint_network_interface_ip}"
}
