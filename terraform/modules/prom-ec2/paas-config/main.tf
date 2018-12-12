data "template_file" "prometheus_config_template" {
  template = "${file("${path.module}/prometheus.conf.tpl")}"

  vars {
    alertmanager_dns_names = "${join(",", formatlist("\"%s\"", var.alertmanager_dns_names))}"
    external_alertmanagers = "${join(",", formatlist("\"%s\"", var.external_alertmanager_names))}"

    environment = "${var.environment}"
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
