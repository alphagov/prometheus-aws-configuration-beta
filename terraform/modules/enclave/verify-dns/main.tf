data "aws_route53_zone" "private_hosted_zone" {
  name   = "${var.hosted_zone_name}"
  vpc_id = "${var.target_vpc}"
}

resource "aws_route53_record" "prometheus" {
  count = "{var.prometheus_private_ip_count}"

  zone_id = "${data.aws_route53_zone.private_hosted_zone.zone_id}"
  name    = "${var.hostname_prefix}-${count.index + 1}.${data.aws_route53_zone.private_hosted_zone.name}"
  type    = "A"
  ttl     = "300"
  records = ["${element(var.prometheus_private_ips, count.index)}"]
}
