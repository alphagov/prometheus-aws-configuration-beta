terraform {
  required_version = "= 0.11.13"
}

locals {
  enable_public_ip = "${var.enable_ssh == 1 ? true : false}"
  filebeat_count   = "${var.logstash_host != "" ? 1 : 0}"
}

resource "aws_key_pair" "ssh_key" {
  count      = "${var.enable_ssh}"
  key_name   = "${var.environment}-prom-key"
  public_key = "${file("~/.ssh/id_rsa.pub")}"
}

resource "aws_instance" "prometheus" {
  count = "${length(keys(var.availability_zones))}"

  ami                  = "${var.ami_id}"
  instance_type        = "${var.instance_size}"
  user_data            = "${element(data.template_file.user_data_script.*.rendered, count.index)}"
  iam_instance_profile = "${aws_iam_instance_profile.prometheus_instance_profile.id}"
  subnet_id            = "${element(var.subnet_ids, count.index)}"

  associate_public_ip_address = "${local.enable_public_ip}"

  key_name = "${var.enable_ssh ? format("%s-prom-key", var.environment) : ""}"

  vpc_security_group_ids = ["${var.vpc_security_groups}"]

  tags {
    Name        = "${var.product}-${var.environment}-prometheus-${element(keys(var.availability_zones), count.index)}"
    Environment = "${var.environment}"
    Product     = "${var.product}"
    ManagedBy   = "terraform"
    Job         = "prometheus"
  }
}

resource "aws_volume_attachment" "attach-prometheus-disk" {
  count = "${length(keys(var.availability_zones))}"

  device_name = "${var.device_mount_path}"
  volume_id   = "${element(aws_ebs_volume.prometheus-disk.*.id, count.index)}"
  instance_id = "${element(aws_instance.prometheus.*.id, count.index)}"

  # Required to work around a bug in terraform https://github.com/hashicorp/terraform/issues/2957
  # terraform tries to destroy the attachment before stoping/destorying the instance
  skip_destroy = true
}

resource "aws_ebs_volume" "prometheus-disk" {
  count = "${length(keys(var.availability_zones))}"

  availability_zone = "${element(keys(var.availability_zones), count.index)}"
  size              = "21"

  tags {
    Name = "prometheus-disk"
  }
}

data "template_file" "user_data_script" {
  count = "${length(keys(var.availability_zones))}"

  template = "${file("${path.module}/cloud.conf")}"

  vars {
    config_bucket       = "${aws_s3_bucket.prometheus_config.id}"
    region              = "${var.region}"
    targets_bucket      = "${var.targets_bucket}"
    alerts_bucket       = "${aws_s3_bucket.prometheus_config.id}"
    prom_external_url   = "https://${var.prometheus_public_fqdns[count.index]}"
    logstash_host       = "${var.logstash_host}"
    prometheus_htpasswd = "${var.prometheus_htpasswd}"
    allowed_cidrs       = "${join("\n        ",formatlist("allow %s;", var.allowed_cidrs))}"
  }
}

resource "aws_s3_bucket" "prometheus_config" {
  bucket        = "${var.config_bucket}"
  acl           = "private"
  force_destroy = true

  versioning {
    enabled = true
  }
}

data "template_file" "filebeat_conf" {
  count    = "${local.filebeat_count}"
  template = "${file("${path.module}/filebeat.yml.tpl")}"

  vars {
    logstash_host = "${var.logstash_host}"
    environment   = "${var.environment}"
  }
}

resource "aws_s3_bucket_object" "filebeat" {
  count   = "${local.filebeat_count}"
  bucket  = "${var.config_bucket}"
  key     = "filebeat/filebeat.yml"
  content = "${data.template_file.filebeat_conf.rendered}"
}

resource "aws_lb_target_group_attachment" "prom_target_group_attachment" {
  count            = "${length(var.prometheus_target_group_arns)}"
  target_group_arn = "${element(var.prometheus_target_group_arns, count.index)}"
  target_id        = "${element(aws_instance.prometheus.*.id, count.index)}"
  port             = 80
}
