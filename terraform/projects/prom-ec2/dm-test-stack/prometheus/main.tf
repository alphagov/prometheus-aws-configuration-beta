locals {
  product                           = "paas"
  environment                       = "dm-test-stack"
  config_bucket                     = "gdsobserve-${local.product}-${local.environment}-config-store"
  active_alertmanager_private_fqdns = "${slice(data.terraform_remote_state.app_ecs_albs.alerts_private_record_fqdns, 0,
 3)}"
}

terraform {
  required_version = "= 0.11.10"

  backend "s3" {
    bucket  = "govukobserve-tfstate-prom-enclave-dm-test-stack"
    key     = "prometheus.tfstate"
    encrypt = true
    region  = "eu-west-1"
  }
}

provider "aws" {
  region              = "eu-west-1"
  allowed_account_ids = ["047969882937"]
}

data "terraform_remote_state" "infra_networking" {
  backend = "s3"

  config {
    bucket = "${local.environment}"
    key    = "infra-networking-modular.tfstate"
    region = "eu-west-1"
  }
}

data "terraform_remote_state" "infra_security_groups" {
  backend = "s3"

  config {
    bucket = "${local.environment}"
    key    = "infra-security-groups-modular.tfstate"
    region = "eu-west-1"
  }
}

data "terraform_remote_state" "app_ecs_albs" {
  backend = "s3"

  config {
    bucket = "${local.environment}"
    key    = "app-ecs-albs-modular.tfstate"
    region = "eu-west-1"
  }
}

module "prometheus" {
  source = "../../../../modules/prom-ec2/prometheus"

  # Canonicals Ubunutu 18.04 Bionic Beaver in eu-west-1
  ami_id = "ami-0ee06eb8d6eebcde0"

  target_vpc = "vpc-e3c39685"
  enable_ssh = true

  product        = "${local.product}"
  environment    = "${local.environment}"
  config_bucket  = "${local.config_bucket}"
  targets_bucket = "gds-prometheus-targets-${local.environment}"

  prometheus_public_fqdns = "${data.terraform_remote_state.app_ecs_albs.prom_public_record_fqdns}"

  subnet_ids            = "${data.terraform_remote_state.infra_networking.public_subnets}"
  availability_zones    = "${data.terraform_remote_state.infra_networking.subnets_by_az}"
  vpc_security_groups   = ["${data.terraform_remote_state.infra_security_groups.monitoring_external_sg_id}"]
  source_security_group = "${data.terraform_remote_state.infra_security_groups.monitoring_internal_sg_id}"
  region                = "eu-west-1"
}

module "paas-config" {
  source = "../../../../modules/prom-ec2/paas-config"

  prometheus_config_bucket = "${module.prometheus.s3_config_bucket}"
  prom_private_ips         = "${module.prometheus.private_ip_addresses}"
  private_zone_id          = "${data.terraform_remote_state.infra_networking.private_zone_id}"
  private_subdomain        = "${data.terraform_remote_state.infra_networking.private_subdomain}"
  alertmanager_dns_names   = "${join("\",\"", local.active_alertmanager_private_fqdns)}"
  alerts_path              = "../../../../projects/app-ecs-services/config/alerts/"

  prometheus_sg_id = "${module.prometheus.ec2_instance_prometheus_sg}"
}

output "public_ips" {
  value = "${module.prometheus.public_ip_address}"
}

output "public_dns" {
  value = "[\n    ${join("\n    ", formatlist("%s:9090", module.prometheus.prometheus_public_dns))}\n]"
}

output "private_ips" {
  value = "${module.prometheus.private_ip_addresses}"
}
