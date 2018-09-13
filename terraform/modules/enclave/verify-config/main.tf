data "aws_region" "current" {}

data "template_file" "prometheus_config_template" {
  template = "${file("${path.module}/prometheus.conf.tpl")}"

  vars {
    ec2_instance_profile = "${var.ec2_instance_profile_name}"
    aws_region           = "${data.aws_region.current.name}"
  }
}

resource "aws_s3_bucket_object" "prometheus_config" {
  bucket  = "${var.prometheus_config_bucket}"
  key     = "prometheus/prometheus.yml"
  content = "${data.template_file.prometheus_config_template.rendered}"
  etag    = "${md5(data.template_file.prometheus_config_template.rendered)}"
}
