provider "aws" {
  region = "eu-west-2" # "${var.aws_region}"
}

terraform {
  required_version = ">= 0.11.7"
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/22"
  enable_dns_hostnames = true
  enable_dns_support   = true
}

resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = "${aws_vpc.main.id}"
}

module "network" {
  source              = "../../../../enclave/network"
  environment         = "perf-test"
  product             = "hub"
  target_vpc          = "${aws_vpc.main.id}"
  internet_gateway_id = "${aws_internet_gateway.internet_gateway.id}"

  availability_zones = {
    "eu-west-2a" = "10.0.3.32/28"
    "eu-west-2b" = "10.0.3.48/28"
  }
}

module "Prometheus" {
  source = "../../../../enclave/prometheus"

  ami_id     = "ami-e4ad5983"
  target_vpc = "${aws_vpc.main.id}"
  enable_ssh = true

  product     = "hub"
  environment = "perf-test"

  subnet_ids          = "${module.network.subnet_ids}"
  availability_zones  = "${module.network.availability_zones}"
  vpc_security_groups = ["${module.network.security_groups}", "${aws_security_group.permit_internet_access.id}"]
  ec2_endpoint_ips    = "${module.network.endpoint_network_interface_ip}"
  verify_enclave      = "false"
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

  tags {
    Name = "SSH from GDS"
  }
}
