/**
* ## module: infra-networking
*
* Terraform module to deploy the networking required for a VPC and
* related services. You will often have multiple VPCs in an account
*
*/

variable "aws_region" {
  type        = string
  description = "AWS region"
  default     = "eu-west-1"
}

variable "environment" {
  type        = string
  description = "Unique name for this collection of resources"
}

variable "prometheus_subdomain" {
  type        = string
  description = "Subdomain for prometheus"
  default     = "monitoring"
}

# locals
# --------------------------------------------------------------

locals {
  default_tags = {
    Terraform   = "true"
    Project     = "infra-networking"
    Source      = "github.com/alphagov/prometheus-aws-configuration-beta"
    Environment = var.environment
  }

  subdomain_name         = "${var.prometheus_subdomain}.gds-reliability.engineering"
  private_subdomain_name = "${var.environment}.monitoring.private"
}

## Data sources

data "aws_availability_zones" "available" {}

## Resources

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "3.5.0"

  name = "observe-${var.environment}"
  cidr = "10.0.0.0/16"

  # subnets assumes 3 AZs although 3AZs are not implemented elsewhere
  azs             = data.aws_availability_zones.available.names
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  create_database_subnet_group = false

  enable_nat_gateway = true
  single_nat_gateway = false

  enable_dns_hostnames = true
  enable_dns_support   = true

  enable_dhcp_options      = true
  dhcp_options_domain_name = local.private_subdomain_name

  # no `Name` tag unlike other resources as this is taken care of by the vpc module `name` property
  tags = local.default_tags
}

resource "aws_route53_zone" "subdomain" {
  name = local.subdomain_name
}

resource "aws_route53_zone" "private" {
  name          = local.private_subdomain_name
  force_destroy = true
  vpc {
    vpc_id = module.vpc.vpc_id
  }
}

## Outputs

output "vpc_id" {
  value       = module.vpc.vpc_id
  description = "VPC ID where the stack resources are created"
}

output "private_subnets" {
  value       = module.vpc.private_subnets
  description = "List of private subnet IDs"
}

output "public_subnets" {
  value       = module.vpc.public_subnets
  description = "List of public subnet IDs"
}

output "public_zone_id" {
  value       = aws_route53_zone.subdomain.zone_id
  description = "Route 53 Zone ID for publicly visible zone"
}

output "public_subdomain" {
  value       = aws_route53_zone.subdomain.name
  description = "This is the subdomain for root zone"
}

output "private_zone_id" {
  value       = aws_route53_zone.private.zone_id
  description = "Route 53 Zone ID for the internal zone"
}

output "private_zone_name" {
  value       = aws_route53_zone.private.name
  description = "Route 53 Zone name for the internal zone"
}

output "private_subnets_ips" {
  value       = module.vpc.private_subnets_cidr_blocks
  description = "List of private subnet IPs"
}

output "nat_gateway" {
  value       = module.vpc.nat_public_ips
  description = "List of nat gateway IP"
}

output "private_subdomain" {
  value       = aws_route53_zone.private.name
  description = "This is the subdomain for private zone"
}

output "subnets_by_az" {
  value = zipmap(
    data.aws_availability_zones.available.names,
    module.vpc.private_subnets_cidr_blocks,
  )

  description = "Map of availability zones to private subnets"
}

