/**
* ## Project: alertmanager
*
* Create services and task definitions for the ECS cluster
*
*/

variable "aws_region" {
  type        = string
  description = "AWS region"
  default     = "eu-west-1"
}

data "pass_password" "cronitor_staging_url" {
  path = "cronitor/cronitor-staging-url"
}

# Resources
# --------------------------------------------------------------

## Providers

terraform {
  required_version = "~> 0.13.3"

  backend "s3" {
    bucket = "prometheus-staging"
    key    = "app-ecs-services-modular.tfstate"
    region = "eu-west-1"
  }
}

provider "aws" {
  version = "~> 2.45"
  region  = var.aws_region
}

provider "template" {
  version = "~> 2.1"
}

provider "pass" {
  store_dir     = "~/.password-store/re-secrets/observe"
  refresh_store = true
}

variable "remote_state_bucket" {
  type        = string
  description = "S3 bucket we store our terraform state in"
  default     = "prometheus-staging"
}

module "alertmanager" {
  source = "../../modules/alertmanager"

  remote_state_bucket = var.remote_state_bucket
  environment         = "staging"
  observe_cronitor    = data.pass_password.cronitor_staging_url.password
}

