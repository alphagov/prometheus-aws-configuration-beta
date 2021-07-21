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

data "pass_password" "cronitor_production_url" {
  path = "cronitor/cronitor-production-url"
}

# Resources
# --------------------------------------------------------------

## Providers

terraform {
  required_version = "~> 0.13.3"

  backend "s3" {
    bucket = "prometheus-production"
    key    = "app-ecs-services-modular.tfstate"
    region = "eu-west-1"
  }
}

provider "aws" {
  region = var.aws_region
}

provider "pass" {
  store_dir     = "~/.password-store/re-secrets/observe"
  refresh_store = true
}

variable "remote_state_bucket" {
  type        = string
  description = "S3 bucket we store our terraform state in"
  default     = "prometheus-production"
}

module "alertmanager" {
  source = "../../modules/alertmanager"

  remote_state_bucket = var.remote_state_bucket
  environment         = "production"
  observe_cronitor    = data.pass_password.cronitor_production_url.password
  allowed_cidrs = [
    # Office IPs
    "213.86.153.211/32",
    "213.86.153.212/32",
    "213.86.153.213/32",
    "213.86.153.214/32",
    "213.86.153.231/32",
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

    # concourse
    "35.177.37.128/32",

    "35.176.252.164/32",

    "51.149.9.112/29", # CO
    "51.149.9.240/29", # CO
  ]
}

