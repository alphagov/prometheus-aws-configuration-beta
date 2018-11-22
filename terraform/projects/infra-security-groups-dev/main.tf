terraform {
  required_version = "= 0.11.10"

  backend "s3" {
    bucket = "re-observe-dev"
    key    = "infra-security-groups-modular.tfstate"
  }
}

provider "aws" {
  version = "~> 1.14.1"
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
  default     = "ecs-monitoring"
}

variable "stack_name" {
  type        = "string"
  description = "Unique name for this collection of resources"
  default     = "ecs-monitoring"
}

module "infra-security-groups" {
    source = "../../modules/infra-security-groups/"

    aws_region          = "${var.aws_region}"
    dev_environment     = true
    stack_name          = "module-refactor"
    remote_state_bucket = "observe-dev"
}
