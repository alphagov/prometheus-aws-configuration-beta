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
    allow_cidrs             = "${join("",formatlist("allow %s;\n", var.cidr_admin_whitelist))}"
    alertmanager_1_dns_name = "${data.terraform_remote_state.app_ecs_albs.alerts_private_record_fqdns.0}"
    alertmanager_2_dns_name = "${data.terraform_remote_state.app_ecs_albs.alerts_private_record_fqdns.1}"
    alertmanager_3_dns_name = "${data.terraform_remote_state.app_ecs_albs.alerts_private_record_fqdns.2}"
    prometheus_1_address    = "prom-1.${data.terraform_remote_state.infra_networking.private_subdomain}:9090"
    prometheus_2_address    = "prom-2.${data.terraform_remote_state.infra_networking.private_subdomain}:9090"
    prometheus_3_address    = "prom-3.${data.terraform_remote_state.infra_networking.private_subdomain}:9090"
  }
}

resource "aws_s3_bucket_object" "nginx-auth-proxy" {
  bucket  = "${aws_s3_bucket.config_bucket.id}"
  key     = "prometheus/nginx-auth-proxy/conf.d/auth-proxy.conf"
  content = "${data.template_file.nginx-auth-proxy-config-file.rendered}"
  etag    = "${md5(data.template_file.nginx-auth-proxy-config-file.rendered)}"
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
