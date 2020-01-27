######################################################################
# ----- alertmanager public NLB -------
######################################################################
#
#
# The NLB serves one main purpose: so we can use ACM certs instead of
# managing our own.  We don't actually want it to load-balance; each
# public IP of the NLB should route to exactly one internal
# alertmanager instance.  We achieve this by disabling cross-AZ load
# balancing, so that requests must stay in the same AZ, and running
# one alertmanager per AZ.
#


# AWS should manage the certificate renewal automatically
# https://docs.aws.amazon.com/acm/latest/userguide/managed-renewal.html
# If this fails, AWS will email associated with the AWS account
resource "aws_acm_certificate" "alertmanager_cert" {
  domain_name       = "alerts.${local.subdomain}"
  validation_method = "DNS"

  lifecycle {
    # We can't destroy a certificate that's in use, and we can't stop
    # using it until the new one is ready.  Hence
    # create_before_destroy here.
    create_before_destroy = true
  }
}

resource "aws_route53_record" "alertmanager_cert_validation" {
  name       = aws_acm_certificate.alertmanager_cert.domain_validation_options[0]["resource_record_name"]
  type       = aws_acm_certificate.alertmanager_cert.domain_validation_options[0]["resource_record_type"]
  zone_id    = local.zone_id
  records    = [aws_acm_certificate.alertmanager_cert.domain_validation_options[0]["resource_record_value"]]
  ttl        = 60
  depends_on = [aws_acm_certificate.alertmanager_cert]
}

resource "aws_acm_certificate_validation" "alertmanager_cert" {
  certificate_arn         = aws_acm_certificate.alertmanager_cert.arn
  validation_record_fqdns = aws_route53_record.alertmanager_cert_validation.*.fqdn
}

resource "aws_route53_record" "alerts_alias" {
  zone_id = local.zone_id
  name    = "alerts"
  type    = "A"

  alias {
    name                   = aws_lb.alertmanager_nlb.dns_name
    zone_id                = aws_lb.alertmanager_nlb.zone_id
    evaluate_target_health = false
  }
}

resource "aws_lb" "alertmanager_nlb" {
  name               = "${var.environment}-alertmanager-nlb"
  internal           = false
  load_balancer_type = "network"

  subnets = data.terraform_remote_state.infra_networking.outputs.public_subnets

  # We definitely do not want cross-zone load balancing; we want each
  # public IP to map to the alertmanager in that same AZ, so that
  # prometheus can send alerts to each alertmanager independently.
  #
  # false is the default value here but it's worth being explicit
  enable_cross_zone_load_balancing = false

  tags = merge(
    local.default_tags,
    {
      Name    = "${var.environment}-alertmanager-nlb"
      Service = "alertmanager"
    },
  )
}

resource "aws_lb_listener" "alertmanager_listener_https" {
  load_balancer_arn = aws_lb.alertmanager_nlb.arn
  port              = 443
  protocol          = "TLS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = aws_acm_certificate_validation.alertmanager_cert.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alertmanager.arn
  }
}

resource "aws_lb_target_group" "alertmanager" {
  name                 = "${var.environment}-alertmanager"
  port                 = 9093
  protocol             = "TCP"
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
    timeout             = 5
  }
}

