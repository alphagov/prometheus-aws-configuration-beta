locals {
  product                           = "paas"
  environment                       = "production"
  config_bucket                     = "gdsobserve-${local.product}-${local.environment}-config-store"
  active_alertmanager_private_fqdns = "${slice(data.terraform_remote_state.app_ecs_albs.alerts_private_record_fqdns, 0,
 3)}"
}

terraform {
  required_version = "= 0.11.7"

  backend "s3" {
    bucket  = "govukobserve-tfstate-prom-enclave-paas-production"
    key     = "prometheus.tfstate"
    encrypt = true
    region  = "eu-west-1"
  }
}

provider "aws" {
  region              = "eu-west-1"
  allowed_account_ids = ["455214962221"]
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

data "terraform_remote_state" "app_ecs_albs" {
  backend = "s3"

  config {
    bucket = "prometheus-${local.environment}"
    key    = "app-ecs-albs.tfstate"
    region = "eu-west-1"
  }
}

module "prometheus" {
  source = "../../../../modules/enclave/prometheus"

  # Canonicals Ubunutu 18.04 Bionic Beaver in eu-west-1
  ami_id = "ami-0ee06eb8d6eebcde0"

  # Production
  target_vpc = "vpc-0cdd9631927b526ce"
  enable_ssh = true

  product        = "${local.product}"
  environment    = "${local.environment}"
  config_bucket  = "${local.config_bucket}"
  targets_bucket = "gds-prometheus-targets"

  prometheus_public_fqdns = "${data.terraform_remote_state.app_ecs_albs.prom_public_record_fqdns}"

  subnet_ids          = "${data.terraform_remote_state.network.public_subnets}"
  availability_zones  = "${data.terraform_remote_state.network.subnets_by_az}"
  vpc_security_groups = ["${data.terraform_remote_state.sg.monitoring_external_sg_id}"]
  region              = "eu-west-1"
}

module "paas-config" {
  source = "../../../../modules/enclave/paas-config"

  environment              = "${local.environment}"
  prometheus_dns_names     = "${data.terraform_remote_state.app_ecs_albs.prom_private_record_fqdns}"
  prometheus_dns_nodes     = "${join("\",\"", formatlist("%s:9100", module.prometheus.prometheus_private_dns))}"
  prometheus_config_bucket = "${module.prometheus.s3_config_bucket}"
  alertmanager_dns_names   = "${join("\",\"", local.active_alertmanager_private_fqdns)}"
  alerts_path              = "../../../../projects/app-ecs-services/config/alerts/"

  prom_private_ips  = "${module.prometheus.private_ip_addresses}"
  private_zone_id   = "${data.terraform_remote_state.network.private_zone_id}"
  private_subdomain = "${data.terraform_remote_state.network.private_subdomain}"

  paas_proxy_sg_id = "${data.terraform_remote_state.sg.alertmanager_external_sg_id}"
  prometheus_sg_id = "${module.prometheus.ec2_instance_prometheus_sg}"
}

output "public_ips" {
  value = "${module.prometheus.public_ip_address}"
}

output "public_dns" {
  value = "[\n    ${join("\n    ", formatlist("%s:9090", module.prometheus.prometheus_public_dns))}\n]"
}
