/**
* ECS service to pull down the prometheus config file from Github
*
*/

data "template_file" "git_puller_container_defn" {
  template = "${file("task-definitions/git-puller.json")}"
}

resource "aws_ecs_task_definition" "git_puller" {
  family                = "git-puller"
  container_definitions = "${data.template_file.git_puller_container_defn.rendered}"

  volume {
    name      = "pulled-config"
    host_path = "/srv/ecs/pulled-config"
  }
}

resource "aws_ecs_service" "git_puller" {
  name            = "git-puller"
  cluster         = "${var.stack_name}-ecs-monitoring"
  task_definition = "${aws_ecs_task_definition.git_puller.arn}"
  desired_count   = 1
}
