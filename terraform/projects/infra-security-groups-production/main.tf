terraform {
  required_version = "= 0.11.13"

  backend "s3" {
    bucket = "prometheus-production"
    key    = "infra-security-groups-modular.tfstate"
    region = "eu-west-1"
  }
}

provider "aws" {
  version = "~> 1.14.1"
  region  = "${var.aws_region}"
}

variable "aws_region" {
  type        = "string"
  description = "AWS region"
  default     = "eu-west-1"
}

variable "remote_state_bucket" {
  type        = "string"
  description = "S3 bucket we store our terraform state in"
  default     = "prometheus-production"
}

variable "stack_name" {
  type        = "string"
  description = "Unique name for this collection of resources"
  default     = "production"
}

variable "project" {
  type        = "string"
  description = "Project name for tag"
  default     = "infra-security-groups-production"
}

module "infra-security-groups" {
  source = "../../modules/infra-security-groups/"

  aws_region          = "${var.aws_region}"
  stack_name          = "production"
  remote_state_bucket = "prometheus-production"
  project             = "${var.project}"

  allowed_cidrs = [
    # Office IPs
    "213.86.153.212/32",

    "213.86.153.213/32",
    "213.86.153.214/32",
    "213.86.153.235/32",
    "213.86.153.236/32",
    "213.86.153.237/32",
    "85.133.67.244/32",

    # verify prod
    "35.178.25.41/32",

    "35.177.2.97/32",
    "35.176.169.64/32",

    # verify integration
    "3.8.68.252/32",

    "3.8.41.125/32",
    "3.8.225.106/32",

    # verify staging
    "35.177.140.5/32",

    "18.130.58.164/32",
    "35.176.196.169/32",

    # verify joint
    "35.176.160.191/32",

    "35.177.182.230/32",
    "35.177.122.134/32",

    # concourse
    "35.177.37.128/32",

    "35.176.252.164/32",

    # verify gsp
    "35.176.76.151/32",

    "18.130.183.50/32",
    "18.130.4.61/32",
  ]
}

## Outputs

output "prometheus_ec2_sg_id" {
  value       = "${module.infra-security-groups.prometheus_ec2_sg_id}"
  description = "security group prometheus_ec2 ID"
}

output "prometheus_alb_sg_id" {
  value       = "${module.infra-security-groups.prometheus_alb_sg_id}"
  description = "security group prometheus_alb ID"
}

output "alertmanager_ec2_sg_id" {
  value       = "${module.infra-security-groups.alertmanager_ec2_sg_id}"
  description = "security group alertmanager_ec2 ID"
}

output "alertmanager_alb_sg_id" {
  value       = "${module.infra-security-groups.alertmanager_alb_sg_id}"
  description = "security group alertmanager_alb ID"
}
