data "template_file" "paas_proxy_container_defn" {
  template = "${file("task-definitions/paas_proxy.json")}"

  vars {
    log_group     = "${aws_cloudwatch_log_group.task_logs.name}"
    region        = "${var.aws_region}"
    config_bucket = "${aws_s3_bucket.config_bucket.id}"
  }
}

resource "aws_iam_role" "paas_proxy_task_iam_role" {
  name = "${var.stack_name}-paas-proxy-task"
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

resource "aws_ecs_task_definition" "paas_proxy" {
  family                = "${var.stack_name}-paas-proxy"
  container_definitions = "${data.template_file.paas_proxy_container_defn.rendered}"
  task_role_arn         = "${aws_iam_role.paas_proxy_task_iam_role.arn}"

  volume {
    name      = "paas-proxy"
    host_path = "/ecs/config-from-s3/paas-proxy/conf.d"
  }
}

resource "aws_ecs_service" "paas_proxy_service" {
  name            = "${var.stack_name}-paas-proxy"
  cluster         = "${var.stack_name}-ecs-monitoring"
  task_definition = "${aws_ecs_task_definition.paas_proxy.arn}"
  desired_count   = "${length(data.terraform_remote_state.app_ecs_instances.available_azs)}"

  load_balancer {
    target_group_arn = "${data.terraform_remote_state.app_ecs_albs.paas_proxy_tg}"
    container_name   = "paas-proxy"
    container_port   = 8080
  }

  ordered_placement_strategy {
    type  = "spread"
    field = "attribute:ecs.availability-zone"
  }
}

resource "aws_s3_bucket_object" "nginx-paas-proxy" {
  bucket = "${aws_s3_bucket.config_bucket.id}"
  key    = "prometheus/paas-proxy/conf.d/prometheus-paas-proxy.conf"
  source = "config/vhosts/paas-proxy.conf"
  etag   = "${md5(file("config/vhosts/paas-proxy.conf"))}"
}
