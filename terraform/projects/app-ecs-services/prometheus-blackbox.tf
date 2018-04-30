resource "aws_ecs_task_definition" "prometheus_blackbox" {
  family                = "prometheus-blackbox"
  container_definitions = "${file("task-definitions/prometheus-blackbox.json")}"
}

resource "aws_ecs_service" "prometheus_blackbox" {
  name            = "prometheus-blackbox"
  cluster         = "default"
  task_definition = "${aws_ecs_task_definition.prometheus_blackbox.arn}"
  desired_count   = 1
}
