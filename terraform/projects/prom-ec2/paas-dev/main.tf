locals {
  product                           = "paas"
  environment                       = "dev"
  config_bucket                     = "gdsobserve-${local.product}-${local.environment}-config-store"
  active_alertmanager_private_fqdns = "${slice(data.terraform_remote_state.app_ecs_albs.alerts_private_record_fqdns, 0,
 3)}"
}

terraform {
  required_version = "= 0.11.10"

  backend "s3" {
    bucket  = "re-prom-dev-tfstate"
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
    bucket = "re-observe-dev"
    key    = "infra-networking-modular.tfstate"
    region = "eu-west-1"
  }
}

data "terraform_remote_state" "infra_security_groups" {
  backend = "s3"

  config {
    bucket = "re-observe-dev"
    key    = "infra-security-groups-modular.tfstate"
    region = "eu-west-1"
  }
}

data "terraform_remote_state" "app_ecs_albs" {
  backend = "s3"

  config {
    bucket = "re-observe-dev"
    key    = "app-ecs-albs-modular.tfstate"
    region = "eu-west-1"
  }
}

module "ami" {
  source = "../../../modules/common/ami"
}

module "prometheus" {
  source = "../../../modules/prom-ec2/prometheus"

  ami_id = "${module.ami.ubuntu_bionic_ami_id}"

  target_vpc = "${data.terraform_remote_state.infra_networking.vpc_id}"
  enable_ssh = false

  product        = "${local.product}"
  environment    = "${local.environment}"
  config_bucket  = "${local.config_bucket}"
  targets_bucket = "gds-prometheus-targets-${local.environment}"

  prometheus_public_fqdns = "${data.terraform_remote_state.app_ecs_albs.prom_public_record_fqdns}"

  subnet_ids            = "${data.terraform_remote_state.infra_networking.private_subnets}"
  availability_zones    = "${data.terraform_remote_state.infra_networking.subnets_by_az}"
  vpc_security_groups   = ["${data.terraform_remote_state.infra_security_groups.monitoring_external_sg_id}"]
  source_security_group = "${data.terraform_remote_state.infra_security_groups.monitoring_internal_sg_id}"
  region                = "eu-west-1"

  # basic auth password is 'hello world'
  prometheus_htpasswd          = "grafana:$6$DoATHwJM$ws9EPPNpFe6fmKgBPa/3CX3C4f1F1cHi/pnxjYrGR3y652gIRtTzgl/ZFCLiRfa9/1jfgRBsNITelo1JNiiJD/"
  prometheus_target_group_arns = "${data.terraform_remote_state.app_ecs_albs.prometheus_target_group_arns}"
}

module "paas-config" {
  source = "../../../modules/prom-ec2/paas-config"

  prometheus_config_bucket = "${module.prometheus.s3_config_bucket}"
  alertmanager_dns_names   = "${local.active_alertmanager_private_fqdns}"
  alerts_path              = "../../../modules/app-ecs-services/config/alerts/"

  prom_private_ips  = "${module.prometheus.private_ip_addresses}"
  private_zone_id   = "${data.terraform_remote_state.infra_networking.private_zone_id}"
  private_subdomain = "${data.terraform_remote_state.infra_networking.private_subdomain}"

  prometheus_sg_id = "${module.prometheus.ec2_instance_prometheus_sg}"
}

output "instance_ids" {
  value = "[\n    ${join("\n    ", module.prometheus.prometheus_instance_id)}\n]"
}
