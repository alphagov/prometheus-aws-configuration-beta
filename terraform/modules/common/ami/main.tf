## Variables

locals {
  canonical_account_id = "099720109477"
}

## Data sources

data "aws_ami" "ecs_optimized" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn-ami-*-amazon-ecs-optimized"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  owners = ["amazon"]
}

data "aws_ami" "ubuntu_focal" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = [local.canonical_account_id]
}

# 2020-07-01 focal arm64 has a broken snapd installation, so we can't
# get ssm agent and other things
# https://bugs.launchpad.net/ubuntu/+source/snapd/+bug/1881350
data "aws_ami" "ubuntu_focal_arm" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-arm64-server-*"]
  }

  filter {
    name   = "architecture"
    values = ["arm64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = [local.canonical_account_id]
}

data "aws_ami" "ubuntu_groovy_daily_arm" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images-testing/hvm-ssd/ubuntu-groovy-daily-arm64-server-*"]
  }

  filter {
    name   = "architecture"
    values = ["arm64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = [local.canonical_account_id]
}

## Outputs

output "ecs_optimized_ami_id" {
  value = data.aws_ami.ecs_optimized.id
}

output "ubuntu_focal_ami_id" {
  value = data.aws_ami.ubuntu_focal.id
}

output "ubuntu_focal_arm_ami_id" {
  value = data.aws_ami.ubuntu_focal_arm.id
}

output "ubuntu_groovy_arm_ami_id" {
  value = data.aws_ami.ubuntu_groovy_daily_arm.id
}

