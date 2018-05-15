/**
* ECS service to pull down the prometheus config file from Github
*
*/

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

  volume {
    name      = "pulled-config"
    host_path = "/ecs/pulled-config"
  }
}

resource "aws_ecs_service" "git_puller" {
  name            = "git-puller"
  cluster         = "${var.stack_name}-ecs-monitoring"
  task_definition = "${aws_ecs_task_definition.git_puller.arn}"
  desired_count   = 1
}
