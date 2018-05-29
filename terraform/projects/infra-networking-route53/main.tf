/**
* ## Project: infra-networking-route53
*
* Terraform project to setup route53
*
*/

variable "aws_region" {
  type        = "string"
  description = "AWS region"
  default     = "eu-west-1"
}

variable "prometheus_subdomain" {
  type        = "string"
  description = "Subdomain for prometheus"
  default     = "monitoring"
}

variable "remote_state_bucket" {
  type        = "string"
  description = "S3 bucket we store our terraform state in"
  default     = "ecs-monitoring"
}

# locals
# --------------------------------------------------------------

# Resources
# --------------------------------------------------------------

## Providers

terraform {
  required_version = "= 0.11.7"

  backend "s3" {
    key = "infra-networking-route53.tfstate"
  }
}

provider "aws" {
  version = "~> 1.14.1"
  region  = "${var.aws_region}"
}

## Data sources

data "terraform_remote_state" "app-ecs-albs" {
  backend = "s3"

  config {
    bucket = "${var.remote_state_bucket}"
    key    = "app-ecs-albs.tfstate"
    region = "${var.aws_region}"
  }
}

## Resources

resource "aws_route53_zone" "subdomain" {
  name = "${var.prometheus_subdomain}.gds-reliability.engineering"
}

resource "aws_route53_record" "prom-alias" {
  zone_id = "${aws_route53_zone.subdomain.zone_id}"
  name    = "prom-1"
  type    = "A"

  alias {
    name                   = "${data.terraform_remote_state.app-ecs-albs.dns_name}"
    zone_id                = "${data.terraform_remote_state.app-ecs-albs.zone_id}"
    evaluate_target_health = false
  }
}

## Outputs

