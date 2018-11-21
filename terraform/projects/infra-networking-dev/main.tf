terraform {
  required_version = "= 0.11.10"

  backend "s3" {
    bucket = "re-observe-dev"
    key    = "infra-networking-dev.tfstate"
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
  default     = "ecs-monitoring"
}

module "infra-networking" {
  source = "../../modules/infra-networking"

  aws_region      = "eu-west-1"
  dev_environment = true
  stack_name      = "module-refactor"
}
