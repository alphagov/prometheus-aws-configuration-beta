
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
  single_nat_gateway = "${var.dev_environment == "true" ? true : false }"

  enable_dns_hostnames = true
  enable_dns_support   = true

  enable_dhcp_options      = true
  dhcp_options_domain_name = "${local.private_subdomain_name}"

  # no `Name` tag unlike other resources as this is taken care of by the vpc module `name` property
  tags = "${merge(
    local.default_tags,
    var.additional_tags,
    map("Stackname", var.stack_name)
  )}"
}

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

output "private_subnets_ips" {
  value       = "${module.vpc.private_subnets_cidr_blocks}"
  description = "List of private subnet IPs"
}

output "nat_gateway" {
  value       = "${module.vpc.nat_public_ips}"
  description = "List of nat gateway IP"
}