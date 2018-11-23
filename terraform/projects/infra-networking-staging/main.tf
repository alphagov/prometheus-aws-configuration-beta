terraform {
  required_version = "= 0.11.10"

  backend "s3" {
    bucket = "prometheus-staging"
    key    = "infra-networking-staging.tfstate"
    region = "eu-west-1"
  }
}

provider "aws" {
  version = "~> 1.14.1"
  region  = "${var.aws_region}"
}

variable "aws_region" {
  type        = "string"
  description = "The AWS region to use."
  default     = "eu-west-1"
}

variable "stack_name" {
  type        = "string"
  description = "Unique name for this collection of resources"
  default     = "staging"
}

variable "prometheus_subdomain" {
  type        = "string"
  description = "Subdomain for prometheus"
  default     = "monitoring-staging"
}

module "infra-networking" {
  source = "../../modules/infra-networking"

  aws_region      = "eu-west-1"
  dev_environment = false
  stack_name      = "staging"
  prometheus_subdomain = "${var.prometheus_subdomain}"

}
