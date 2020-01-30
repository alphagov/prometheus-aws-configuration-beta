terraform {
  required_version = "~> 0.12.19"

  backend "s3" {
    bucket = "prometheus-staging"
    key    = "infra-security-groups-modular.tfstate"
    region = "eu-west-1"
  }
}

provider "aws" {
  version = "~> 2.45"
  region  = var.aws_region
}

variable "aws_region" {
  type        = string
  description = "AWS region"
  default     = "eu-west-1"
}

module "infra-security-groups" {
  source = "../../modules/infra-security-groups/"

  aws_region          = var.aws_region
  environment         = "staging"
  remote_state_bucket = "prometheus-staging"
}

## Outputs

output "prometheus_ec2_sg_id" {
  value       = module.infra-security-groups.prometheus_ec2_sg_id
  description = "security group prometheus_ec2 ID"
}

output "prometheus_alb_sg_id" {
  value       = module.infra-security-groups.prometheus_alb_sg_id
  description = "security group prometheus_alb ID"
}
