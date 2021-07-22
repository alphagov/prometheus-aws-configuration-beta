/**
* ## Module: alertmanager
*
* Create services and task definitions for the ECS cluster
*
*/

variable "aws_region" {
  type        = string
  description = "AWS region"
  default     = "eu-west-1"
}

variable "remote_state_bucket" {
  type        = string
  description = "S3 bucket we store our terraform state in"
  default     = "ecs-monitoring"
}

variable "environment" {
  type        = string
  description = "Unique name for this collection of resources"
  default     = "ecs-monitoring"
}

variable "observe_cronitor" {
  type        = string
  description = "URL to send Observe heartbeats to"
  default     = ""
}

variable "allowed_cidrs" {
  type        = list(string)
  description = "List of CIDRs which are able to access alertmanager, default are GDS ips and concourse egress"

  default = [
    "213.86.153.211/32",
    "213.86.153.212/32",
    "213.86.153.213/32",
    "213.86.153.214/32",
    "213.86.153.231/32",
    "213.86.153.235/32",
    "213.86.153.236/32",
    "213.86.153.237/32",
    "85.133.67.244/32",
    "35.177.37.128/32",
    "35.176.252.164/32",
    "51.149.9.112/29", # CO
    "51.149.9.240/29", # CO
  ]
}

locals {
  default_tags = {
    Terraform   = "true"
    Project     = "alertmanager"
    Source      = "github.com/alphagov/prometheus-aws-configuration-beta"
    Environment = var.environment
    Service     = "alertmanager"
  }
  vpc_id             = data.terraform_remote_state.infra_networking.outputs.vpc_id
  zone_id            = data.terraform_remote_state.infra_networking.outputs.public_zone_id
  availability_zones = data.aws_subnet.public_subnets.*.availability_zone
}

# Resources
# --------------------------------------------------------------

## Data sources
data "terraform_remote_state" "infra_networking" {
  backend = "s3"

  config = {
    bucket = var.remote_state_bucket
    key    = "infra-networking-modular.tfstate"
    region = var.aws_region
  }
}

data "terraform_remote_state" "infra_security_groups" {
  backend = "s3"

  config = {
    bucket = var.remote_state_bucket
    key    = "infra-security-groups-modular.tfstate"
    region = var.aws_region
  }
}

data "aws_availability_zones" "available" {}

data "aws_subnet" "public_subnets" {
  count = length(data.terraform_remote_state.infra_networking.outputs.public_subnets)
  id    = data.terraform_remote_state.infra_networking.outputs.public_subnets[count.index]
}

data "aws_subnet" "private_subnets" {
  count = length(data.terraform_remote_state.infra_networking.outputs.private_subnets)
  id    = data.terraform_remote_state.infra_networking.outputs.private_subnets[count.index]
}

## Resources

resource "aws_cloudwatch_log_group" "task_logs" {
  name              = var.environment
  retention_in_days = 7

  tags = merge(local.default_tags, {
    Name = "${var.environment}-alertmanager-task-logs"
  })
}

## Outputs

output "ecs_clusters_services" {
  description = "Names of ECS services created, listed by ECS cluster name"
  value = transpose({
    for _, service in aws_ecs_service.alertmanager_alb:
    service.name => [ service.cluster ]
  })
}
