# Locals

locals {
  product     = "test-paas"
  environment = "${local.product}-${var.test_user}"

  active_alertmanager_private_fqdns = ["alert-1.private.test.com", "alert-2.private.test.com", "alert-3.private.test.com"]
  availability_zones                = "${zipmap(data.aws_availability_zones.available.names, local.private_subnets_cidr_blocks)}"
  private_subdomain_name            = "${var.test_user}.monitoring.private"
  private_subnets_cidr_blocks       = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

# Providers

terraform {
  required_version = "= 0.11.10"
}

provider "aws" {
  region = "eu-west-1"
}

# Data sources

data "aws_availability_zones" "available" {}

# Resources

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "${var.test_user}-test-vpc"
  cidr = "10.0.0.0/16"

  # subnets assumes 3 AZs although 3AZs are not implemented elsewhere
  azs              = "${data.aws_availability_zones.available.names}"
  private_subnets  = "${local.private_subnets_cidr_blocks}"
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
  name          = "${local.private_subdomain_name}"
  force_destroy = true

  vpc {
    vpc_id = "${module.vpc.vpc_id}"
  }
}

resource "aws_security_group" "permit_internet_access" {
  vpc_id = "${module.vpc.vpc_id}"

  egress {
    protocol  = "tcp"
    from_port = 80
    to_port   = 80

    cidr_blocks = [
      "0.0.0.0/0",
    ]
  }

  egress {
    protocol  = "tcp"
    from_port = 443
    to_port   = 443

    cidr_blocks = [
      "0.0.0.0/0",
    ]
  }

  ingress {
    protocol  = "tcp"
    from_port = 22
    to_port   = 22

    cidr_blocks = [
      "0.0.0.0/0",
    ]
  }

  ingress {
    protocol  = "tcp"
    from_port = 9090
    to_port   = 9090

    cidr_blocks = [
      "0.0.0.0/0",
    ]
  }

  tags {
    Name = "Internet access & prometheus access from GDS in dev env"
  }
}
