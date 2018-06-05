/**
* ## Project: app-ecs-albs
*
* Create ALBs for the ECS cluster
*
*/

variable "additional_tags" {
  type        = "map"
  description = "Stack specific tags to apply"
  default     = {}
}

variable "aws_region" {
  type        = "string"
  description = "AWS region"
  default     = "eu-west-1"
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
  default_tags = {
    Terraform = "true"
    Project   = "app-ecs-albs"
  }
}

# Resources
# --------------------------------------------------------------

## Providers

terraform {
  required_version = "= 0.11.7"

  backend "s3" {
    key = "app-ecs-albs.tfstate"
  }
}

provider "aws" {
  version = "~> 1.14.1"
  region  = "${var.aws_region}"
}

## Data sources

data "terraform_remote_state" "infra_networking" {
  backend = "s3"

  config {
    bucket = "${var.remote_state_bucket}"
    key    = "infra-networking.tfstate"
    region = "${var.aws_region}"
  }
}

data "terraform_remote_state" "infra_security_groups" {
  backend = "s3"

  config {
    bucket = "${var.remote_state_bucket}"
    key    = "infra-security-groups.tfstate"
    region = "${var.aws_region}"
  }
}

## Resources

resource "aws_lb" "monitoring_external_alb" {
  count = "${length(data.terraform_remote_state.infra_networking.public_subnets)}"

  name               = "${var.stack_name}-ext-alb-${count.index + 1}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["${data.terraform_remote_state.infra_security_groups.monitoring_external_sg_id}"]

  subnets = [
    "${data.terraform_remote_state.infra_networking.public_subnets}",
  ]

  tags = "${merge(
    local.default_tags,
    var.additional_tags,
    map("Stackname", "${var.stack_name}"),
    map("Name", "${var.stack_name}-prometheus-external-${count.index + 1}")
  )}"
}

resource "aws_route53_record" "prom_alias" {
  count = "${length(data.terraform_remote_state.infra_networking.public_subnets)}"

  zone_id = "${data.terraform_remote_state.infra_networking.public_zone_id}"
  name    = "prom-${count.index + 1}"
  type    = "A"

  alias {
    name                   = "${element(aws_lb.monitoring_external_alb.*.dns_name, count.index)}"
    zone_id                = "${element(aws_lb.monitoring_external_alb.*.zone_id, count.index)}"
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "alerts_alias" {
  zone_id = "${data.terraform_remote_state.infra_networking.public_zone_id}"
  name    = "alerts-1"
  type    = "A"

  alias {
    name                   = "${aws_lb.monitoring_external_alb.dns_name}"
    zone_id                = "${aws_lb.monitoring_external_alb.zone_id}"
    evaluate_target_health = false
  }
}

resource "aws_lb_target_group" "monitoring_external_tg" {
  count = "${length(data.terraform_remote_state.infra_networking.public_subnets)}"

  name                 = "${var.stack_name}-ext-tg-${count.index + 1}"
  port                 = 80
  protocol             = "HTTP"
  vpc_id               = "${data.terraform_remote_state.infra_networking.vpc_id}"
  deregistration_delay = 30

  health_check {
    interval            = "10"
    path                = "/health" # static health check on nginx auth proxy
    matcher             = "200"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = "5"
  }
}

resource "aws_lb_listener" "monitoring_external_listener" {
  count = "${length(data.terraform_remote_state.infra_networking.public_subnets)}"

  load_balancer_arn = "${element(aws_lb.monitoring_external_alb.*.arn, count.index)}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${element(aws_lb_target_group.monitoring_external_tg.*.arn, count.index)}"
    type             = "forward"
  }
}

resource "aws_lb" "alertmanager_external_alb" {
  name               = "${var.stack_name}-alertmanager"
  internal           = true
  load_balancer_type = "application"
  security_groups    = ["${data.terraform_remote_state.infra_security_groups.alertmanager_external_sg_id}"]

  subnets = [
    "${element(data.terraform_remote_state.infra_networking.public_subnets, 0)}",
    "${element(data.terraform_remote_state.infra_networking.public_subnets, 1)}",
    "${element(data.terraform_remote_state.infra_networking.public_subnets, 2)}",
  ]

  tags = "${merge(
    local.default_tags,
    var.additional_tags,
    map("Stackname", "${var.stack_name}"),
    map("Name", "${var.stack_name}-alertmanager-external")
  )}"
}

resource "aws_lb_listener" "alertmanager_listener" {
  load_balancer_arn = "${aws_lb.alertmanager_external_alb.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_lb_target_group.alertmanager_endpoint.arn}"
    type             = "forward"
  }
}

resource "aws_lb_target_group" "alertmanager_endpoint" {
  name     = "${var.stack_name}-alertmanager"
  port     = "9093"
  protocol = "HTTP"
  vpc_id   = "${data.terraform_remote_state.infra_networking.vpc_id}"

  health_check {
    interval            = "10"
    path                = "/"
    matcher             = "200"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = "5"
  }
}

resource "aws_lb_listener" "paas_proxy_listener" {
  load_balancer_arn = "${aws_lb.alertmanager_external_alb.arn}"
  port              = "8080"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_lb_target_group.paas_proxy_endpoint.arn}"
    type             = "forward"
  }
}

resource "aws_lb_target_group" "paas_proxy_endpoint" {
  name     = "${var.stack_name}-paas-proxy"
  protocol = "HTTP"
  port     = "8080"
  vpc_id   = "${data.terraform_remote_state.infra_networking.vpc_id}"

  health_check {
    interval            = "10"
    path                = "/health"
    matcher             = "200"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = "5"
  }
}

## Outputs

output "monitoring_external_tg" {
  value       = "${aws_lb_target_group.monitoring_external_tg.*.arn}"
  description = "External Monitoring ALB target group"
}

output "prometheus_alb_dns" {
  value       = "${aws_lb.monitoring_external_alb.dns_name}"
  description = "External Monitoring ALB DNS name"
}

output "zone_id" {
  value       = "${aws_lb.monitoring_external_alb.zone_id}"
  description = "External Monitoring ALB hosted zone ID"
}

output "alertmanager_external_tg" {
  value       = "${aws_lb_target_group.alertmanager_endpoint.arn}"
  description = "External Alertmanager ALB target group"
}

output "alertmanager_alb_zoneid" {
  value       = "${aws_lb.alertmanager_external_alb.zone_id}"
  description = "External Alertmanager ALB zone id"
}

output "alertmanager_alb_dns" {
  value       = "${aws_lb.alertmanager_external_alb.dns_name}"
  description = "External Alertmanager ALB DNS name"
}

output "paas_proxy_alb_zoneid" {
  value       = "${aws_lb.alertmanager_external_alb.zone_id}"
  description = "Internal PaaS ALB target group"
}

output "paas_proxy_alb_dns" {
  value       = "${aws_lb.alertmanager_external_alb.dns_name}"
  description = "Internal PaaS ALB DNS name"
}

output "pass_proxy_tg" {
  value       = "${aws_lb_target_group.paas_proxy_endpoint.arn}"
  description = "Paas proxy target group"
}
