## Providers

terraform {
  required_version = "= 0.11.13"

  backend "s3" {
    bucket = "prometheus-staging"
    key    = "app-ecs-albs-modular.tfstate"
    region = "eu-west-1"
  }
}

provider "aws" {
  version = "~> 1.51.0"
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
  default     = "app-ecs-albs-staging"
}

data "terraform_remote_state" "infra_networking" {
  backend = "s3"

  config {
    bucket = "${var.remote_state_bucket}"
    key    = "infra-networking-modular.tfstate"
    region = "${var.aws_region}"
  }
}

module "app-ecs-albs" {
  source = "../../modules/app-ecs-albs/"

  aws_region          = "${var.aws_region}"
  stack_name          = "${var.stack_name}"
  remote_state_bucket = "${var.remote_state_bucket}"
  project             = "${var.project}"
  zone_id             = "${data.terraform_remote_state.infra_networking.public_zone_id}"
  subnets             = "${data.terraform_remote_state.infra_networking.public_subnets}"
}

output "prom_public_record_fqdns" {
  value       = "${module.app-ecs-albs.prom_public_record_fqdns}"
  description = "Prometheus public DNS FQDNs"
}

output "alerts_public_record_fqdns" {
  value       = "${module.app-ecs-albs.alerts_public_record_fqdns}"
  description = "Alertmanagers public DNS FQDNs"
}

output "prometheus_target_group_arns" {
  value = "${module.app-ecs-albs.prometheus_target_group_ids}"
}

output "alertmanager_ip_target_group_arns" {
  value = "${module.app-ecs-albs.alertmanager_ip_target_group_ids}"
}
