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
  name               = "${var.stack_name}-ext-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["${data.terraform_remote_state.infra_security_groups.monitoring_external_sg_id}"]

  subnets = [
    "${element(data.terraform_remote_state.infra_networking.public_subnets, 0)}",
    "${element(data.terraform_remote_state.infra_networking.public_subnets, 1)}",
  ]

  tags = "${merge(
    local.default_tags,
    var.additional_tags,
    map("Stackname", "${var.stack_name}"),
    map("Name", "${var.stack_name}-ecs-monitoring")
  )}"
}

resource "aws_lb_target_group" "monitoring_external_tg" {
  name     = "${var.stack_name}-ext-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${data.terraform_remote_state.infra_networking.vpc_id}"

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
  load_balancer_arn = "${aws_lb.monitoring_external_alb.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_lb_target_group.monitoring_external_tg.arn}"
    type             = "forward"
  }
}


resource "aws_lb_listener" "alertmanager_listener" {
  load_balancer_arn = "${aws_lb.monitoring_external_alb.arn}"
  port              = "8080"
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
    path                = "/" # static health check on nginx auth proxy
    matcher             = "200"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = "5"
  }
}


## Outputs

output "monitoring_external_tg" {
  value       = "${aws_lb_target_group.monitoring_external_tg.arn}"
  description = "External Monitoring ALB target group"
}


output "alertmanager_external_tg" {
  value       = "${aws_lb_target_group.alertmanager_endpoint.arn}"
  description = "External Alertmanager ALB target group"
}