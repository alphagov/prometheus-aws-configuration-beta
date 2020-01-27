/**
* ## Module: app-ecs-services
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

locals {
  default_tags = {
    Terraform   = "true"
    Project     = "app-ecs-services"
    Source      = "github.com/alphagov/prometheus-aws-configuration-beta"
    Environment = var.environment
    Service     = "alertmanager"
  }
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

data "terraform_remote_state" "app_ecs_albs" {
  backend = "s3"

  config = {
    bucket = var.remote_state_bucket
    key    = "app-ecs-albs-modular.tfstate"
    region = var.aws_region
  }
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
