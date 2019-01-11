output "public_ip_address" {
  value = "${aws_instance.prometheus.*.public_ip}"
}

output "private_ip_addresses" {
  value = "${aws_instance.prometheus.*.private_ip}"
}

output "prometheus_instance_id" {
  value = "${aws_instance.prometheus.*.id}"
}

output "prometheus_private_dns" {
  value = "${aws_instance.prometheus.*.private_dns}"
}

output "prometheus_public_dns" {
  value = "${aws_instance.prometheus.*.public_dns}"
}

output "s3_config_bucket" {
  value = "${aws_s3_bucket.prometheus_config.id}"
}

output "ec2_instance_profile_name" {
  value = "${aws_iam_instance_profile.prometheus_instance_profile.name}"
}
