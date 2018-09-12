provider "aws" {
  region = "eu-west-2" # "${var.aws_region}"
}

terraform {
  required_version = "= 0.11.7"
}

locals {
  config_bucket = "reobserve-kitchen-prometheus-config-test"
  product       = "hub-testing"
  enviroment    = "test"
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
  source              = "../../../network"
  environment         = "${local.enviroment}"
  product             = "${local.product}"
  target_vpc          = "${aws_vpc.main.id}"
  internet_gateway_id = "${aws_internet_gateway.internet_gateway.id}"

  availability_zones = {
    "eu-west-2a" = "10.0.3.32/28"
    "eu-west-2b" = "10.0.3.48/28"
  }
}

module "prometheus" {
  source = "../../../prometheus"

  # Canonicals Ubunutu 18.04 Bionic Beaver in eu-west-2
  ami_id = "ami-e4ad5983"

  # Verifys perf-a low-vpc
  target_vpc = "${aws_vpc.main.id}"

  enable_ssh   = true
  egress_proxy = ""

  product       = "${local.product}"
  environment   = "${local.enviroment}"
  config_bucket = "${local.config_bucket}"

  subnet_ids          = "${module.network.subnet_ids}"
  availability_zones  = "${module.network.availability_zones}"
  vpc_security_groups = ["${module.network.security_groups}", "${aws_security_group.permit_internet_access.id}"]
  ec2_endpoint_ips    = "${module.network.endpoint_network_interface_ip}"
}

module "verify-config" {
  source = "../../../verify-config"

  ec2_instance_profile_name = "${module.prometheus.ec2_instance_profile_name}"
  prometheus_config_bucket  = "${module.prometheus.s3_config_bucket}"
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
