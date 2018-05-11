/**
* ECS service to pull down the prometheus config file from Github
*
*/

## IAM roles & policies

resource "aws_iam_role" "prometheus_task_iam_role" {
  name = "${var.stack_name}-prometheus-task"
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

data "aws_iam_policy_document" "prometheus_policy_doc" {
  statement {
    sid = "GetPrometheusFiles"

    resources = ["arn:aws:s3:::${aws_s3_bucket.config_bucket.id}/etc/prometheus/*"]

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

resource "aws_iam_policy" "prometheus_task_policy" {
  name   = "${var.stack_name}-prometheus-task-policy"
  path   = "/"
  policy = "${data.aws_iam_policy_document.prometheus_policy_doc.json}"
}

resource "aws_iam_role_policy_attachment" "prometheus_policy_attachment" {
  role       = "${aws_iam_role.prometheus_task_iam_role.name}"
  policy_arn = "${aws_iam_policy.prometheus_task_policy.arn}"
}

## container, task and service definitions

data "template_file" "git_puller_container_defn" {
  template = "${file("task-definitions/git-puller.json")}"

  vars {
    log_group = "${aws_cloudwatch_log_group.task_logs.name}"
    region    = "${var.aws_region}"
  }
}

resource "aws_ecs_task_definition" "git_puller" {
  family                = "git-puller"
  container_definitions = "${data.template_file.git_puller_container_defn.rendered}"
  task_role_arn         = "${aws_iam_role.prometheus_task_iam_role.arn}"

  volume {
    name      = "pulled-config"
    host_path = "/ecs/config-from-s3"
  }
}

resource "aws_ecs_service" "git_puller" {
  name            = "git-puller"
  cluster         = "${var.stack_name}-ecs-monitoring"
  task_definition = "${aws_ecs_task_definition.git_puller.arn}"
  desired_count   = 1
}
