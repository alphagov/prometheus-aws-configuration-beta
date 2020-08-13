resource "aws_security_group" "alertmanager_alb" {
  name        = "${var.environment}-alertmanager-alb"
  vpc_id      = local.vpc_id
  description = "Alertmanager ALB"

  tags = merge(
    local.default_tags,
    {
      Name = "alertmanager-alb",
    },
  )
}

resource "aws_security_group" "alertmanager_task" {
  name        = "${var.environment}-alertmanager-task"
  vpc_id      = local.vpc_id
  description = "Controls ingress and egress for the alertmanager task"

  tags = merge(
    local.default_tags,
    {
      Name = "alertmanager-task",
    },
  )
}

# Alertmanager is behind an NLB, so it needs to allow ingress from the
# allowed public internet cidrs directly
resource "aws_security_group_rule" "ingress_from_allowed_cidrs_to_alertmanager_9093" {
  security_group_id = aws_security_group.alertmanager_task.id
  type              = "ingress"
  from_port         = 9093
  to_port           = 9093
  protocol          = "tcp"
  cidr_blocks       = var.allowed_cidrs
}

# Alertmanager ALB needs to allow ingress from the allowed public
# internet cidrs
resource "aws_security_group_rule" "ingress_from_allowed_cidrs_to_alertmanager_alb_http" {
  security_group_id = aws_security_group.alertmanager_alb.id
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = var.allowed_cidrs
}

resource "aws_security_group_rule" "ingress_from_allowed_cidrs_to_alertmanager_alb_https" {
  security_group_id = aws_security_group.alertmanager_alb.id
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = var.allowed_cidrs
}

# NLB health checks come from the public subnet IP range
resource "aws_security_group_rule" "ingress_from_public_subnets_to_alertmanager_9093" {
  security_group_id = aws_security_group.alertmanager_task.id
  type              = "ingress"
  from_port         = 9093
  to_port           = 9093
  protocol          = "tcp"
  cidr_blocks       = data.aws_subnet.public_subnets.*.cidr_block
}

resource "aws_security_group_rule" "ingress_from_alertmanager_alb_to_alertmanager_9093" {
  security_group_id        = aws_security_group.alertmanager_task.id
  source_security_group_id = aws_security_group.alertmanager_alb.id
  type                     = "ingress"
  from_port                = 9093
  to_port                  = 9093
  protocol                 = "tcp"
}

resource "aws_security_group_rule" "egress_from_alertmanager_alb_to_alertmanager_9093" {
  security_group_id = aws_security_group.alertmanager_alb.id
  # source_security_group_id means destination for egress rules
  source_security_group_id = aws_security_group.alertmanager_task.id
  type                     = "egress"
  from_port                = 9093
  to_port                  = 9093
  protocol                 = "tcp"
}

# TODO: could we make observe prometheus more consistent with external
# prometheis and go via public NLB IPs?
resource "aws_security_group_rule" "ingress_from_prometheus_ec2_to_alertmanager_task" {
  security_group_id        = aws_security_group.alertmanager_task.id
  type                     = "ingress"
  from_port                = 9093
  to_port                  = 9093
  protocol                 = "tcp"
  source_security_group_id = data.terraform_remote_state.infra_security_groups.outputs.prometheus_ec2_sg_id
}


resource "aws_security_group_rule" "ingress_alertmanager_task_meshing" {
  security_group_id        = aws_security_group.alertmanager_task.id
  type                     = "ingress"
  from_port                = 9094
  to_port                  = 9094
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alertmanager_task.id
}

# This rule allows all egress out of alertmanager_task. This is for the following purposes:
# - raising alerts with receivers such as pagerduty and cronitor
# - sending emails via AWS API
# - communicate with other alertmanagers to mesh
resource "aws_security_group_rule" "egress_from_alertmanager_task_to_all" {
  security_group_id = aws_security_group.alertmanager_task.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}
