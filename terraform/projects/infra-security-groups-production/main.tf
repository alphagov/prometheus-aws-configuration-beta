terraform {
  required_version = "= 0.11.10"

  backend "s3" {
    bucket = "prometheus-production"
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
  default     = "prometheus-production"
}

variable "stack_name" {
  type        = "string"
  description = "Unique name for this collection of resources"
  default     = "production"
}

variable "project" {
  type        = "string"
  description = "Project name for tag"
  default     = "infra-security-groups-production"
}

module "infra-security-groups" {
    source = "../../modules/infra-security-groups/"

    aws_region          = "${var.aws_region}"
    stack_name          = "production"
    remote_state_bucket = "prometheus-production"
    project             = "${var.project}"
}