/**
* ## Module: app-ecs-instances
*
* Create ECS container instances
*
*/

variable "aws_region" {
  type        = "string"
  description = "AWS region"
  default     = "eu-west-1"
}

variable "prometheis_total" {
  type        = "string"
  description = "Desired number of prometheus servers.  Maximum 3."
  default     = "3"
}

variable "ecs_instance_type" {
  type        = "string"
  description = "ECS container instance type"
  default     = "t2.medium"
}

variable "ecs_instance_root_size" {
  type        = "string"
  description = "ECS container instance root volume size - in GB"
  default     = "50"
}

variable "ecs_optimised_ami_version" {
  default = "2018.03.a"
}

variable "remote_state_bucket" {
  type        = "string"
  description = "S3 bucket we store our terraform state in"
  default     = "ecs-monitoring"
}

variable "stack_name" {
  type        = "string"
  description = "Unique name for this collection of resources"
  default     = "ecs-monitoring"
}

variable "dev_environment" {
  type        = "string"
  description = "Boolean flag for development environments"
  default     = "false"
}

variable "project" {
  type        = "string"
  description = "Project name for tag"
}

variable "asg_dev_scaledown_schedules" {
  type        = "list"
  description = "Schedules for scaling down dev EC2 instances"

  # every hour starting from 6pm - 8am UTC, Monday - Friday, and every hour on the weekend
  default = ["0 18-23 * * MON,TUE,WED,THU,FRI", "0 0-8 * * MON,TUE,WED,THU,FRI", "0 0 * * SAT,SUN"]
}

# locals
# --------------------------------------------------------------

locals {
  default_tags = {
    Terraform = "true"
    Project   = "${var.project}"
  }

  cluster_name = "${var.stack_name}-ecs-monitoring"
}

# Resources
# --------------------------------------------------------------

## Data sources

data "terraform_remote_state" "infra_networking" {
  backend = "s3"

  config {
    bucket = "${var.remote_state_bucket}"
    key    = "infra-networking-modular.tfstate"
    region = "${var.aws_region}"
  }
}

data "terraform_remote_state" "infra_security_groups" {
  backend = "s3"

  config {
    bucket = "${var.remote_state_bucket}"
    key    = "infra-security-groups-modular.tfstate"
    region = "${var.aws_region}"
  }
}

data "aws_subnet" "subnets_for_prometheus" {
  # only use enough subnets to fit the desired number of prometheus servers
  count = "${var.prometheis_total}"
  id    = "${data.terraform_remote_state.infra_networking.private_subnets[count.index]}"
}

## Resources

resource "aws_ecs_cluster" "prometheus_cluster" {
  name = "${local.cluster_name}"
}

data "template_file" "instance_user_data" {
  template = "${file("${path.module}/instance-user-data.tpl")}"

  vars {
    cluster_name = "${local.cluster_name}"
  }
}

module "ami" {
  source = "../../modules/common/ami"
}

module "ecs_instance" {
  source = "terraform-aws-modules/autoscaling/aws"

  name = "${var.stack_name}-ecs-instances"

  # Launch configuration
  lc_name = "${var.stack_name}-ecs-instances"

  image_id      = "${module.ami.ecs_optimized_ami_id}"
  instance_type = "${var.ecs_instance_type}"

  security_groups = ["${data.terraform_remote_state.infra_security_groups.alertmanager_ec2_sg_id}"]

  iam_instance_profile = "${var.stack_name}-ecs-profile"

  root_block_device = [
    {
      volume_size = "${var.ecs_instance_root_size}"
      volume_type = "gp2"
    },
  ]

  user_data = "${data.template_file.instance_user_data.rendered}"

  # Auto scaling group
  asg_name                  = "${var.stack_name}-ecs-instance"
  vpc_zone_identifier       = ["${data.aws_subnet.subnets_for_prometheus.*.id}"]
  health_check_type         = "EC2"
  min_size                  = "${var.prometheis_total}"
  max_size                  = "${var.prometheis_total}"
  desired_capacity          = "${var.prometheis_total}"
  wait_for_capacity_timeout = 0

  tags_as_map = "${merge(
    local.default_tags,
    map("Stackname", "${var.stack_name}"),
    map("Name", "${var.stack_name}-ecs-instance")
  )}"
}

resource "aws_autoscaling_schedule" "asg_dev_scaledown_schedules" {
  scheduled_action_name  = "asg_dev_scaledown_schedule-${count.index}"
  count                  = "${var.dev_environment == "true" ? "${length(var.asg_dev_scaledown_schedules)}" : 0}"
  min_size               = 0
  max_size               = "${var.prometheis_total}"
  desired_capacity       = 0
  recurrence             = "${element(var.asg_dev_scaledown_schedules, count.index)}"
  autoscaling_group_name = "${module.ecs_instance.this_autoscaling_group_name}"
}

## Outputs

output "available_azs" {
  value       = "${data.aws_subnet.subnets_for_prometheus.*.availability_zone}"
  description = "AZs available with running container instances"
}

output "asg_dev_scaledown_schedules" {
  value       = "${aws_autoscaling_schedule.asg_dev_scaledown_schedules.*.recurrence}"
  description = "Cron schedule for scaling down dev EC2 instances"
}
