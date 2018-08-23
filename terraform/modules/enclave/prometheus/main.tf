terraform {
  required_version = "= 0.11.7"
}

locals {
  enable_public_ip = "${var.enable_ssh == 1 ? true : false}"
}

resource "aws_key_pair" "ssh_key" {
  key_name   = "${var.environment}-prom-key"
  public_key = "${file("~/.ssh/id_rsa.pub")}"
}

resource "aws_instance" "prometheus" {
  count = "${length(var.subnet_ids)}"

  ami                  = "${var.ami_id}"
  instance_type        = "${var.instance_size}"
  user_data            = "${data.template_file.user_data_script.rendered}"
  iam_instance_profile = "${aws_iam_instance_profile.prometheus_instance_profile.id}"
  subnet_id            = "${element(var.subnet_ids, count.index)}"

  associate_public_ip_address = "${local.enable_public_ip}"

  key_name = "${aws_key_pair.ssh_key.key_name}"

  vpc_security_group_ids = ["${var.vpc_security_groups}"]

  tags {
    Name        = "${var.product}-${var.environment}-prometheus-${element(keys(var.availability_zones), count.index)}"
    Environment = "${var.environment}"
    Product     = "${var.product}"
    ManagedBy   = "terraform"
  }
}

resource "aws_volume_attachment" "attach-prometheus-disk" {
  count = "${length(var.subnet_ids)}"

  device_name = "${var.device_mount_path}"
  volume_id   = "${element(aws_ebs_volume.promethues-disk.*.id, count.index)}"
  instance_id = "${element(aws_instance.prometheus.*.id, count.index)}"

  # Required to work around a bug in terraform https://github.com/hashicorp/terraform/issues/2957
  # terraform tries to destroy the attachment before stoping/destorying the instance
  skip_destroy = true
}

resource "aws_ebs_volume" "promethues-disk" {
  count = "${length(var.subnet_ids)}"

  availability_zone = "${element(keys(var.availability_zones), count.index)}"
  size              = "20"

  tags {
    Name = "promethues-disk"
  }
}

data "template_file" "user_data_script" {
  template = "${file("${path.module}/cloud.conf")}"

  vars {
    config_bucket  = "${aws_s3_bucket.prometheus_config.id}"
    egress_proxy   = "${var.egress_proxy}"
    aws_ec2_ip     = "${var.ec2_endpoint_ips[0]}"
    region         = "${var.region}"
    verify_enclave = "${var.verify_enclave}"
  }
}
