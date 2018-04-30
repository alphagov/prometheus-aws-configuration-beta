resource "aws_ecs_task_definition" "git_puller" {
  family                = "git-puller"
  container_definitions = "${file("task-definitions/git-puller.json")}"

  volume {
    name      = "pulled-config"
    host_path = "/ecs/pulled-config"
  }
}

resource "aws_ecs_service" "git_puller" {
  name            = "git-puller"
  cluster         = "default"
  task_definition = "${aws_ecs_task_definition.git_puller.arn}"
  desired_count   = 1
}
