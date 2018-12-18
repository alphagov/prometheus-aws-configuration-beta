terraform {
  required_version = "= 0.11.10"

  backend "s3" {
    bucket = "re-prom-dev-tfstate"
    key    = "infra-security-groups-modular.tfstate"
    region = "eu-west-1"
  }
}

provider "aws" {
  version             = "~> 1.14.1"
  allowed_account_ids = ["931679966755"]
  region              = "${var.aws_region}"
}

variable "aws_region" {
  type        = "string"
  description = "AWS region"
  default     = "eu-west-1"
}

variable "remote_state_bucket" {
  type        = "string"
  description = "S3 bucket we store our terraform state in"
  default     = "re-observe-dev"
}

variable "stack_name" {
  type        = "string"
  description = "Unique name for this collection of resources"
  default     = "dev"
}

variable "project" {
  type        = "string"
  description = "Project name for tag"
  default     = "infra-security-groups-dev"
}

module "infra-security-groups" {
  source = "../../modules/infra-security-groups/"

  aws_region          = "${var.aws_region}"
  stack_name          = "module-refactor"
  remote_state_bucket = "${var.remote_state_bucket}"
  project             = "${var.project}"
}

## Outputs

output "monitoring_external_sg_id" {
  value       = "${module.infra-security-groups.monitoring_external_sg_id}"
  description = "monitoring_external_sg ID"
}

output "alertmanager_external_sg_id" {
  value       = "${module.infra-security-groups.alertmanager_external_sg_id}"
  description = "alertmanager_external_sg ID"
}

output "monitoring_internal_sg_id" {
  value       = "${module.infra-security-groups.monitoring_internal_sg_id}"
  description = "monitoring_internal_sg ID"
}
