resource "aws_iam_role" "config_task_iam_role" {
  name = "${var.stack_name}-config-updater-task"
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

data "aws_iam_policy_document" "config_policy_doc" {
  statement {
    sid = "GetConfigFiles"

    resources = ["arn:aws:s3:::${aws_s3_bucket.config_bucket.id}/prometheus/*", "arn:aws:s3:::${aws_s3_bucket.config_bucket.id}/alertmanager/*"]

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

resource "aws_iam_policy" "config_task_policy" {
  name   = "${var.stack_name}-config-task-policy"
  path   = "/"
  policy = "${data.aws_iam_policy_document.config_policy_doc.json}"
}

resource "aws_iam_role_policy_attachment" "config_policy_attachment" {
  role       = "${aws_iam_role.config_task_iam_role.name}"
  policy_arn = "${aws_iam_policy.config_task_policy.arn}"
}

resource "aws_ecs_service" "config_updater" {
  name            = "${var.stack_name}-config-updater"
  cluster         = "${var.stack_name}-ecs-monitoring"
  task_definition = "${aws_ecs_task_definition.config_updater.arn}"
  desired_count   = "${length(data.terraform_remote_state.app_ecs_instances.available_azs)}"
}

data "template_file" "config_updater_defn" {
  template = "${file("${path.module}/task-definitions/config_updater.json")}"

  vars {
    log_group     = "${aws_cloudwatch_log_group.task_logs.name}"
    region        = "${var.aws_region}"
    config_bucket = "${aws_s3_bucket.config_bucket.id}"
  }
}

resource "aws_ecs_task_definition" "config_updater" {
  family                = "${var.stack_name}-config-updater"
  container_definitions = "${data.template_file.config_updater_defn.rendered}"
  task_role_arn         = "${aws_iam_role.config_task_iam_role.arn}"

  volume {
    name      = "config-from-s3"
    host_path = "/ecs/config-from-s3"
  }
}
