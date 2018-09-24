data "template_file" "prometheus_config_template" {
  template = "${file("${path.module}/prometheus.conf.tpl")}"

  vars {
    prometheus_dns_names   = "${var.prometheus_dns_names}"
    environment            = "${var.environment}"
    alertmanager_dns_names = "${var.alertmanager_dns_names}"
    prometheus_dns_nodes   = "${var.prometheus_dns_nodes}"
  }
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
