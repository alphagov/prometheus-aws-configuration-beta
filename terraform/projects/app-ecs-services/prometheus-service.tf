resource "aws_ecs_task_definition" "prometheus_server" {
  family                = "prometheus-server"
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
  name            = "prometheus-server"
  cluster         = "default"
  task_definition = "${aws_ecs_task_definition.prometheus_server.arn}"
  desired_count   = 1
}
