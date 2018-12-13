## Providers

terraform {
  required_version = "= 0.11.10"

  backend "s3" {
    bucket = "re-observe-dev"
    key    = "alertmanager-modular.tfstate"
    region = "eu-west-1"
  }
}

provider "aws" {
  version = "~> 1.51.0"
  region  = "eu-west-1"
}

variable "stack_name" {
  type        = "string"
  description = "Unique name for this collection of resources"
  default     = "dev"
}

data "terraform_remote_state" "infra_networking" {
  backend = "s3"

  config {
    bucket = "re-observe-dev"
    key    = "infra-networking-modular.tfstate"
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

module "alertmanager-alb" {
  source = "../../modules/alertmanager-alb/"

  aws_region    = "eu-west-1"
  stack_name    = "${var.stack_name}"
  subnets       = "${data.terraform_remote_state.infra_networking.public_subnets}"
  zone_id       = "${data.terraform_remote_state.infra_networking.public_zone_id}"
  vpc_id        = "${data.terraform_remote_state.infra_networking.vpc_id}"
  alerts_fqdns  = "${data.terraform_remote_state.app_ecs_albs.alerts_public_record_fqdns}"
  target_groups = "${data.terraform_remote_state.app_ecs_albs.monitoring_internal_tg}"
}
