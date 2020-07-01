data "template_file" "prometheus_config_template" {
  template = file("${path.module}/prometheus.conf.tpl")

  vars = {
    environment = var.environment
  }
}

resource "aws_route53_record" "prom_ec2_a_record" {
  count = length(var.prom_private_ips)

  zone_id = var.private_zone_id
  name    = "prom-ec2-${count.index + 1}"
  type    = "A"
  ttl     = 300

  records = [var.prom_private_ips[count.index]]
}

resource "aws_s3_bucket_object" "prometheus_config" {
  bucket  = var.prometheus_config_bucket
  key     = "prometheus/prometheus.yml"
  content = data.template_file.prometheus_config_template.rendered
  etag    = md5(data.template_file.prometheus_config_template.rendered)
}

resource "aws_s3_bucket_object" "alerts-config" {
  bucket = var.prometheus_config_bucket
  key    = "prometheus/alerts/observe-alerts.yml"
  source = "${var.alerts_path}observe-alerts.yml"
  etag   = filemd5("${var.alerts_path}observe-alerts.yml")
}

resource "aws_s3_bucket_object" "alerts-data-gov-uk-config" {
  bucket = var.prometheus_config_bucket
  key    = "prometheus/alerts/data-gov-uk-alerts.yml"
  source = "${var.alerts_path}data-gov-uk-alerts.yml"
  etag   = filemd5("${var.alerts_path}data-gov-uk-alerts.yml")
}

resource "aws_s3_bucket_object" "alerts-govuk-coronavirus-services-config" {
  bucket = var.prometheus_config_bucket
  key    = "prometheus/alerts/govuk-coronavirus-services-alerts.yml"
  source = "${var.alerts_path}govuk-coronavirus-services-alerts.yml"
  etag   = filemd5("${var.alerts_path}govuk-coronavirus-services-alerts.yml")
}

resource "aws_s3_bucket_object" "alerts-registers-config" {
  bucket = var.prometheus_config_bucket
  key    = "prometheus/alerts/registers-alerts.yml"
  source = "${var.alerts_path}registers-alerts.yml"
  etag   = filemd5("${var.alerts_path}registers-alerts.yml")
}
