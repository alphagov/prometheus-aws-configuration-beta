/**
* ECS service that runs a prometheus black box exporter
*
* This enables prometheus to 'black box' check web services that haven't
* instrumented a prometheus metrics endpoint.
*
*/

resource "aws_ecs_task_definition" "prometheus_blackbox" {
  family                = "${var.stack_name}-prometheus-blackbox"
  container_definitions = "${file("task-definitions/prometheus-blackbox.json")}"
}

resource "aws_ecs_service" "prometheus_blackbox" {
  name            = "${var.stack_name}-prometheus-blackbox"
  cluster         = "${var.stack_name}-ecs-monitoring"
  task_definition = "${aws_ecs_task_definition.prometheus_blackbox.arn}"
  desired_count   = 1
}
