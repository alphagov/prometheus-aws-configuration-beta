locals {
  product                           = "paas"
  environment                       = "production"
  config_bucket                     = "gdsobserve-${local.product}-${local.environment}-config-store"
  active_alertmanager_private_fqdns = "${slice(data.terraform_remote_state.app_ecs_albs.alerts_private_record_fqdns, 0,
 3)}"
}

terraform {
  required_version = "= 0.11.10"

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

data "terraform_remote_state" "infra_networking" {
  backend = "s3"

  config {
    bucket = "prometheus-${local.environment}"
    key    = "infra-networking-modular.tfstate"
    region = "eu-west-1"
  }
}

data "terraform_remote_state" "infra_security_groups" {
  backend = "s3"

  config {
    bucket = "prometheus-${local.environment}"
    key    = "infra-security-groups-modular.tfstate"
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

provider "pass" {
  store_dir     = "~/.password-store/re-secrets/observe"
  refresh_store = true
}

data "pass_password" "logstash_endpoint" {
  path = "logit/prometheus-paas-logstash-endpoint-prod"
}

module "ami" {
  source = "../../../../modules/common/ami"
}

module "prometheus" {
  source = "../../../../modules/enclave/prometheus"

  ami_id = "${module.ami.ubuntu_bionic_ami_id}"

  # Production
  target_vpc = "vpc-0cdd9631927b526ce"
  enable_ssh = false

  product        = "${local.product}"
  environment    = "${local.environment}"
  config_bucket  = "${local.config_bucket}"
  targets_bucket = "gds-prometheus-targets"
  instance_size  = "m4.large"
  logstash_host  = "${data.pass_password.logstash_endpoint.password}"

  prometheus_public_fqdns = "${data.terraform_remote_state.app_ecs_albs.prom_public_record_fqdns}"

  subnet_ids          = "${data.terraform_remote_state.infra_networking.private_subnets}"
  availability_zones  = "${data.terraform_remote_state.infra_networking.subnets_by_az}"
  vpc_security_groups = ["${data.terraform_remote_state.infra_security_groups.monitoring_external_sg_id}"]
  region              = "eu-west-1"
}

module "paas-config" {
  source = "../../../../modules/enclave/paas-config"

  environment              = "${local.environment}"
  prometheus_config_bucket = "${module.prometheus.s3_config_bucket}"
  alertmanager_dns_names   = "${join("\",\"", local.active_alertmanager_private_fqdns)}"
  alerts_path              = "../../../../projects/app-ecs-services/config/alerts/"

  prom_private_ips  = "${module.prometheus.private_ip_addresses}"
  private_zone_id   = "${data.terraform_remote_state.infra_networking.private_zone_id}"
  private_subdomain = "${data.terraform_remote_state.infra_networking.private_subdomain}"

  paas_proxy_sg_id = "${data.terraform_remote_state.infra_security_groups.alertmanager_external_sg_id}"
  prometheus_sg_id = "${module.prometheus.ec2_instance_prometheus_sg}"
}

output "public_dns" {
  value = "[\n    ${join("\n    ", formatlist("%s:9090", module.prometheus.prometheus_public_dns))}\n]"
}

output "instance_ids" {
  value = "[\n    ${join("\n    ", module.prometheus.prometheus_instance_id)}\n]"
}
