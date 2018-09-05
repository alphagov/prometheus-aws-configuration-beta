output "availability_zones" {
  value = "${var.availability_zones}"
}

output "subnet_ids" {
  value = "${aws_subnet.observe.*.id}"
}

output "security_groups" {
  value = [
    "${aws_security_group.prometheus_instance.id}",
  ]
}

output "endpoint_network_interface_ip" {
  value = "${flatten(data.aws_network_interface.ec2_endpoint_network_interfaces.*.private_ips)}"
}

output "routing_table" {
  value = "${aws_route_table.observe.id}"
}
