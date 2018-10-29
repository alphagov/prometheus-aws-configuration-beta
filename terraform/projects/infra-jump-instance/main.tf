## Variables

variable "additional_tags" {
  type        = "map"
  description = "Stack specific tags to apply"
  default     = {}
}

variable "aws_region" {
  type        = "string"
  description = "AWS region"
  default     = "eu-west-1"
}

variable "remote_state_bucket" {
  type        = "string"
  description = "S3 bucket we store our terraform state in"
  default     = "ecs-monitoring"
}

variable "stack_name" {
  type        = "string"
  description = "Unique name for this collection of resources"
  default     = "ecs-monitoring"
}

variable "jumpbox_cidrs" {
  type        = "list"
  description = "List of CIDRs which are able to access the jumpbox"
  default     = ["0.0.0.0/0"]
}

## Providers

terraform {
  required_version = "= 0.11.10"

  backend "s3" {
    key = "infra-jump-instance.tfstate"
  }
}

provider "aws" {
  version = "~> 1.14.1"
  region  = "${var.aws_region}"
}

provider "template" {
  version = "~> 1.0.0"
}

## Data sources

data "terraform_remote_state" "infra_networking" {
  backend = "s3"

  config {
    bucket = "${var.remote_state_bucket}"
    key    = "infra-networking.tfstate"
    region = "${var.aws_region}"
  }
}

data "terraform_remote_state" "infra_security_groups" {
  backend = "s3"

  config {
    bucket = "${var.remote_state_bucket}"
    key    = "infra-security-groups.tfstate"
    region = "${var.aws_region}"
  }
}

## Resources

module "jumpbox" {
  source          = "../../modules/jumpbox"
  aws_region      = "${var.aws_region}"
  subnet_id       = "${element(data.terraform_remote_state.infra_networking.public_subnets, 0)}"
  stack_name      = "${var.stack_name}"
  vpc_id          = "${data.terraform_remote_state.infra_networking.vpc_id}"
  security_groups = ["${data.terraform_remote_state.infra_security_groups.monitoring_external_sg_id}"]
  allowed_cidrs   = "${var.jumpbox_cidrs}"
}

resource "aws_route53_record" "jump_alias" {
  zone_id = "${data.terraform_remote_state.infra_networking.public_zone_id}"
  name    = "jump"
  type    = "A"
  ttl     = 60

  records = ["${module.jumpbox.jumpbox_ip}"]
}

## Outputs

output "jumpbox_ip" {
  value = "${module.jumpbox.jumpbox_ip}"
}

output "jump_box_key_name" {
  value = "${module.jumpbox.key_name}"
}
