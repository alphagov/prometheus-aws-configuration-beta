## IAM roles & policies

### container, task, service definitions

data "template_file" "nginx_auth_container_def" {
  template = "${file("task-definitions/nginx-auth-proxy.json")}"

  vars {
    log_group = "${aws_cloudwatch_log_group.task_logs.name}"
    region    = "${var.aws_region}"
  }
}

resource "aws_ecs_task_definition" "nginx_auth_server" {
  family                = "${var.stack_name}-nginx-auth"
  container_definitions = "${data.template_file.nginx_auth_container_def.rendered}"

  volume {
    name      = "nginx-auth-proxy"
    host_path = "/ecs/config-from-s3/nginx-auth-proxy/conf.d"
  }

  volume {
    name      = "nginx-config"
    host_path = "/ecs/config-from-s3/nginx-auth-proxy"
  }

}

resource "aws_ecs_service" "nginx_auth_service" {
  name            = "${var.stack_name}-nginx-auth"
  cluster         = "${var.stack_name}-ecs-monitoring"
  task_definition = "${aws_ecs_task_definition.nginx_auth_server.arn}"
  desired_count   = "${length(data.terraform_remote_state.app_ecs_instances.available_azs)}"

  load_balancer {
    target_group_arn = "${data.terraform_remote_state.app_ecs_albs.monitoring_external_tg}"
    container_name   = "nginx-auth-proxy"
    container_port   = 80
  }

  ordered_placement_strategy {
    type  = "spread"
    field = "attribute:ecs.availability-zone"
  }
}

data "template_file" "nginx-auth-proxy-config-file" {
  template = "${file("templates/nginx-auth-proxy.conf.tpl")}"

  vars {
    alertmanager_1_dns_name = "${data.terraform_remote_state.app_ecs_albs.alerts_private_record_fqdns.0}"
    alertmanager_2_dns_name = "${data.terraform_remote_state.app_ecs_albs.alerts_private_record_fqdns.1}"
    alertmanager_3_dns_name = "${data.terraform_remote_state.app_ecs_albs.alerts_private_record_fqdns.2}"
    prometheus_1_dns_name   = "${data.terraform_remote_state.app_ecs_albs.prom_private_record_fqdns.0}"
    prometheus_2_dns_name   = "${data.terraform_remote_state.app_ecs_albs.prom_private_record_fqdns.1}"
    prometheus_3_dns_name   = "${data.terraform_remote_state.app_ecs_albs.prom_private_record_fqdns.2}"
  }
}

data "template_file" "nginx-config" {
  template = "${file("templates/nginx-config.tpl")}"

  vars {
    mesh_1_dns_name   = "${data.terraform_remote_state.app_ecs_instances.mesh_private_record_fqdns.0}"
    mesh_2_dns_name   = "${data.terraform_remote_state.app_ecs_instances.mesh_private_record_fqdns.1}"
    mesh_3_dns_name   = "${data.terraform_remote_state.app_ecs_instances.mesh_private_record_fqdns.2}"
  }
}


resource "aws_s3_bucket_object" "nginx-auth-proxy" {
  bucket  = "${aws_s3_bucket.config_bucket.id}"
  key     = "prometheus/nginx-auth-proxy/conf.d/auth-proxy.conf"
  content = "${data.template_file.nginx-auth-proxy-config-file.rendered}"
  etag    = "${md5(data.template_file.nginx-auth-proxy-config-file.rendered)}"
}

resource "aws_s3_bucket_object" "nginx-conf" {
  bucket  = "${aws_s3_bucket.config_bucket.id}"
  key     = "prometheus/nginx-auth-proxy/nginx.conf"
  content = "${data.template_file.nginx-config.rendered}"
  etag    = "${md5(data.template_file.nginx-config.rendered)}"
}


# The htpasswd file is in bcrypt format, which is only supported
# by the nginx:alpine image, not the plain nginx image
# https://github.com/nginxinc/docker-nginx/issues/29
resource "aws_s3_bucket_object" "nginx-htpasswd" {
  bucket = "${aws_s3_bucket.config_bucket.id}"
  key    = "prometheus/nginx-auth-proxy/conf.d/.htpasswd"
  source = "config/vhosts/.htpasswd"
  etag   = "${md5(file("config/vhosts/.htpasswd"))}"
}
