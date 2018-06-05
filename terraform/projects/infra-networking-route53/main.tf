/**
* ## Project: infra-networking-route53
*
* Terraform project to setup route53 with alias records to our ALBs.
*
* When running for `staging` and `production` environments, this will set up a
* new DNS hosted zone, for example `monitoring-staging.gds-reliability.engineering` using the
* `prometheus_subdomain` variable from the `tfvars` file.
*
* When running for development environments, this will create a new zone and
* delegate it to our shared `dev.gds-reliability.engineering` zone
* for example `your-stack.dev.gds-reliability.engineering`.
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

variable "stack_name" {
  type        = "string"
  description = "Unique name for this collection of resources"
  default     = "ecs-monitoring"
}

# locals
# --------------------------------------------------------------

locals {
  create_dev_count = "${(var.stack_name == "production" || var.stack_name == "staging") ? 0 : 1}"
  subdomain_name   = "${(var.stack_name == "production" || var.stack_name == "staging") ? "${var.prometheus_subdomain}.gds-reliability.engineering" : "${var.prometheus_subdomain}.${aws_route53_zone.shared_dev_subdomain.name}"}"
}

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
# --------------------------------------------------------------
# These resources are only created for staging or production environments (not dev)

resource "aws_route53_zone" "subdomain" {
  name = "${local.subdomain_name}"
}

resource "aws_route53_record" "prom_alias" {
  zone_id = "${aws_route53_zone.subdomain.zone_id}"
  name    = "prom-1"
  type    = "A"

  alias {
    name                   = "${data.terraform_remote_state.app-ecs-albs.dns_name}"
    zone_id                = "${data.terraform_remote_state.app-ecs-albs.zone_id}"
    evaluate_target_health = false
  }
}

## Development resources
# --------------------------------------------------------------
# These resources are only created for development environments (not staging or prod)

resource "aws_route53_zone" "shared_dev_subdomain" {
  count = "${local.create_dev_count}"
  name  = "dev.gds-reliability.engineering"
}

resource "aws_route53_record" "shared_dev_ns" {
  count   = "${local.create_dev_count}"
  zone_id = "${aws_route53_zone.shared_dev_subdomain.zone_id}"
  name    = "${var.stack_name}.${aws_route53_zone.shared_dev_subdomain.name}"
  type    = "NS"
  ttl     = "30"

  records = [
    "${aws_route53_zone.subdomain.name_servers.0}",
    "${aws_route53_zone.subdomain.name_servers.1}",
    "${aws_route53_zone.subdomain.name_servers.2}",
    "${aws_route53_zone.subdomain.name_servers.3}",
  ]
}

## Outputs

output "public_zone_id" {
  value       = "${aws_route53_zone.subdomain.zone_id}"
  description = "Route 53 Zone ID for publicly visible zone"
}
