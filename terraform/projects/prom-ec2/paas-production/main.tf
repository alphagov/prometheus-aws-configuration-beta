locals {
  environment   = "production"
  config_bucket = "gdsobserve-paas-${local.environment}-config-store"
}

terraform {
  required_version = "~> 0.13.3"

  backend "s3" {
    bucket  = "govukobserve-tfstate-prom-enclave-paas-production"
    key     = "prometheus.tfstate"
    encrypt = true
    region  = "eu-west-1"
  }
}

provider "aws" {
  version = "~> 2.45"

  region              = "eu-west-1"
  allowed_account_ids = ["455214962221"]
}

data "terraform_remote_state" "infra_networking" {
  backend = "s3"

  config = {
    bucket = "prometheus-${local.environment}"
    key    = "infra-networking-modular.tfstate"
    region = "eu-west-1"
  }
}

data "terraform_remote_state" "infra_security_groups" {
  backend = "s3"

  config = {
    bucket = "prometheus-${local.environment}"
    key    = "infra-security-groups-modular.tfstate"
    region = "eu-west-1"
  }
}

data "terraform_remote_state" "app_ecs_albs" {
  backend = "s3"

  config = {
    bucket = "prometheus-${local.environment}"
    key    = "app-ecs-albs-modular.tfstate"
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

data "pass_password" "prometheus_htpasswd" {
  path = "prometheus-basic-auth-htpasswd"
}

data "pass_password" "dm_elasticsearch_metrics_password" {
  path = "dm-elasticsearch-metrics-password"
}

module "ami" {
  source = "../../../modules/common/ami"
}

module "prometheus" {
  source = "../../../modules/prom-ec2/prometheus"

  ami_id = module.ami.ubuntu_focal_ami_id

  target_vpc = data.terraform_remote_state.infra_networking.outputs.vpc_id
  enable_ssh = false

  environment   = local.environment
  config_bucket = local.config_bucket
  logstash_host = data.pass_password.logstash_endpoint.password

  prometheus_public_fqdns = data.terraform_remote_state.app_ecs_albs.outputs.prom_public_record_fqdns

  subnet_ids          = data.terraform_remote_state.infra_networking.outputs.private_subnets
  availability_zones  = data.terraform_remote_state.infra_networking.outputs.subnets_by_az
  vpc_security_groups = [data.terraform_remote_state.infra_security_groups.outputs.prometheus_ec2_sg_id]
  region              = "eu-west-1"

  prometheus_htpasswd          = data.pass_password.prometheus_htpasswd.password
  prometheus_target_group_arns = data.terraform_remote_state.app_ecs_albs.outputs.prometheus_target_group_arns
}

module "paas-config" {
  source = "../../../modules/prom-ec2/paas-config"

  environment = local.environment

  prometheus_config_bucket = module.prometheus.s3_config_bucket
  alerts_path              = "../../../modules/prom-ec2/alerts-config/alerts/"

  prom_private_ips  = module.prometheus.private_ip_addresses
  private_zone_id   = data.terraform_remote_state.infra_networking.outputs.private_zone_id
  private_subdomain = data.terraform_remote_state.infra_networking.outputs.private_subdomain

  extra_scrape_configs = yamldecode(templatefile("${path.module}/extra-prometheus-scrape-configs.yml.tpl", {
    dm_elasticsearch_metrics_password = data.pass_password.dm_elasticsearch_metrics_password.password
  }))
}

output "instance_ids" {
  value = "[\n    ${join("\n    ", module.prometheus.prometheus_instance_id)}\n]"
}
