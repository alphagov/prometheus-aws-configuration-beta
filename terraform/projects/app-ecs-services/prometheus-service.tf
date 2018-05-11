/**
* ECS service that runs prometheus
*
*/

data "template_file" "prometheus_container_defn" {
  template = "${file("task-definitions/prometheus-server.json")}"

  vars {
    log_group = "${aws_cloudwatch_log_group.task_logs.name}"
    region    = "${var.aws_region}"
  }
}

resource "aws_ecs_task_definition" "prometheus_server" {
  family                = "${var.stack_name}-prometheus-server"
  container_definitions = "${data.template_file.prometheus_container_defn.rendered}"

  volume {
    name      = "prometheus-config"
    host_path = "/ecs/config-from-s3/prometheus/prometheus.yml"
  }

  volume {
    name      = "alert-config"
    host_path = "/ecs/config-from-s3/prometheus/alerts"
  }
}

resource "aws_ecs_service" "prometheus_server" {
  name            = "${var.stack_name}-prometheus-server"
  cluster         = "${var.stack_name}-ecs-monitoring"
  task_definition = "${aws_ecs_task_definition.prometheus_server.arn}"
  desired_count   = 1

  load_balancer {
    target_group_arn = "${data.terraform_remote_state.app_ecs_albs.monitoring_external_tg}"
    container_name   = "prometheus"
    container_port   = 9090
  }
}

resource "aws_s3_bucket_object" "prometheus-config" {
  bucket = "${aws_s3_bucket.config_bucket.id}"
  key    = "etc/prometheus/prometheus.yml"
  source = "config/prometheus.yml"
  etag   = "${md5(file("config/prometheus.yml"))}"
}
