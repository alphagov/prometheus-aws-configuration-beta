locals {
  product       = "hub"
  environment   = "perf"
  config_bucket = "gdsobserve-verify-${local.environment}-prometheus-config-store"
}

terraform {
  required_version = "= 0.11.7"

  backend "s3" {
    bucket  = "govukobserve-tfstate-prom-enclave-verify-perf-a"
    key     = "prometheus.tfstate"
    encrypt = true
    region  = "eu-west-2"
  }
}

provider "aws" {
  region              = "eu-west-2"
  allowed_account_ids = ["170611269615"]
}

data "terraform_remote_state" "network" {
  backend = "s3"

  config {
    bucket  = "govukobserve-tfstate-prom-enclave-verify-perf-a"
    key     = "network.tfstate"
    encrypt = true
    region  = "eu-west-2"
  }
}

module "prometheus" {
  source = "../../../../modules/enclave/prometheus"

  # Canonicals Ubunutu 18.04 Bionic Beaver in eu-west-2
  ami_id = "ami-e4ad5983"

  # Verifys perf-a low-vpc
  target_vpc = "vpc-0067a6d5138a90c5e"

  enable_ssh   = true
  egress_proxy = "egress-proxy.service.dmz:8080"

  product       = "${local.product}"
  environment   = "${local.environment}"
  config_bucket = "${local.config_bucket}"

  subnet_ids          = "${data.terraform_remote_state.network.subnet_ids}"
  availability_zones  = "${data.terraform_remote_state.network.availability_zones}"
  vpc_security_groups = ["${data.terraform_remote_state.network.security_groups}"]
  ec2_endpoint_ips    = ["${data.terraform_remote_state.network.endpoint_network_interface_ip}"]
}

module "verify-config" {
  source = "../../../../modules/enclave/verify-config"

  ec2_instance_profile_name = "${module.prometheus.ec2_instance_profile_name}"
  prometheus_config_bucket  = "${local.config_bucket}"
}

module "private_dns" {
  source = "../../../../modules/enclave/verify-dns"

  prometheus_private_ips = "${module.prometheus.private_ip_address}"
  hosted_zone_name       = "service.dmz"
  target_vpc             = "vpc-0067a6d5138a90c5e"
}

output "public_ips" {
  value = "${module.prometheus.public_ip_address}"
}
