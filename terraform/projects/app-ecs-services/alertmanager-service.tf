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
  name            = "${var.stack_name}-alertmanager-server"
  cluster         = "${var.stack_name}-ecs-monitoring"
  task_definition = "${aws_ecs_task_definition.alertmanager_server.arn}"
  desired_count   = 1

  load_balancer {
    target_group_arn = "${data.terraform_remote_state.app_ecs_albs.alertmanager_external_tg}"
    container_name   = "alertmanager"
    container_port   = 9093
  }
}

#### alertmanager

resource "aws_s3_bucket_object" "alertmanager" {
  bucket = "${aws_s3_bucket.config_bucket.id}"
  key    = "alertmanager/alertmanager.yml"
  source = "config/alertmanager.yml"
  etag   = "${md5(file("config/alertmanager.yml"))}"
}
