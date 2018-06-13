/**
* ECS service that runs prometheus
*
* This service consists of two containers.  The first, `s3-config-grabber`, fetches prometheus configuration from our config S3 bucket, and stores it on a shared volume.  Then `prometheus` runs and consumes that config.
*
* There is a known race condition between the two tasks - there is no guarantee that `s3-config-grabber` will grab the config before `prometheus` starts.
*
*/

## IAM roles & policies

resource "aws_iam_role" "prometheus_task_iam_role" {
  name = "${var.stack_name}-prometheus-task"
  path = "/"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

data "aws_iam_policy_document" "prometheus_policy_doc" {
  statement {
    sid = "GetPrometheusFiles"

    resources = ["arn:aws:s3:::${aws_s3_bucket.config_bucket.id}/prometheus/*", "arn:aws:s3:::${aws_s3_bucket.config_bucket.id}/alertmanager/*"]

    actions = [
      "s3:Get*",
    ]
  }

  statement {
    sid = "ListConfigBucket"

    resources = ["arn:aws:s3:::${aws_s3_bucket.config_bucket.id}"]

    actions = [
      "s3:List*",
    ]
  }

  statement {
    sid = "GetTargetsBucket"

    resources = [
      "arn:aws:s3:::${var.targets_s3_bucket}",
      "arn:aws:s3:::${var.targets_s3_bucket}/*",
    ]

    actions = [
      "s3:List*",
      "s3:Get*",
    ]
  }
}

resource "aws_iam_policy" "prometheus_task_policy" {
  name   = "${var.stack_name}-prometheus-task-policy"
  path   = "/"
  policy = "${data.aws_iam_policy_document.prometheus_policy_doc.json}"
}

resource "aws_iam_role_policy_attachment" "prometheus_policy_attachment" {
  role       = "${aws_iam_role.prometheus_task_iam_role.name}"
  policy_arn = "${aws_iam_policy.prometheus_task_policy.arn}"
}

data "template_file" "prometheus_config_file" {
  template = "${file("templates/prometheus.tpl")}"

  vars {
    alertmanager_dns_name = "${join("\",\"", data.terraform_remote_state.app_ecs_albs.alerts_private_record_fqdn)}"
    paas_proxy_dns_name   = "${join("\",\"", data.terraform_remote_state.app_ecs_albs.paas_proxy_private_record_fqdn)}"
  }
}

### container, task, service definitions

data "template_file" "prometheus_container_defn" {
  template = "${file("task-definitions/prometheus-server.json")}"

  vars {
    log_group     = "${aws_cloudwatch_log_group.task_logs.name}"
    region        = "${var.aws_region}"
    config_bucket = "${aws_s3_bucket.config_bucket.id}"
  }
}

resource "aws_ecs_task_definition" "prometheus_server" {
  family                = "${var.stack_name}-prometheus-server"
  container_definitions = "${data.template_file.prometheus_container_defn.rendered}"
  task_role_arn         = "${aws_iam_role.prometheus_task_iam_role.arn}"

  volume {
    name      = "config-from-s3"
    host_path = "/ecs/config-from-s3"
  }

  volume {
    name      = "prometheus-config"
    host_path = "/ecs/config-from-s3"
  }

  volume {
    name      = "auth-proxy"
    host_path = "/ecs/config-from-s3/auth-proxy/conf.d"
  }

  # We mount this at /prometheus which is the expected location for the prom/prometheus docker image
  volume {
    name      = "prometheus-timeseries-storage"
    host_path = "/ecs/prometheus_data"
  }
}

data "template_file" "pass_proxy_container_defn" {
  template = "${file("task-definitions/paas_proxy.json")}"

  vars {
    log_group     = "${aws_cloudwatch_log_group.task_logs.name}"
    region        = "${var.aws_region}"
    config_bucket = "${aws_s3_bucket.config_bucket.id}"
  }
}

resource "aws_ecs_task_definition" "paas_proxy" {
  family                = "${var.stack_name}-pass-proxy"
  container_definitions = "${data.template_file.pass_proxy_container_defn.rendered}"
  task_role_arn         = "${aws_iam_role.prometheus_task_iam_role.arn}"

  volume {
    name      = "paas-proxy"
    host_path = "/ecs/config-from-s3/paas-proxy/conf.d"
  }
}

resource "aws_ecs_service" "prometheus_server" {
  count = "${length(data.terraform_remote_state.app_ecs_albs.monitoring_external_tg)}"

  name            = "${var.stack_name}-prometheus-server-${count.index}"
  cluster         = "${var.stack_name}-ecs-monitoring"
  task_definition = "${aws_ecs_task_definition.prometheus_server.arn}"
  desired_count   = 1

  load_balancer {
    target_group_arn = "${element(data.terraform_remote_state.app_ecs_albs.monitoring_external_tg, count.index)}"
    container_name   = "auth-proxy"
    container_port   = 9090
  }
}

resource "aws_ecs_service" "paas_proxy_service" {
  count           = 3
  name            = "${var.stack_name}-paas-proxy-${count.index}"
  cluster         = "${var.stack_name}-ecs-monitoring"
  task_definition = "${aws_ecs_task_definition.paas_proxy.arn}"
  desired_count   = 1

  load_balancer {
    target_group_arn = "${data.terraform_remote_state.app_ecs_albs.paas_proxy_tg}"
    container_name   = "paas-proxy"
    container_port   = 8080
  }
}

resource "aws_ecs_service" "config_updater" {
  name            = "${var.stack_name}-targets-grabber"
  cluster         = "${var.stack_name}-ecs-monitoring"
  task_definition = "${aws_ecs_task_definition.config_updater.arn}"
  desired_count   = 3
}

data "template_file" "config_updater_defn" {
  template = "${file("task-definitions/config_updater.json")}"

  vars {
    log_group      = "${aws_cloudwatch_log_group.task_logs.name}"
    region         = "${var.aws_region}"
    targets_bucket = "${var.targets_s3_bucket}"
    config_bucket  = "${aws_s3_bucket.config_bucket.id}"
  }
}

resource "aws_ecs_task_definition" "config_updater" {
  family                = "${var.stack_name}-config-updater"
  container_definitions = "${data.template_file.config_updater_defn.rendered}"
  task_role_arn         = "${aws_iam_role.prometheus_task_iam_role.arn}"

  volume {
    name      = "config-from-s3"
    host_path = "/ecs/config-from-s3"
  }
}

resource "aws_s3_bucket_object" "prometheus-config" {
  bucket  = "${aws_s3_bucket.config_bucket.id}"
  key     = "prometheus/prometheus.yml"
  content = "${data.template_file.prometheus_config_file.rendered}"
  etag    = "${md5(data.template_file.prometheus_config_file.rendered)}"
}

resource "aws_s3_bucket_object" "alerts-config" {
  bucket = "${aws_s3_bucket.config_bucket.id}"
  key    = "prometheus/alerts/alerts.yml"
  source = "config/alerts.yml"
  etag   = "${md5(file("config/alerts.yml"))}"
}

#### nginx reverse proxy

data "template_file" "auth_proxy_config_file" {
  template = "${file("templates/auth-proxy.conf.tpl")}"

  vars {
    alertmanager_1_dns_name = "${data.terraform_remote_state.app_ecs_albs.alerts_private_record_fqdn.0}"
    alertmanager_2_dns_name = "${data.terraform_remote_state.app_ecs_albs.alerts_private_record_fqdn.1}"
    alertmanager_3_dns_name = "${data.terraform_remote_state.app_ecs_albs.alerts_private_record_fqdn.2}"
  }
}

resource "aws_s3_bucket_object" "nginx-reverse-proxy" {
  bucket  = "${aws_s3_bucket.config_bucket.id}"
  key     = "prometheus/auth-proxy/conf.d/prometheus-auth-proxy.conf"
  content = "${data.template_file.auth_proxy_config_file.rendered}"
  etag    = "${md5(data.template_file.auth_proxy_config_file.rendered)}"
}

# The htpasswd file is in bcrypt format, which is only supported
# by the nginx:alpine image, not the plain nginx image
# https://github.com/nginxinc/docker-nginx/issues/29
resource "aws_s3_bucket_object" "nginx-htpasswd" {
  bucket = "${aws_s3_bucket.config_bucket.id}"
  key    = "prometheus/auth-proxy/conf.d/.htpasswd"
  source = "config/vhosts/.htpasswd"
  etag   = "${md5(file("config/vhosts/.htpasswd"))}"
}

#### paas proxy

resource "aws_s3_bucket_object" "nginx-paas-proxy" {
  bucket = "${aws_s3_bucket.config_bucket.id}"
  key    = "prometheus/paas-proxy/conf.d/prometheus-paas-proxy.conf"
  source = "config/vhosts/paas-proxy.conf"
  etag   = "${md5(file("config/vhosts/paas-proxy.conf"))}"
}
