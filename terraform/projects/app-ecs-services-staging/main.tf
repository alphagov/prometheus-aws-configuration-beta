/**
* ## Project: app-ecs-services
*
* Create services and task definitions for the ECS cluster
*
*/

variable "aws_region" {
  type        = "string"
  description = "AWS region"
  default     = "eu-west-1"
}

variable "stack_name" {
  type        = "string"
  description = "Unique name for this collection of resources"
  default     = "staging"
}

data "pass_password" "cronitor_staging_url" {
  path = "cronitor/cronitor-staging-url"
}

# Resources
# --------------------------------------------------------------

## Providers

terraform {
  required_version = "= 0.11.13"

  backend "s3" {
    bucket = "prometheus-staging"
    key    = "app-ecs-services-modular.tfstate"
    region = "eu-west-1"
  }
}

provider "aws" {
  version = "~> 1.17"
  region  = "${var.aws_region}"
}

provider "template" {
  version = "~> 1.0.0"
}

provider "pass" {
  store_dir     = "~/.password-store/re-secrets/observe"
  refresh_store = true
}

variable "remote_state_bucket" {
  type        = "string"
  description = "S3 bucket we store our terraform state in"
  default     = "prometheus-staging"
}

module "app-ecs-services" {
  source = "../../modules/app-ecs-services"

  remote_state_bucket = "${var.remote_state_bucket}"
  stack_name          = "${var.stack_name}"
  observe_cronitor    = "${data.pass_password.cronitor_staging_url.password}"
}
