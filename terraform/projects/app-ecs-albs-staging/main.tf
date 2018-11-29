## Providers

terraform {
  required_version = "= 0.11.10"

  backend "s3" {
    bucket = "prometheus-staging"
    key    = "app-ecs-albs-modular.tfstate"
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

module "app-ecs-albs" {
  source = "../../modules/app-ecs-albs/"

  aws_region          = "${var.aws_region}"
  stack_name          = "${var.stack_name}"
  remote_state_bucket = "${var.remote_state_bucket}"
  project             = "${var.project}"
}
