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
