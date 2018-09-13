locals {
  product       = "paas"
  environment   = "staging"
  config_bucket = "gdsobserve-${local.product}-${local.environment}-config-store"
}

terraform {
  required_version = "= 0.11.7"

  backend "s3" {
    bucket  = "govukobserve-tfstate-prom-enclave-paas-staging"
    key     = "prometheus.tfstate"
    encrypt = true
    region  = "eu-west-1"
  }
}

provider "aws" {
  region              = "eu-west-1"
  allowed_account_ids = ["027317422673"]
}

data "terraform_remote_state" "network" {
  backend = "s3"

  config {
    bucket = "prometheus-${local.environment}"
    key    = "infra-networking.tfstate"
    region = "eu-west-1"
  }
}

data "terraform_remote_state" "sg" {
  backend = "s3"

  config {
    bucket = "prometheus-${local.environment}"
    key    = "infra-security-groups.tfstate"
    region = "eu-west-1"
  }
}

module "prometheus" {
  source = "../../../../modules/enclave/prometheus"

  # Canonicals Ubunutu 18.04 Bionic Beaver in eu-west-1
  ami_id = "ami-0ee06eb8d6eebcde0"

  # Staging
  target_vpc = "vpc-0bbf4123f5b385806"
  enable_ssh = true

  product       = "${local.product}"
  environment   = "${local.environment}"
  config_bucket = "${local.config_bucket}"

  subnet_ids          = "${data.terraform_remote_state.network.public_subnets}"
  availability_zones  = "${data.terraform_remote_state.network.subnets_by_az}"
  vpc_security_groups = ["${data.terraform_remote_state.sg.monitoring_external_sg_id}"]
  region              = "eu-west-1"
}

module "paas-config" {
  source = "../../../../modules/enclave/paas-config"

  prometheus_dns_names     = "${join("\",\"", formatlist("%s:9090", module.prometheus.prometheus_private_dns))}"
  prometheus_config_bucket = "${local.config_bucket}"
}

output "public_ips" {
  value = "${module.prometheus.public_ip_address}"
}

output "public_dns" {
  value = "[\n    ${join("\n    ", formatlist("%s:9090", module.prometheus.prometheus_public_dns))}\n]"
}
