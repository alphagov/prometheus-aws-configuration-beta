/**
* ## Module: infra-networking
*
* Terraform module to deploy the networking required for a VPC and
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

variable "dev_environment" {
  type        = "string"
  description = "Boolean flag for development environments"
  default     = "true"
}

variable "stack_name" {
  type        = "string"
  description = "Unique name for this collection of resources"
  default     = "ecs-monitoring"
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

  shared_dev_subdomain_name = "dev.gds-reliability.engineering"
  subdomain_name            = "${var.dev_environment == "true" ? "${var.prometheus_subdomain}.${local.shared_dev_subdomain_name}" : "${var.prometheus_subdomain}.gds-reliability.engineering"}"
  private_subdomain_name    = "${var.stack_name}.monitoring.private"
}

## Providers

terraform {
  required_version = "= 0.11.10"

  backend "s3" {
    key = "infra-networking.tfstate"
  }
}

provider "aws" {
  version = "~> 1.14.1"
  region  = "${var.aws_region}"
}

## Data sources

module "vpc" {
  source         = "../../modules/common/vpc"
  environment    = "${var.stack_name}"
}

data "aws_availability_zones" "available" {}

## Resources

resource "aws_route53_zone" "subdomain" {
  name = "${local.subdomain_name}"
}

resource "aws_route53_zone" "private" {
  vpc_id        = "${module.vpc.vpc_id}"
  name          = "${local.private_subdomain_name}"
  force_destroy = true
}

## Development resources
# --------------------------------------------------------------
# These resources are only created for development environments (not staging or prod)
# This is to add the extra delegation from dev.gds-reliability.engineering to the prometheus subdomain

data "aws_route53_zone" "shared_dev_subdomain" {
  count = "${var.dev_environment == "true" ? 1 : 0}"
  name  = "${local.shared_dev_subdomain_name}"
}

resource "aws_route53_record" "shared_dev_ns" {
  count   = "${var.dev_environment == "true" ? 1 : 0}"
  zone_id = "${data.aws_route53_zone.shared_dev_subdomain.zone_id}"
  name    = "${var.stack_name}.${data.aws_route53_zone.shared_dev_subdomain.name}"
  type    = "NS"
  ttl     = "30"

  records = [
    "${aws_route53_zone.subdomain.name_servers.0}",
    "${aws_route53_zone.subdomain.name_servers.1}",
    "${aws_route53_zone.subdomain.name_servers.2}",
    "${aws_route53_zone.subdomain.name_servers.3}",
  ]
}

## Outputs

output "public_zone_id" {
  value       = "${aws_route53_zone.subdomain.zone_id}"
  description = "Route 53 Zone ID for publicly visible zone"
}

output "public_subdomain" {
  value       = "${aws_route53_zone.subdomain.name}"
  description = "This is the subdomain for root zone"
}

output "private_zone_id" {
  value       = "${aws_route53_zone.private.zone_id}"
  description = "Route 53 Zone ID for the internal zone"
}

output "private_zone_name" {
  value       = "${aws_route53_zone.private.name}"
  description = "Route 53 Zone name for the internal zone"
}


output "private_subdomain" {
  value       = "${aws_route53_zone.private.name}"
  description = "This is the subdomain for private zone"
}

output "subnets_by_az" {
  value = "${
   zipmap(
     data.aws_availability_zones.available.names,
     module.vpc.private_subnets_cidr_blocks
   )
 }"

  description = "Map of availability zones to private subnets"
}
