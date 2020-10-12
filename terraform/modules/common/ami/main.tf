## Variables

locals {
  canonical_account_id = "099720109477"
}

## Data sources

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

## Outputs

output "ubuntu_focal_ami_id" {
  value = data.aws_ami.ubuntu_focal.id
}

