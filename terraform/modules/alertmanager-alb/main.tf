/**
* ## Module: alertmanager-alb
*
* Creates an ALB for alertmanager
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
}

variable "stack_name" {
  type        = "string"
  description = "Unique name for this collection of resources"
}

variable "subnets" {
  type        = "list"
  description = "List of subnet ids to attach to the ALB"
}

variable "alerts_fqdns" {
  type        = "list"
  description = "Fully-qualified domain names that should be created in DNS and ACM for alertmanager"
}

variable "zone_id" {
  type        = "string"
  description = "route 53 zone id that alerts-* records should be created in"
}

variable "vpc_id" {
  type        = "string"
  description = "VPC id to create ALB in"
}

variable "target_groups" {
  type        = "list"
  description = "target group ids that alertmanager instances will be registered into."
}

variable "allowed_cidrs" {
  type        = "list"
  description = "List of CIDRs which are able to access the prometheus instance, default are GDS ips"

  default = [
    "213.86.153.212/32",
    "213.86.153.213/32",
    "213.86.153.214/32",
    "213.86.153.235/32",
    "213.86.153.236/32",
    "213.86.153.237/32",
    "85.133.67.244/32",
  ]
}

# locals
# --------------------------------------------------------------

locals {
  default_tags = {
    Terraform = "true"
  }
}

# AWS should manage the certificate renewal automatically
# https://docs.aws.amazon.com/acm/latest/userguide/managed-renewal.html
# If this fails, AWS will email associated with the AWS account
resource "aws_acm_certificate" "alerts_cert" {
  domain_name               = "${var.alerts_fqdns[0]}"
  validation_method         = "DNS"
  subject_alternative_names = ["${var.alerts_fqdns}"]
}

resource "aws_route53_record" "alerts_cert_validation" {
  # Count matches the domain name plus each `subject_alternative_domain`
  count = "${length(var.alerts_fqdns)}"

  zone_id    = "${var.zone_id}"
  name       = "${lookup(aws_acm_certificate.alerts_cert.domain_validation_options[count.index], "resource_record_name")}"
  type       = "${lookup(aws_acm_certificate.alerts_cert.domain_validation_options[count.index], "resource_record_type")}"
  records    = ["${lookup(aws_acm_certificate.alerts_cert.domain_validation_options[count.index], "resource_record_value")}"]
  ttl        = 60
  depends_on = ["aws_acm_certificate.alerts_cert"]
}

resource "aws_acm_certificate_validation" "alerts_cert" {
  certificate_arn         = "${aws_acm_certificate.alerts_cert.arn}"
  validation_record_fqdns = ["${aws_route53_record.alerts_cert_validation.*.fqdn}"]
}

resource "aws_security_group" "alertmanager_alb" {
  name        = "${var.stack_name}-alertmanager-alb"
  vpc_id      = "${var.vpc_id}"
  description = "Controls external access to alertmanager ALB"

  tags = "${merge(
    local.default_tags,
    var.additional_tags,
    map("Stackname", "${var.stack_name}"),
    map("Name", "${var.stack_name}-monitoring-external-sg")
  )}"
}

resource "aws_security_group_rule" "allow_http" {
  security_group_id = "${aws_security_group.alertmanager_alb.id}"
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["${var.allowed_cidrs}"]
}

resource "aws_security_group_rule" "allow_https" {
  security_group_id = "${aws_security_group.alertmanager_alb.id}"
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["${var.allowed_cidrs}"]
}

resource "aws_lb" "alertmanager_alb" {
  name               = "${var.stack_name}-alertmanager-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["${aws_security_group.alertmanager_alb.id}"]

  subnets = ["${var.subnets}"]

  tags = "${merge(
    local.default_tags,
    var.additional_tags,
    map("Stackname", "${var.stack_name}"),
    map("Name", "${var.stack_name}-alertmanager-alb")
  )}"
}

resource "aws_lb_listener" "alertmanager_listener_http" {
  load_balancer_arn = "${aws_lb.alertmanager_alb.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "alertmanager_listener_https" {
  load_balancer_arn = "${aws_lb.alertmanager_alb.arn}"
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = "${aws_acm_certificate.alerts_cert.arn}"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Not found"
      status_code  = "404"
    }
  }
}

resource "aws_lb_listener_rule" "alerts_listener_https" {
  count = "${length(var.target_groups)}"

  listener_arn = "${aws_lb_listener.alertmanager_listener_https.arn}"
  priority     = "${100 + count.index}"

  action {
    type             = "forward"
    target_group_arn = "${element(var.target_groups, count.index)}"
  }

  condition {
    field = "host-header"

    values = [
      "alerts-${count.index + 1}.*",
    ]
  }
}

## Outputs

