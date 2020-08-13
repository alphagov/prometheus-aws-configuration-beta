/**
* ECS service that runs alertmanager
*
*/

### container, task, service definitions

resource "aws_ecs_cluster" "prometheus_cluster" {
  name = "${var.environment}-ecs-monitoring"

  tags = merge(local.default_tags, {
    Name = "${var.environment}-alertmanager"
  })
}

resource "aws_iam_role" "execution" {
  name = "${var.environment}-alertmanager-execution"

  assume_role_policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "ecs-tasks.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }
    ]
  }
EOF

  tags = merge(local.default_tags, {
    Name = "${var.environment}-alertmanager-execution"
  })
}

resource "aws_iam_policy" "execution" {
  name = "${var.environment}-alertmanager-execution"

  policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        "Resource": "*"
      }
    ]
  }
EOF

}

resource "aws_iam_role_policy_attachment" "execution_execution" {
  role       = aws_iam_role.execution.name
  policy_arn = aws_iam_policy.execution.arn
}

data "template_file" "alertmanager_nlb_container_defn" {
  template = file("${path.module}/task-definitions/alertmanager.json")

  vars = {
    alertmanager_config_base64 = base64encode(data.template_file.alertmanager_config_file.rendered)
    templates_base64           = base64encode(file("${path.module}/templates/default.tmpl"))
    alertmanager_url           = "--web.external-url=https://${aws_route53_record.alerts_alias.fqdn}"
    log_group                  = aws_cloudwatch_log_group.task_logs.name
    region                     = var.aws_region
  }
}

resource "aws_ecs_task_definition" "alertmanager_nlb" {
  family                   = "${var.environment}-alertmanager"
  container_definitions    = data.template_file.alertmanager_nlb_container_defn.rendered
  network_mode             = "awsvpc"
  execution_role_arn       = aws_iam_role.execution.arn
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512

  tags = merge(local.default_tags, {
    Name = "${var.environment}-alertmanager"
  })
}

resource "aws_ecs_service" "alertmanager_nlb" {
  count           = length(data.aws_subnet.private_subnets)
  name            = "${var.environment}-alertmanager-${data.aws_subnet.private_subnets[count.index].availability_zone}"
  cluster         = "${var.environment}-ecs-monitoring"
  task_definition = aws_ecs_task_definition.alertmanager_nlb.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  load_balancer {
    target_group_arn = aws_lb_target_group.alertmanager.arn
    container_name   = "alertmanager"
    container_port   = 9093
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.alertmanager_per_subnet[count.index].arn
    container_name   = "alertmanager"
    container_port   = 9093
  }

  network_configuration {
    subnets         = [data.aws_subnet.private_subnets[count.index].id]
    security_groups = [aws_security_group.alertmanager_task.id]
  }

  service_registries {
    registry_arn = aws_service_discovery_service.alertmanager.arn
  }
}

#### alertmanager

data "pass_password" "observe_pagerduty_key" {
  path = "pagerduty/integration-keys/production"
}

data "pass_password" "dgu_pagerduty_key" {
  path = "pagerduty/integration-keys/dgu"
}

data "pass_password" "govuk_pagerduty_key" {
  path = "pagerduty/integration-keys/govuk"
}

data "pass_password" "verify_p1_pagerduty_key" {
  path = "pagerduty/integration-keys/verify-p1"
}

data "pass_password" "verify_p2_pagerduty_key" {
  path = "pagerduty/integration-keys/verify-p2"
}

data "pass_password" "dcs_p2_pagerduty_key" {
  path = "pagerduty/integration-keys/dcs-p2"
}

data "pass_password" "slack_api_url" {
  path = "slack-api-url"
}

data "pass_password" "registers_zendesk" {
  path = "receivers/registers/zendesk"
}

data "pass_password" "observe_zendesk" {
  path = "receivers/observe/zendesk"
}

data "pass_password" "verify_gsp_cronitor" {
  path = "cronitor/verify-gsp-url"
}

data "pass_password" "verify_joint_cronitor" {
  path = "cronitor/verify-joint-url"
}

data "pass_password" "verify_staging_cronitor" {
  path = "cronitor/verify-staging-url"
}

data "pass_password" "verify_integration_cronitor" {
  path = "cronitor/verify-integration-url"
}

data "pass_password" "verify_prod_cronitor" {
  path = "cronitor/verify-prod-url"
}

data "template_file" "alertmanager_config_file" {
  template = file("${path.module}/templates/alertmanager.tpl")

  vars = {
    observe_pagerduty_key   = data.pass_password.observe_pagerduty_key.password
    dgu_pagerduty_key       = data.pass_password.dgu_pagerduty_key.password
    govuk_pagerduty_key     = data.pass_password.govuk_pagerduty_key.password
    verify_p1_pagerduty_key = data.pass_password.verify_p1_pagerduty_key.password
    verify_p2_pagerduty_key = data.pass_password.verify_p2_pagerduty_key.password
    dcs_p2_pagerduty_key    = data.pass_password.dcs_p2_pagerduty_key.password
    slack_api_url           = data.pass_password.slack_api_url.password
    registers_zendesk       = data.pass_password.registers_zendesk.password
    smtp_from               = "alerts@${data.terraform_remote_state.infra_networking.outputs.public_subdomain}"
    # Port as requested by https://docs.aws.amazon.com/ses/latest/DeveloperGuide/smtp-connect.html
    smtp_smarthost              = "email-smtp.${var.aws_region}.amazonaws.com:587"
    smtp_username               = aws_iam_access_key.smtp.id
    smtp_password               = aws_iam_access_key.smtp.ses_smtp_password
    ticket_recipient_email      = data.pass_password.observe_zendesk.password
    observe_cronitor            = var.observe_cronitor
    verify_gsp_cronitor         = data.pass_password.verify_gsp_cronitor.password
    verify_joint_cronitor       = data.pass_password.verify_joint_cronitor.password
    verify_staging_cronitor     = data.pass_password.verify_staging_cronitor.password
    verify_integration_cronitor = data.pass_password.verify_integration_cronitor.password
    verify_prod_cronitor        = data.pass_password.verify_prod_cronitor.password
  }
}

## AWS SES

resource "aws_ses_domain_identity" "main" {
  domain = data.terraform_remote_state.infra_networking.outputs.public_subdomain
}

resource "aws_route53_record" "txt_amazonses_verification_record" {
  zone_id = data.terraform_remote_state.infra_networking.outputs.public_zone_id
  name    = "_amazonses.${data.terraform_remote_state.infra_networking.outputs.public_subdomain}"
  type    = "TXT"
  ttl     = "600"
  records = [aws_ses_domain_identity.main.verification_token]
}

resource "aws_ses_domain_dkim" "main" {
  domain = aws_ses_domain_identity.main.domain
}

resource "aws_route53_record" "dkim_amazonses_verification_record" {
  count   = 3
  zone_id = data.terraform_remote_state.infra_networking.outputs.public_zone_id
  name    = "${element(aws_ses_domain_dkim.main.dkim_tokens, count.index)}._domainkey.${data.terraform_remote_state.infra_networking.outputs.public_subdomain}"
  type    = "CNAME"
  ttl     = "600"
  records = ["${element(aws_ses_domain_dkim.main.dkim_tokens, count.index)}.dkim.amazonses.com"]
}

resource "aws_ses_domain_mail_from" "alerts" {
  domain           = aws_ses_domain_identity.main.domain
  mail_from_domain = "mail.${aws_ses_domain_identity.main.domain}"
}

resource "aws_route53_record" "alerts_ses_domain_mail_from_mx" {
  zone_id = data.terraform_remote_state.infra_networking.outputs.public_zone_id
  name    = aws_ses_domain_mail_from.alerts.mail_from_domain
  type    = "MX"
  ttl     = "600"
  records = ["10 feedback-smtp.${var.aws_region}.amazonses.com"]
}

resource "aws_route53_record" "alerts_ses_domain_mail_from_txt" {
  zone_id = data.terraform_remote_state.infra_networking.outputs.public_zone_id
  name    = aws_ses_domain_mail_from.alerts.mail_from_domain
  type    = "TXT"
  ttl     = "600"
  records = ["v=spf1 include:amazonses.com -all"]
}

# IAM for SMTP

resource "aws_iam_user" "smtp" {
  name = "${var.environment}.smtp"
  path = "/system/"

  tags = merge(local.default_tags, {
    Name = "${var.environment}-alertmanager-smtp"
  })
}

resource "aws_iam_access_key" "smtp" {
  user = aws_iam_user.smtp.name
}

resource "aws_iam_user_policy" "smtp_ro" {
  name = "${var.environment}.smtp"
  user = aws_iam_user.smtp.name

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "ses:SendRawEmail",
      "Resource": "*"
    }
  ]
}
EOF

}
