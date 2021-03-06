locals {
  filebeat_count = var.logstash_host != "" ? 1 : 0
  default_tags = {
    ManagedBy   = "terraform"
    Source      = "github.com/alphagov/prometheus-aws-configuration-beta"
    Environment = var.environment
    Service     = "observe-prometheus"
  }
}

resource "aws_key_pair" "ssh_key" {
  count      = var.enable_ssh == true ? 1 : 0
  key_name   = "${var.environment}-prom-key"
  public_key = file("~/.ssh/id_rsa.pub")
}

resource "aws_instance" "prometheus" {
  count = length(keys(var.availability_zones))

  ami                  = var.ami_id
  instance_type        = var.instance_size
  user_data            = data.template_file.user_data_script[count.index].rendered
  iam_instance_profile = aws_iam_instance_profile.prometheus_instance_profile.id
  subnet_id            = var.subnet_ids[count.index]

  associate_public_ip_address = var.enable_ssh

  key_name = var.enable_ssh ? format("%s-prom-key", var.environment) : ""

  vpc_security_group_ids = var.vpc_security_groups

  tags = merge(local.default_tags, {
    Name = "paas-${var.environment}-prometheus-${element(keys(var.availability_zones), count.index)}"
  })
}

resource "aws_volume_attachment" "attach-prometheus-disk" {
  count = length(keys(var.availability_zones))

  device_name = var.device_mount_path
  volume_id   = aws_ebs_volume.prometheus-disk[count.index].id
  instance_id = aws_instance.prometheus[count.index].id

  # Required to work around a bug in terraform https://github.com/hashicorp/terraform/issues/2957
  # terraform tries to destroy the attachment before stoping/destorying the instance
  skip_destroy = true
}

resource "aws_ebs_volume" "prometheus-disk" {
  count = length(keys(var.availability_zones))

  availability_zone = element(keys(var.availability_zones), count.index)
  size              = var.data_volume_size

  tags = merge(local.default_tags, {
    Name = "prometheus-disk"
  })
}

data "template_file" "user_data_script" {
  count = length(keys(var.availability_zones))

  template = file("${path.module}/cloud.conf")

  vars = {
    config_bucket          = aws_s3_bucket.prometheus_config.id
    region                 = var.region
    ireland_targets_bucket = aws_s3_bucket.prometheus_targets.id
    london_targets_bucket  = aws_s3_bucket.prometheus_london_targets.id
    alerts_bucket          = aws_s3_bucket.prometheus_config.id
    prom_external_url      = "https://${var.prometheus_public_fqdns[count.index]}"
    logstash_host          = var.logstash_host
    prometheus_htpasswd    = var.prometheus_htpasswd
    allowed_cidrs          = join("\n        ", formatlist("allow %s;", var.allowed_cidrs))
    data_volume_size       = var.data_volume_size
  }
}

resource "aws_s3_bucket" "prometheus_config" {
  bucket        = var.config_bucket
  acl           = "private"
  force_destroy = true

  versioning {
    enabled = true
  }

  tags = merge(local.default_tags, {
    Name = "${var.environment}-prometheus-config"
  })
}

data "template_file" "filebeat_conf" {
  count    = local.filebeat_count
  template = file("${path.module}/filebeat.yml.tpl")

  vars = {
    logstash_host = var.logstash_host
    environment   = var.environment
  }
}

resource "aws_s3_bucket_object" "filebeat" {
  count   = local.filebeat_count
  bucket  = var.config_bucket
  key     = "filebeat/filebeat.yml"
  content = data.template_file.filebeat_conf[0].rendered
}

resource "aws_lb_target_group_attachment" "prom_target_group_attachment" {
  count            = length(var.prometheus_target_group_arns)
  target_group_arn = var.prometheus_target_group_arns[count.index]
  target_id        = aws_instance.prometheus[count.index].id
  port             = 80
}

