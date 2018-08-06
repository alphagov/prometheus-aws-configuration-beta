/**
* ECS service that runs alertmanager
*
* This service consists of two containers.  The first, `s3-config-grabber`, fetches alertmanager configuration from our config S3 bucket, and stores it on a shared volume.  Then `alertmanager` runs and consumes that config.
*
* There is a known race condition between the two tasks - there is no guarantee that `s3-config-grabber` will grab the config before `alertmanager` starts.
*
*/

## IAM roles & policies

resource "aws_iam_role" "alertmanager_task_iam_role" {
  name = "${var.stack_name}-alertmanager-task"
  path = "/"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

data "aws_iam_policy_document" "alertmanager_policy_doc" {
  statement {
    sid = "GetAlertmanagerFiles"

    resources = ["arn:aws:s3:::${aws_s3_bucket.config_bucket.id}/alertmanager/*"]

    actions = [
      "s3:Get*",
    ]
  }

  statement {
    sid = "ListConfigBucket"

    resources = ["arn:aws:s3:::${aws_s3_bucket.config_bucket.id}"]

    actions = [
      "s3:List*",
    ]
  }
}

resource "aws_iam_policy" "alertmanager_task_policy" {
  name   = "${var.stack_name}-alertmanager-task-policy"
  path   = "/"
  policy = "${data.aws_iam_policy_document.alertmanager_policy_doc.json}"
}

resource "aws_iam_role_policy_attachment" "alertmanager_policy_attachment" {
  role       = "${aws_iam_role.alertmanager_task_iam_role.name}"
  policy_arn = "${aws_iam_policy.alertmanager_task_policy.arn}"
}

### container, task, service definitions

data "template_file" "alertmanager_container_defn" {
  template = "${file("task-definitions/alertmanager-server.json")}"

  vars {
    log_group     = "${aws_cloudwatch_log_group.task_logs.name}"
    region        = "${var.aws_region}"
    config_bucket = "${aws_s3_bucket.config_bucket.id}"
  }
}

resource "aws_ecs_task_definition" "alertmanager_server" {
  family                = "${var.stack_name}-alertmanager-server"
  container_definitions = "${data.template_file.alertmanager_container_defn.rendered}"
  task_role_arn         = "${aws_iam_role.alertmanager_task_iam_role.arn}"

  volume {
    name      = "config-from-s3"
    host_path = "/ecs/config-from-s3"
  }

  volume {
    name      = "alertmanager"
    host_path = "/ecs/config-from-s3/alertmanager"
  }
}

resource "aws_ecs_service" "alertmanager_server" {
  count = "${length(data.terraform_remote_state.app_ecs_instances.available_azs)}"

  name            = "${var.stack_name}-alertmanager-server-${count.index + 1}"
  cluster         = "${var.stack_name}-ecs-monitoring"
  task_definition = "${aws_ecs_task_definition.alertmanager_server.arn}"
  desired_count   = 1

  load_balancer {
    target_group_arn = "${element(data.terraform_remote_state.app_ecs_albs.monitoring_internal_tg, count.index)}"
    container_name   = "alertmanager"
    container_port   = 9093
  }

  placement_constraints {
    type       = "memberOf"
    expression = "attribute:ecs.availability-zone == ${data.terraform_remote_state.app_ecs_instances.available_azs[count.index]}"
  }
}

#### alertmanager

data "pass_password" "pagerduty_service_key" {
  path = "pagerduty/integration-keys/production"
}

data "template_file" "alertmanager_config_file" {
  template = "${file("templates/alertmanager.tpl")}"

  vars {
    pagerduty_service_key  = "${data.pass_password.pagerduty_service_key.password}"
    smtp_from              = "alerts@${data.terraform_remote_state.infra_networking.public_subdomain}"

    # Port as requested by https://docs.aws.amazon.com/ses/latest/DeveloperGuide/smtp-connect.html
    smtp_smarthost         = "email-smtp.${var.aws_region}.amazonaws.com:587"
    smtp_username          = "${aws_iam_access_key.smtp.id}"
    smtp_password          = "${aws_iam_access_key.smtp.ses_smtp_password}"
    ticket_recipient_email = "${var.ticket_recipient_email}"
  }
}

data "template_file" "alertmanager_dev_config_file" {
  template = "${file("templates/alertmanager-dev.tpl")}"

  # For dev stacks, as we have not requested "AWS SES production access", by default
  # emails will not be sent unless you verify the recipient's email address
  # (e.g. your personal email for testing).
  # https://docs.aws.amazon.com/ses/latest/DeveloperGuide/verify-email-addresses-procedure.html
  vars {
    smtp_from              = "alerts@${data.terraform_remote_state.infra_networking.public_subdomain}"

    # Port as requested by https://docs.aws.amazon.com/ses/latest/DeveloperGuide/smtp-connect.html
    smtp_smarthost         = "email-smtp.${var.aws_region}.amazonaws.com:587"
    smtp_username          = "${aws_iam_access_key.smtp.id}"
    smtp_password          = "${aws_iam_access_key.smtp.ses_smtp_password}"
    ticket_recipient_email = "${var.ticket_recipient_email}"
  }
}

resource "aws_s3_bucket_object" "alertmanager" {
  bucket  = "${aws_s3_bucket.config_bucket.id}"
  key     = "alertmanager/alertmanager.yml"
  content = "${var.dev_environment == "true" ? data.template_file.alertmanager_dev_config_file.rendered : data.template_file.alertmanager_config_file.rendered}"
  etag    = "${md5(var.dev_environment == "true" ? data.template_file.alertmanager_dev_config_file.rendered : data.template_file.alertmanager_config_file.rendered)}"
}

## AWS SES

resource "aws_ses_domain_identity" "main" {
  domain = "${data.terraform_remote_state.infra_networking.public_subdomain}"
}

resource "aws_route53_record" "txt_amazonses_verification_record" {
  zone_id = "${data.terraform_remote_state.infra_networking.public_zone_id}"
  name    = "_amazonses.${data.terraform_remote_state.infra_networking.public_subdomain}"
  type    = "TXT"
  ttl     = "600"
  records = ["${aws_ses_domain_identity.main.verification_token}"]
}

resource "aws_ses_domain_dkim" "main" {
  domain = "${aws_ses_domain_identity.main.domain}"
}

resource "aws_route53_record" "dkim_amazonses_verification_record" {
  count   = 3
  zone_id = "${data.terraform_remote_state.infra_networking.public_zone_id}"
  name    = "${element(aws_ses_domain_dkim.main.dkim_tokens, count.index)}._domainkey.${data.terraform_remote_state.infra_networking.public_subdomain}"
  type    = "CNAME"
  ttl     = "600"
  records = ["${element(aws_ses_domain_dkim.main.dkim_tokens, count.index)}.dkim.amazonses.com"]
}

resource "aws_ses_domain_mail_from" "alerts" {
  domain           = "${aws_ses_domain_identity.main.domain}"
  mail_from_domain = "mail.${aws_ses_domain_identity.main.domain}"
}

resource "aws_route53_record" "alerts_ses_domain_mail_from_mx" {
  zone_id = "${data.terraform_remote_state.infra_networking.public_zone_id}"
  name    = "${aws_ses_domain_mail_from.alerts.mail_from_domain}"
  type    = "MX"
  ttl     = "600"
  records = ["10 feedback-smtp.${var.aws_region}.amazonses.com"]
}

resource "aws_route53_record" "alerts_ses_domain_mail_from_txt" {
  zone_id = "${data.terraform_remote_state.infra_networking.public_zone_id}"
  name    = "${aws_ses_domain_mail_from.alerts.mail_from_domain}"
  type    = "TXT"
  ttl     = "600"
  records = ["v=spf1 include:amazonses.com -all"]
}

# IAM for SMTP

resource "aws_iam_user" "smtp" {
  name = "${var.stack_name}.smtp"
  path = "/system/"
}

resource "aws_iam_access_key" "smtp" {
  user = "${aws_iam_user.smtp.name}"
}

resource "aws_iam_user_policy" "smtp_ro" {
  name = "${var.stack_name}.smtp"
  user = "${aws_iam_user.smtp.name}"

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
