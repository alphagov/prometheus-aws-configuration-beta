######################################################################
# ----- alertmanager public ALB -------
######################################################################
#
#
# The ALB serves one main purpose: so we can use ACM certs instead of
# managing our own.  We don't actually want it to load-balance; each
# public domain name associated with alertmanager should route to
# exactly one internal alertmanager instance.  We achieve this by
# using listener rules, so that requests with a particular host:
# header must go to a particular AZ, and running one alertmanager per
# AZ.


resource "aws_lb" "alertmanager_alb" {
  name               = "${var.environment}-alertmanager-alb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [aws_security_group.alertmanager_alb.id]

  subnets = data.terraform_remote_state.infra_networking.outputs.public_subnets

  tags = merge(
    local.default_tags,
    {
      Name = "${var.environment}-alertmanager-alb"
    },
  )
}

resource "aws_lb_listener" "alertmanager_listener_alb_http" {
  load_balancer_arn = aws_lb.alertmanager_alb.arn
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

resource "aws_lb_listener" "alertmanager_listener_alb_https" {
  load_balancer_arn = aws_lb.alertmanager_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = aws_acm_certificate_validation.alertmanager_cert.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alertmanager_all.arn
  }
}

resource "aws_lb_listener_rule" "alertmanager_listener_rule_per_az" {
  for_each = toset(local.availability_zones)

  listener_arn = aws_lb_listener.alertmanager_listener_alb_https.arn

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alertmanager_per_az[each.key].arn
  }

  condition {
    host_header {
      values = ["alerts-${each.key}.*"]
    }
  }
}

resource "aws_lb_target_group" "alertmanager_per_az" {
  for_each             = toset(local.availability_zones)
  name                 = "${var.environment}-alerts-${each.key}"
  port                 = 9093
  protocol             = "HTTP"
  vpc_id               = local.vpc_id
  deregistration_delay = 30
  target_type          = "ip"

  health_check {
    interval            = 10
    path                = "/"
    matcher             = "200"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = "5"
  }

  tags = merge(
    local.default_tags,
    {
      Name = "${var.environment}-alertmanager-${each.key}"
    },
  )
}

resource "aws_lb_target_group" "alertmanager_all" {
  name                 = "${var.environment}-alerts-all"
  port                 = 9093
  protocol             = "HTTP"
  vpc_id               = local.vpc_id
  deregistration_delay = 30
  target_type          = "ip"

  health_check {
    interval            = 10
    path                = "/"
    matcher             = "200"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = "5"
  }

  tags = merge(
    local.default_tags,
    {
      Name = "${var.environment}-alertmanager-all"
    },
  )
}

resource "aws_route53_record" "alerts_alias" {
  zone_id = local.zone_id
  name    = "alerts"
  type    = "A"

  alias {
    name                   = aws_lb.alertmanager_alb.dns_name
    zone_id                = aws_lb.alertmanager_alb.zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "alerts_az_alias" {
  for_each = toset(local.availability_zones)

  zone_id = local.zone_id
  name    = "alerts-${each.key}"
  type    = "A"

  alias {
    name                   = aws_lb.alertmanager_alb.dns_name
    zone_id                = aws_lb.alertmanager_alb.zone_id
    evaluate_target_health = false
  }
}
