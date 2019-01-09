terraform {
  required_version = "= 0.11.10"

  backend "s3" {
    bucket = "prometheus-staging"
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
  default     = "prometheus-staging"
}

variable "stack_name" {
  type        = "string"
  description = "Unique name for this collection of resources"
  default     = "staging"
}

variable "project" {
  type        = "string"
  description = "Project name for tag"
  default     = "infra-security-groups-staging"
}

module "infra-security-groups" {
  source = "../../modules/infra-security-groups/"

  aws_region          = "${var.aws_region}"
  stack_name          = "${var.stack_name}"
  remote_state_bucket = "${var.remote_state_bucket}"
  project             = "${var.project}"
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
