terraform {
  required_version = "~> 0.13.3"

  backend "s3" {
    bucket = "prometheus-production"
    key    = "infra-networking-modular.tfstate"
    region = "eu-west-1"
  }
}

provider "aws" {
  region = var.aws_region
}

variable "prometheus_subdomain" {
  type        = string
  description = "Subdomain for prometheus"
  default     = "monitoring"
}

variable "aws_region" {
  type        = string
  description = "The AWS region to use."
  default     = "eu-west-1"
}

module "infra-networking" {
  source = "../../modules/infra-networking"

  environment          = "production"
  prometheus_subdomain = var.prometheus_subdomain
}

output "vpc_id" {
  value       = module.infra-networking.vpc_id
  description = "VPC ID where the stack resources are created"
}

output "private_subnets" {
  value       = module.infra-networking.private_subnets
  description = "List of private subnet IDs"
}

output "public_subnets" {
  value       = module.infra-networking.public_subnets
  description = "List of public subnet IDs"
}

output "public_zone_id" {
  value       = module.infra-networking.public_zone_id
  description = "Route 53 Zone ID for publicly visible zone"
}

output "public_subdomain" {
  value       = module.infra-networking.public_subdomain
  description = "This is the subdomain for root zone"
}

output "private_zone_id" {
  value       = module.infra-networking.private_zone_id
  description = "Route 53 Zone ID for the internal zone"
}

output "private_subdomain" {
  value       = module.infra-networking.private_subdomain
  description = "This is the subdomain for private zone"
}

output "subnets_by_az" {
  value       = module.infra-networking.subnets_by_az
  description = "Map of availability zones to private subnets"
}

