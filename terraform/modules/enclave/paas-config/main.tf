resource "aws_security_group_rule" "allow_ec2_prometheus_access_paas_proxy" {
  type                     = "ingress"
  to_port                  = 8080
  from_port                = 8080
  protocol                 = "tcp"
  security_group_id        = "${var.paas_proxy_sg_id}"
  source_security_group_id = "${var.prometheus_sg_id}"
}

data "template_file" "prometheus_config_template" {
  template = "${file("${path.module}/prometheus.conf.tpl")}"

  vars {
    environment = "${var.environment}"

    alertmanager_dns_names    = "${var.alertmanager_dns_names}"
    prometheus_addresses      = "${join("\",\"", formatlist("%s:9090", aws_route53_record.prom_a_record.*.fqdn))}"
    prometheus_node_addresses = "${join("\",\"", formatlist("%s:9100", aws_route53_record.prom_a_record.*.fqdn))}"
  }
}

resource "aws_route53_record" "prom_ec2_a_record" {
  count = 3

  zone_id = "${var.private_zone_id}"
  name    = "prom-ec2-${count.index + 1}"
  type    = "A"
  ttl     = 300

  records = ["${element(var.prom_private_ips, count.index)}"]
}

resource "aws_route53_record" "prom_a_record" {
  count = 3

  zone_id = "${var.private_zone_id}"
  name    = "prom-${count.index + 1}"
  type    = "A"
  ttl     = 300

  records = ["${element(var.prom_private_ips, count.index)}"]
}

resource "aws_s3_bucket_object" "prometheus_config" {
  bucket  = "${var.prometheus_config_bucket}"
  key     = "prometheus/prometheus.yml"
  content = "${data.template_file.prometheus_config_template.rendered}"
  etag    = "${md5(data.template_file.prometheus_config_template.rendered)}"
}

resource "aws_s3_bucket_object" "alerts-config" {
  bucket = "${var.prometheus_config_bucket}"
  key    = "prometheus/alerts/observe-alerts.yml"
  source = "${var.alerts_path}observe-alerts.yml"
  etag   = "${md5(file("${var.alerts_path}observe-alerts.yml"))}"
}

resource "aws_s3_bucket_object" "alerts-data-gov-uk-config" {
  bucket = "${var.prometheus_config_bucket}"
  key    = "prometheus/alerts/data-gov-uk-alerts.yml"
  source = "${var.alerts_path}data-gov-uk-alerts.yml"
  etag   = "${md5(file("${var.alerts_path}data-gov-uk-alerts.yml"))}"
}

resource "aws_s3_bucket_object" "alerts-registers-config" {
  bucket = "${var.prometheus_config_bucket}"
  key    = "prometheus/alerts/registers-alerts.yml"
  source = "${var.alerts_path}registers-alerts.yml"
  etag   = "${md5(file("${var.alerts_path}registers-alerts.yml"))}"
}
