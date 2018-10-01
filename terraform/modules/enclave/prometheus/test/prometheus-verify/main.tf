# Locals

locals {
  product     = "test-verify"
  environment = "${local.product}-${var.test_user}"
}

# Providers

terraform {
  required_version = "= 0.11.7"
}

provider "aws" {
  region = "eu-west-2"
}

# Resources

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/22"
  enable_dns_hostnames = true
  enable_dns_support   = true
}

resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = "${aws_vpc.main.id}"
}

module "network" {
  source              = "../../../network"
  environment         = "${local.environment}"
  product             = "${local.environment}"
  target_vpc          = "${aws_vpc.main.id}"
  internet_gateway_id = "${aws_internet_gateway.internet_gateway.id}"

  availability_zones = {
    "eu-west-2a" = "10.0.3.32/28"
    "eu-west-2b" = "10.0.3.48/28"
  }
}

resource "aws_security_group" "permit_internet_access" {
  vpc_id = "${aws_vpc.main.id}"

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
