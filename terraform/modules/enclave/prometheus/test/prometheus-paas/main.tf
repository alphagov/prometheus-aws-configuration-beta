variable "aws_region" {
  type        = "string"
  description = "AWS region"
  default     = "eu-west-2"
}

variable "stack_name" {
  type        = "string"
  description = "Unique name for this collection of resources"
  default     = "ec2-monitoring"
}

variable "prometheus_subdomain" {
  type        = "string"
  description = "Subdomain for prometheus"
  default     = "monitoring"
}

# locals
# --------------------------------------------------------------

locals {
  default_tags = {
    Terraform = "true"
    Project   = "infra-networking"
  }

  private_subdomain_name = "${var.stack_name}.monitoring.private"

  availability_zones = "${
    zipmap(
      data.aws_availability_zones.available.names,
      module.vpc.public_subnets_cidr_blocks
    )
  }"
}

## Providers

terraform {
  required_version = "= 0.11.7"
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

  name = "ptom-test-vpc"
  cidr = "10.0.0.0/16"

  # subnets assumes 3 AZs although 3AZs are not implemented elsewhere
  azs              = "${data.aws_availability_zones.available.names}"
  private_subnets  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets   = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  database_subnets = ["10.0.201.0/24", "10.0.202.0/24", "10.0.203.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = "true"

  enable_dns_hostnames = true
  enable_dns_support   = true

  enable_dhcp_options      = true
  dhcp_options_domain_name = "${local.private_subdomain_name}"
}

resource "aws_route53_zone" "private" {
  vpc_id        = "${module.vpc.vpc_id}"
  name          = "${local.private_subdomain_name}"
  force_destroy = true
}

## Outputs

