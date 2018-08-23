data "aws_region" "current" {}

data "template_file" "prometheus_config_template" {
  template = "${file("${path.module}/prometheus.conf.tpl")}"

  vars {
    ec2_instance_profile = "${aws_iam_instance_profile.prometheus_instance_profile.name}"
    aws_region           = "${data.aws_region.current.name}"
  }
}

resource "aws_s3_bucket_object" "prometheus_config" {
  bucket  = "${aws_s3_bucket.prometheus_config.id}"
  key     = "prometheus/prometheus.yml"
  content = "${data.template_file.prometheus_config_template.rendered}"
  etag    = "${md5(data.template_file.prometheus_config_template.rendered)}"
}

resource "aws_s3_bucket" "prometheus_config" {
  bucket = "gdsobserve-verify-${var.environment}-prometheus-config-store"
  acl    = "private"

  versioning {
    enabled = true
  }
}
