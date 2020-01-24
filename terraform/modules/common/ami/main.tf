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

data "aws_ami" "ubuntu_bionic" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
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

## Outputs

output "ecs_optimized_ami_id" {
  value = data.aws_ami.ecs_optimized.id
}

output "ubuntu_bionic_ami_id" {
  value = data.aws_ami.ubuntu_bionic.id
}

