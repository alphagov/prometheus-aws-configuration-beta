/**
* ECS service that runs prometheus
*
*/

resource "aws_ecs_task_definition" "prometheus_server" {
  family                = "${var.stack_name}-prometheus-server"
  container_definitions = "${file("task-definitions/prometheus-server.json")}"

  volume {
    name      = "prometheus-config"
    host_path = "/ecs/pulled-config/prometheus/prometheus.yml"
  }

  volume {
    name      = "alert-config"
    host_path = "/ecs/pulled-config/prometheus/alerts/alerts.default"
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
