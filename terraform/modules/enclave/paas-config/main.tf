data "template_file" "prometheus_config_template" {
  template = "${file("${path.module}/prometheus.conf.tpl")}"

  vars {
    prometheus_dns_names = "${var.prometheus_dns_names}"
  }
}

resource "aws_s3_bucket_object" "prometheus_config" {
  bucket  = "${var.prometheus_config_bucket}"
  key     = "prometheus/prometheus.yml"
  content = "${data.template_file.prometheus_config_template.rendered}"
  etag    = "${md5(data.template_file.prometheus_config_template.rendered)}"
}
