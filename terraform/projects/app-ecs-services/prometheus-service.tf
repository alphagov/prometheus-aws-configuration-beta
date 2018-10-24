/**
* ECS service that runs prometheus
*
* This service consists of two containers.  The first, `s3-config-grabber`, fetches prometheus configuration from our config S3 bucket, and stores it on a shared volume.  Then `prometheus` runs and consumes that config.
*
* There is a known race condition between the two tasks - there is no guarantee that `s3-config-grabber` will grab the config before `prometheus` starts.
*
*/

variable "prom_cpu" {
  type        = "string"
  description = "CPU requirement for prometheus"
  default     = "512"
}

variable "prom_memoryReservation" {
  type        = "string"
  description = "memory reservation requirement for prometheus"
  default     = "2048"
}

# locals
# --------------------------------------------------------------

locals {
  num_azs = "${length(data.terraform_remote_state.app_ecs_instances.available_azs)}"

  prometheus_public_fqdns = "${data.terraform_remote_state.app_ecs_albs.prom_public_record_fqdns}"

  active_alertmanager_private_fqdns = "${slice(data.terraform_remote_state.app_ecs_albs.alerts_private_record_fqdns, 0, local.num_azs)}"
  active_prometheus_private_fqdns   = "${slice(data.terraform_remote_state.app_ecs_albs.prom_private_record_fqdns, 0, local.num_azs)}"
}

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
    alertmanager_dns_names = "${join("\",\"", local.active_alertmanager_private_fqdns)}"

    # in dev stacks if we have less than 3 AZs then just have ECS prometheis as we will be migrating the stack to EC2
    # set the prometheis_total to 3 in order to set up ec2 as prom-3
    prometheus_addresses = "${
      local.num_azs < 3 ? "${join("\",\"", local.active_prometheus_private_fqdns)}" :
      join("\",\"", concat(slice(local.active_prometheus_private_fqdns, 0, local.num_azs - 1),
        list("prom-ec2-3.${data.terraform_remote_state.infra_networking.private_subdomain}:9090")))
    }"

    paas_proxy_dns_name = "${data.terraform_remote_state.app_ecs_albs.paas_proxy_private_record_fqdn}"
  }
}

### container, task, service definitions

data "template_file" "prometheus_container_defn" {
  count    = "${length(local.prometheus_public_fqdns)}"
  template = "${file("task-definitions/prometheus-server.json")}"

  vars {
    prom_cpu               = "${var.prom_cpu}"
    prom_memoryReservation = "${var.prom_memoryReservation}"
    prom_url               = "https://${local.prometheus_public_fqdns[count.index]}"
    log_group              = "${aws_cloudwatch_log_group.task_logs.name}"
    region                 = "${var.aws_region}"
    config_bucket          = "${aws_s3_bucket.config_bucket.id}"
  }
}

resource "aws_ecs_task_definition" "prometheus_server" {
  count                 = "${length(local.prometheus_public_fqdns)}"
  family                = "${var.stack_name}-prometheus-server-${count.index + 1}"
  container_definitions = "${element(data.template_file.prometheus_container_defn.*.rendered, count.index)}"
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
resource "aws_ecs_service" "prometheus_server" {
  count = "${length(data.terraform_remote_state.app_ecs_instances.available_azs)}"

  name            = "${var.stack_name}-prometheus-server-${count.index + 1}"
  cluster         = "${var.stack_name}-ecs-monitoring"
  task_definition = "${element(aws_ecs_task_definition.prometheus_server.*.arn, count.index)}"
  desired_count   = 1

  load_balancer {
    target_group_arn = "${element(data.terraform_remote_state.app_ecs_albs.prometheus_internal_tg, count.index)}"
    container_name   = "prometheus"
    container_port   = 9090
  }

  placement_constraints {
    type       = "memberOf"
    expression = "attribute:ecs.availability-zone == ${data.terraform_remote_state.app_ecs_instances.available_azs[count.index]}"
  }
}

resource "aws_ecs_service" "config_updater" {
  name            = "${var.stack_name}-targets-grabber"
  cluster         = "${var.stack_name}-ecs-monitoring"
  task_definition = "${aws_ecs_task_definition.config_updater.arn}"
  desired_count   = "${length(data.terraform_remote_state.app_ecs_instances.available_azs)}"
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
  key    = "prometheus/alerts/observe-alerts.yml"
  source = "config/alerts/observe-alerts.yml"
  etag   = "${md5(file("config/alerts/observe-alerts.yml"))}"
}

resource "aws_s3_bucket_object" "alerts-data-gov-uk-config" {
  bucket = "${aws_s3_bucket.config_bucket.id}"
  key    = "prometheus/alerts/data-gov-uk-alerts.yml"
  source = "config/alerts/data-gov-uk-alerts.yml"
  etag   = "${md5(file("config/alerts/data-gov-uk-alerts.yml"))}"
}

resource "aws_s3_bucket_object" "alerts-registers-config" {
  bucket = "${aws_s3_bucket.config_bucket.id}"
  key    = "prometheus/alerts/registers-alerts.yml"
  source = "config/alerts/registers-alerts.yml"
  etag   = "${md5(file("config/alerts/registers-alerts.yml"))}"
}
