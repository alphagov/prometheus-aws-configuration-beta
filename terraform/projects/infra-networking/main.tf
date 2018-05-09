/**
* ## Project: infra-networking
*
* Terraform project to deploy the networking required for a VPC and
* related services. You will often have multiple VPCs in an account
*
*/

variable "additional_tags" {
  type        = "map"
  description = "Stack specific tags to apply"
  default     = {}
}

variable "aws_region" {
  type        = "string"
  description = "AWS region"
  default     = "eu-west-1"
}

variable "stack_name" {
  type        = "string"
  description = "Unique name for this collection of resources"
  default     = "ecs-monitoring"
}

# locals
# --------------------------------------------------------------

locals {
  default_tags = {
    Terraform = "true"
    Project   = "infra-networking"
  }
}

# Resources
# --------------------------------------------------------------

## Providers

terraform {
  required_version = "= 0.11.7"

  backend "s3" {
    key = "infra-networking.tfstate"
  }
}

provider "aws" {
  version = "~> 1.14.1"
  region  = "${var.aws_region}"
}

## Data sources

data "aws_availability_zones" "available" {}

## Resources

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "${var.stack_name}-vpc"
  cidr = "10.0.0.0/16"

  # subnets assumes 3 AZs although 3AZs are not implemented elsewhere
  azs              = "${data.aws_availability_zones.available.names}"
  private_subnets  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets   = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  database_subnets = ["10.0.201.0/24", "10.0.202.0/24", "10.0.203.0/24"]

  enable_nat_gateway = true

  # no `Name` tag unlike other resources as this is taken care of by the vpc module `name` property
  tags = "${merge(
    local.default_tags,
    var.additional_tags,
    map("Stackname", var.stack_name)
  )}"
}

## Outputs

output "vpc_id" {
  value       = "${module.vpc.vpc_id}"
  description = "VPC ID where the stack resources are created"
}

output "private_subnets" {
  value       = "${module.vpc.private_subnets}"
  description = "List of private subnet IDs"
}

output "public_subnets" {
  value       = "${module.vpc.public_subnets}"
  description = "List of public subnet IDs"
}
