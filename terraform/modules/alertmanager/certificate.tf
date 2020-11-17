# AWS should manage the certificate renewal automatically
# https://docs.aws.amazon.com/acm/latest/userguide/managed-renewal.html
# If this fails, AWS will email associated with the AWS account
resource "aws_acm_certificate" "alertmanager_cert" {
  domain_name       = "alerts.${data.terraform_remote_state.infra_networking.outputs.public_subdomain}"
  validation_method = "DNS"

  subject_alternative_names = formatlist("alerts-%s.${data.terraform_remote_state.infra_networking.outputs.public_subdomain}", data.aws_availability_zones.available.names)

  lifecycle {
    # We can't destroy a certificate that's in use, and we can't stop
    # using it until the new one is ready.  Hence
    # create_before_destroy here.
    create_before_destroy = true
  }
}

resource "aws_route53_record" "alertmanager_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.alertmanager_cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  name    = each.value.name
  records = [each.value.record]
  type    = each.value.type
  zone_id = local.zone_id
  ttl     = 60

  allow_overwrite = true

  depends_on = [aws_acm_certificate.alertmanager_cert]
}

resource "aws_acm_certificate_validation" "alertmanager_cert" {
  certificate_arn         = aws_acm_certificate.alertmanager_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.alertmanager_cert_validation : record.fqdn]
}

