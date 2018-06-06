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

resource "aws_lb" "nginx_auth_external_alb" {
  count = "${length(data.terraform_remote_state.infra_networking.public_subnets)}"

  name               = "${var.stack_name}-external-alb-${count.index + 1}"
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

resource "aws_lb" "monitoring_internal_alb" {
  count = "${length(data.terraform_remote_state.infra_networking.private_subnets)}"
  
  name               = "${var.stack_name}-internal-alb-${count.index}"
  internal           = true
  load_balancer_type = "application"
  security_groups    = ["${data.terraform_remote_state.infra_security_groups.alertmanager_external_sg_id}"]

  subnets = [ 
    "${data.terraform_remote_state.infra_networking.private_subnets}",
  ]

  tags = "${merge(
    local.default_tags,
    var.additional_tags,
    map("Stackname", "${var.stack_name}"),
    map("Name", "${var.stack_name}-monitoring-internal-${count.index}")
  )}"
}

resource "aws_route53_record" "prom_alias" {
  count = "${length(data.terraform_remote_state.infra_networking.public_subnets)}"

  zone_id = "${data.terraform_remote_state.infra_networking.public_zone_id}"
  name    = "prom-${count.index + 1}"
  type    = "A"

  alias {
    name                   = "${element(aws_lb.nginx_auth_external_alb.*.dns_name, count.index)}"
    zone_id                = "${element(aws_lb.nginx_auth_external_alb.*.zone_id, count.index)}"
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "alerts_alias" {
  count = "${length(data.terraform_remote_state.infra_networking.public_subnets)}"
  
  zone_id = "${data.terraform_remote_state.infra_networking.public_zone_id}"
  name    = "alerts-${count.index + 1}"
  type    = "A"

  alias {
    name                   = "${element(aws_lb.nginx_auth_external_alb.*.dns_name, count.index)}"
    zone_id                = "${element(aws_lb.nginx_auth_external_alb.*.zone_id, count.index)}"
    evaluate_target_health = false
  }
}

resource "aws_lb_target_group" "nginx_auth_external_endpoint" {
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

resource "aws_lb_listener" "nginx_auth_external_listener" {
  count = "${length(data.terraform_remote_state.infra_networking.public_subnets)}"

  load_balancer_arn = "${element(aws_lb.nginx_auth_external_alb.*.arn, count.index)}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${element(aws_lb_target_group.nginx_auth_external_endpoint.*.arn, count.index)}"
    type             = "forward"
  }
}


resource "aws_lb_target_group" "alertmanager_internal_endpoint" {
  count = "${length(data.terraform_remote_state.infra_networking.public_subnets)}"

  name     = "${var.stack_name}-alerts-internal-${count.index + 1}"
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

resource "aws_lb_listener" "alertmanager_internal_listener" {
  count = "${length(data.terraform_remote_state.infra_networking.private_subnets)}"

  load_balancer_arn = "${element(aws_lb.monitoring_internal_alb.*.arn, count.index)}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${element(aws_lb_target_group.alertmanager_internal_endpoint.*.arn, count.index)}"
    type             = "forward"
  }
}

resource "aws_lb_target_group" "paas_proxy_internal_endpoint" {
  count = "${length(data.terraform_remote_state.infra_networking.private_subnets)}"

  name     = "${var.stack_name}-paas-proxy-${count.index}"
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

resource "aws_lb_listener" "paas_proxy_internal_listener" {
  count = "${length(data.terraform_remote_state.infra_networking.private_subnets)}"

  load_balancer_arn = "${element(aws_lb.monitoring_internal_alb.*.arn, count.index)}"
  port              = "8080"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${element(aws_lb_target_group.paas_proxy_internal_endpoint.*.arn, count.index)}"
    type             = "forward"
  }
}


## Outputs

output "monitoring_external_tg" {
  value       = "${aws_lb_target_group.nginx_auth_external_endpoint.*.arn}"
  description = "External Monitoring ALB target group"
}

output "prometheus_alb_dns" {
  value       = "${aws_lb.nginx_auth_external_alb.*.dns_name}"
  description = "External Monitoring ALB DNS name"
}

output "zone_id" {
  value       = "${aws_lb.nginx_auth_external_alb.*.zone_id}"
  description = "External Monitoring ALB hosted zone ID"
}

output "monitoring_internal_tg" {
  value       = "${aws_lb_target_group.alertmanager_internal_endpoint.*.arn}"
  description = "External Alertmanager ALB target group"
}

output "alertmanager_alb_zoneid" {
  value       = "${aws_lb.monitoring_internal_alb.*.zone_id}"
  description = "External Alertmanager ALB zone id"
}

output "alertmanager_alb_dns" {
  value       = "${aws_lb.monitoring_internal_alb.*.dns_name}"
  description = "External Alertmanager ALB DNS name"
}

output "paas_proxy_alb_zoneid" {
  value       = "${aws_lb.monitoring_internal_alb.*.zone_id}"
  description = "Internal PaaS ALB target group"
}

output "paas_proxy_alb_dns" {
  value       = "${aws_lb.monitoring_internal_alb.*.dns_name}"
  description = "Internal PaaS ALB DNS name"
}

output "pass_proxy_tg" {
  value       = "${aws_lb_target_group.paas_proxy_internal_endpoint.*.arn}"
  description = "Paas proxy target group"
}
