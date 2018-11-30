terraform {
  required_version = "= 0.11.10"

  backend "s3" {
    bucket = "re-observe-dev"
    key    = "app-ecs-instances-modular.tfstate"
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

variable "stack_name" {
  type        = "string"
  description = "Unique name for this collection of resources"
  default     = "dev"
}

variable "project" {
  type        = "string"
  description = "Project name for tag"
  default     = "app-ecs-instances-dev"
}

variable "remote_state_bucket" {
  type        = "string"
  description = "S3 bucket we store our terraform state in"
  default     = "re-observe-dev"
}

module "app-ecs-instances" {
  source = "../../modules/app-ecs-instances"

  dev_environment     = true
  stack_name          = "${var.stack_name}"
  project             = "${var.project}"
  remote_state_bucket = "${var.remote_state_bucket}"
}
