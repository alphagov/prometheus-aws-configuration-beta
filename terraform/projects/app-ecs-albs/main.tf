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
  name               = "${var.stack_name}-external-alb"
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
    map("Name", "${var.stack_name}-prometheus-external")
  )}"
}

resource "aws_lb" "monitoring_internal_alb" {
  name               = "${var.stack_name}-internal-alb"
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
    map("Name", "${var.stack_name}-monitoring-internal-${count.index + 1}")
  )}"
}

# AWS should manage the certificate renewal automatically
# https://docs.aws.amazon.com/acm/latest/userguide/managed-renewal.html
# If this fails, AWS will email associated with the AWS account
resource "aws_acm_certificate" "monitoring_cert" {
  domain_name               = "${data.terraform_remote_state.infra_networking.public_subdomain}"
  validation_method         = "DNS"
  subject_alternative_names = ["${aws_route53_record.prom_alias.*.fqdn}", "${aws_route53_record.alerts_alias.*.fqdn}"]
}

resource "aws_route53_record" "monitoring_cert_validation" {
  # Count matches the domain_name plus each `subject_alternative_domain`
  count = "${1 + length(concat(aws_route53_record.prom_alias.*.fqdn, aws_route53_record.alerts_alias.*.fqdn))}"

  name       = "${lookup(aws_acm_certificate.monitoring_cert.domain_validation_options[count.index], "resource_record_name")}"
  type       = "${lookup(aws_acm_certificate.monitoring_cert.domain_validation_options[count.index], "resource_record_type")}"
  zone_id    = "${data.terraform_remote_state.infra_networking.public_zone_id}"
  records    = ["${lookup(aws_acm_certificate.monitoring_cert.domain_validation_options[count.index], "resource_record_value")}"]
  ttl        = 60
  depends_on = ["aws_acm_certificate.monitoring_cert"]
}

resource "aws_acm_certificate_validation" "monitoring_cert" {
  certificate_arn         = "${aws_acm_certificate.monitoring_cert.arn}"
  validation_record_fqdns = ["${aws_route53_record.monitoring_cert_validation.*.fqdn}"]
}

resource "aws_route53_record" "prom_alias" {
  count = "${length(data.terraform_remote_state.infra_networking.public_subnets)}"

  zone_id = "${data.terraform_remote_state.infra_networking.public_zone_id}"
  name    = "prom-${count.index + 1}"
  type    = "A"

  alias {
    name                   = "${aws_lb.nginx_auth_external_alb.dns_name}"
    zone_id                = "${aws_lb.nginx_auth_external_alb.zone_id}"
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "alerts_alias" {
  count = "${length(data.terraform_remote_state.infra_networking.public_subnets)}"

  zone_id = "${data.terraform_remote_state.infra_networking.public_zone_id}"
  name    = "alerts-${count.index + 1}"
  type    = "A"

  alias {
    name                   = "${aws_lb.nginx_auth_external_alb.dns_name}"
    zone_id                = "${aws_lb.nginx_auth_external_alb.zone_id}"
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
  load_balancer_arn = "${aws_lb.nginx_auth_external_alb.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_lb_target_group.nginx_auth_external_endpoint.0.arn}"
    type             = "forward"
  }
}

resource "aws_lb_listener" "nginx_auth_external_listener_https" {
  load_balancer_arn = "${aws_lb.nginx_auth_external_alb.arn}"
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "${aws_acm_certificate.monitoring_cert.arn}"

  default_action {
    target_group_arn = "${aws_lb_target_group.nginx_auth_external_endpoint.0.arn}"
    type             = "forward"
  }
}

resource "aws_lb_listener_rule" "prom_public_listener" {
  count = "${length(data.terraform_remote_state.infra_networking.public_subnets)}"

  listener_arn = "${aws_lb_listener.nginx_auth_external_listener.arn}"
  priority     = "${200 + count.index}"

  action {
    type             = "forward"
    target_group_arn = "${element(aws_lb_target_group.nginx_auth_external_endpoint.*.arn, count.index)}"
  }

  condition {
    field = "host-header"

    values = [
      "prom-${count.index + 1}.*",
    ]
  }
}

resource "aws_lb_listener_rule" "alerts_public_listener" {
  count = "${length(data.terraform_remote_state.infra_networking.public_subnets)}"

  listener_arn = "${aws_lb_listener.nginx_auth_external_listener.arn}"
  priority     = "${100 + count.index}"

  action {
    type             = "forward"
    target_group_arn = "${element(aws_lb_target_group.nginx_auth_external_endpoint.*.arn, count.index)}"
  }

  condition {
    field = "host-header"

    values = [
      "alerts-${count.index + 1}.*",
    ]
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
  load_balancer_arn = "${aws_lb.monitoring_internal_alb.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_lb_target_group.alertmanager_internal_endpoint.0.arn}"
    type             = "forward"
  }
}

resource "aws_lb_listener_rule" "alerts_private_listener" {
  count = "${length(data.terraform_remote_state.infra_networking.private_subnets)}"

  listener_arn = "${aws_lb_listener.alertmanager_internal_listener.arn}"
  priority     = "${100 + count.index}"

  action {
    type             = "forward"
    target_group_arn = "${element(aws_lb_target_group.alertmanager_internal_endpoint.*.arn, count.index)}"
  }

  condition {
    field = "host-header"

    values = [
      "alerts-${count.index + 1}.*",
    ]
  }
}

resource "aws_lb_target_group" "paas_proxy_internal_endpoint" {
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

resource "aws_lb_listener" "paas_proxy_internal_listener" {
  load_balancer_arn = "${aws_lb.monitoring_internal_alb.arn}"
  port              = "8080"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_lb_target_group.paas_proxy_internal_endpoint.arn}"
    type             = "forward"
  }
}

resource "aws_route53_record" "alerts_private_record" {
  count = "${length(data.terraform_remote_state.infra_networking.private_subnets)}"

  zone_id = "${data.terraform_remote_state.infra_networking.private_zone_id}"
  name    = "alerts-${count.index + 1}"
  type    = "A"

  alias {
    name                   = "${aws_lb.monitoring_internal_alb.dns_name}"
    zone_id                = "${aws_lb.monitoring_internal_alb.zone_id}"
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "paas_proxy_private_record" {
  zone_id = "${data.terraform_remote_state.infra_networking.private_zone_id}"
  name    = "paas-proxy"
  type    = "A"

  alias {
    name                   = "${aws_lb.monitoring_internal_alb.dns_name}"
    zone_id                = "${aws_lb.monitoring_internal_alb.zone_id}"
    evaluate_target_health = false
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

output "paas_proxy_tg" {
  value       = "${aws_lb_target_group.paas_proxy_internal_endpoint.arn}"
  description = "Paas proxy target group"
}

output "alerts_private_record_fqdn" {
  value       = "${aws_route53_record.alerts_private_record.*.fqdn}"
  description = "Alert Managers private DNS fqdn"
}

output "paas_proxy_private_record_fqdn" {
  value       = "${aws_route53_record.paas_proxy_private_record.*.fqdn}"
  description = "PaaS Proxy private DNS fqdn"
}
