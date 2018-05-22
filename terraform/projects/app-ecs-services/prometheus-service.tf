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

    resources = ["arn:aws:s3:::${aws_s3_bucket.config_bucket.id}/prometheus/*"]

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
    host_path = "/ecs/config-from-s3/prometheus"
  }

  volume {
    name      = "auth-proxy"
    host_path = "/ecs/config-from-s3/auth-proxy/conf.d"
  }

  volume {
    name      = "paas-proxy"
    host_path = "/ecs/config-from-s3/paas-proxy/conf.d"
  }

  volume {
    name      = "alertmanager"
    host_path = "/ecs/config-from-s3/alertmanager"
  }


  # We mount this at /prometheus which is the expected location for the prom/prometheus docker image
  volume {
    name      = "prometheus-timeseries-storage"
    host_path = "/ecs/prometheus_data"
  }
}

resource "aws_ecs_service" "prometheus_server" {
  name            = "${var.stack_name}-prometheus-server"
  cluster         = "${var.stack_name}-ecs-monitoring"
  task_definition = "${aws_ecs_task_definition.prometheus_server.arn}"
  desired_count   = 1

  load_balancer {
    target_group_arn = "${data.terraform_remote_state.app_ecs_albs.monitoring_external_tg}"
    container_name   = "auth-proxy"
    container_port   = 9090
  }
}

resource "aws_s3_bucket_object" "prometheus-config" {
  bucket = "${aws_s3_bucket.config_bucket.id}"
  key    = "prometheus/prometheus/prometheus.yml"
  source = "config/prometheus.yml"
  etag   = "${md5(file("config/prometheus.yml"))}"
}

#### nginx reverse proxy

resource "aws_s3_bucket_object" "nginx-reverse-proxy" {
  bucket = "${aws_s3_bucket.config_bucket.id}"
  key    = "prometheus/auth-proxy/conf.d/prometheus-auth-proxy.conf"
  source = "config/vhosts/auth-proxy.conf"
  etag   = "${md5(file("config/vhosts/auth-proxy.conf"))}"
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

#### alertmanager

resource "aws_s3_bucket_object" "alertmanager" {
  bucket = "${aws_s3_bucket.config_bucket.id}"
  key    = "prometheus/alertmanager/alertmanager.yml"
  source = "config/alertmanager.yml"
  etag   = "${md5(file("config/alertmanager.yml"))}"
}
