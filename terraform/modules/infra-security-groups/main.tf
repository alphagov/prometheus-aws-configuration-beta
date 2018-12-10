/**
* ## module: infra-security-groups
*
* Central module to manage all security groups.
*
* This is done in a single module to reduce conflicts
* and cascade issues.
*
*/

variable "additional_tags" {
  type        = "map"
  description = "Stack specific tags to apply"
  default     = {}
}

variable "aws_region" {
  type        = "string"
  description = "The AWS region to use."
}

variable "remote_state_bucket" {
  type        = "string"
  description = "S3 bucket we store our terraform state in"
}

variable "stack_name" {
  type        = "string"
  description = "Unique name for this collection of resources"
}

variable "project" {
  type        = "string"
  description = "Which project, in which environment, we're running"
}

# locals
# --------------------------------------------------------------

locals {
  default_tags = {
    Terraform = "true"
    Project   = "${var.project}"
  }
}

# Resources
# --------------------------------------------------------------

## Data sources

data "terraform_remote_state" "infra_networking" {
  backend = "s3"

  config {
    bucket = "${var.remote_state_bucket}"
    key    = "infra-networking-modular.tfstate"
    region = "${var.aws_region}"
  }
}

## Resources

### External SG

resource "aws_security_group" "monitoring_external_sg" {
  name        = "${var.stack_name}-monitoring-external-sg"
  vpc_id      = "${data.terraform_remote_state.infra_networking.vpc_id}"
  description = "Controls external access to the LBs"

  tags = "${merge(
    local.default_tags,
    var.additional_tags,
    map("Stackname", "${var.stack_name}"),
    map("Name", "${var.stack_name}-monitoring-external-sg")
  )}"
}

resource "aws_security_group" "alertmanager_external_sg" {
  name        = "${var.stack_name}-alert-external-sg"
  vpc_id      = "${data.terraform_remote_state.infra_networking.vpc_id}"
  description = "Controls external access to the LBs"

  tags = "${merge(
    local.default_tags,
    var.additional_tags,
    map("Stackname", "${var.stack_name}"),
    map("Name", "${var.stack_name}-monitoring-external-sg")
  )}"
}

resource "aws_security_group_rule" "alertmanager_internal_alb" {
  type                     = "ingress"
  to_port                  = 80
  from_port                = 80
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.alertmanager_external_sg.id}"
  source_security_group_id = "${aws_security_group.monitoring_internal_sg.id}"
}

resource "aws_security_group_rule" "monitoring_external_sg_ingress_any_http" {
  type              = "ingress"
  to_port           = 80
  from_port         = 80
  protocol          = "tcp"
  security_group_id = "${aws_security_group.monitoring_external_sg.id}"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "monitoring_external_sg_ingress_any_https" {
  type              = "ingress"
  to_port           = 443
  from_port         = 443
  protocol          = "tcp"
  security_group_id = "${aws_security_group.monitoring_external_sg.id}"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "allow_prometheus_access_alertmanager" {
  type              = "ingress"
  to_port           = 80
  from_port         = 80
  protocol          = "tcp"
  security_group_id = "${aws_security_group.alertmanager_external_sg.id}"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "alertmanager_external_sg_egress_any_any" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.alertmanager_external_sg.id}"
}

resource "aws_security_group_rule" "monitoring_external_sg_egress_any_any" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.monitoring_external_sg.id}"
}

### Internal SG

resource "aws_security_group" "monitoring_internal_sg" {
  name        = "${var.stack_name}-monitoring-internal-sg"
  vpc_id      = "${data.terraform_remote_state.infra_networking.vpc_id}"
  description = "Controls access to the ECS container instance from the LBs"

  tags = "${merge(
    local.default_tags,
    var.additional_tags,
    map("Stackname", "${var.stack_name}"),
    map("Name", "${var.stack_name}-monitoring-internal-sg")
  )}"
}

resource "aws_security_group_rule" "monitoring_internal_sg_ingress_alb_http" {
  type      = "ingress"
  from_port = 0
  to_port   = 0
  protocol  = "-1"

  security_group_id        = "${aws_security_group.monitoring_internal_sg.id}"
  source_security_group_id = "${aws_security_group.monitoring_external_sg.id}"
}

resource "aws_security_group_rule" "monitoring_internal_sg_alertmanager_alb" {
  type      = "ingress"
  from_port = 0
  to_port   = 0
  protocol  = "-1"

  security_group_id        = "${aws_security_group.monitoring_internal_sg.id}"
  source_security_group_id = "${aws_security_group.alertmanager_external_sg.id}"
}

resource "aws_security_group_rule" "monitoring_internal_sg_egress_any_any" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.monitoring_internal_sg.id}"
}

## Outputs

output "monitoring_external_sg_id" {
  value       = "${aws_security_group.monitoring_external_sg.id}"
  description = "monitoring_external_sg ID"
}

output "alertmanager_external_sg_id" {
  value       = "${aws_security_group.alertmanager_external_sg.id}"
  description = "alertmanager_external_sg ID"
}

output "monitoring_internal_sg_id" {
  value       = "${aws_security_group.monitoring_internal_sg.id}"
  description = "monitoring_internal_sg ID"
}
