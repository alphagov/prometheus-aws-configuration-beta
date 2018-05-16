/**
* ## Project: app-ecs-instances
*
* Create ECS container instances
*
*/

variable "additional_tags" {
  type        = "map"
  description = "Stack specific tags to apply"
  default     = {}
}

variable "aws_region" {
  type        = "string"
  description = "AWS region"
  default     = "eu-west-1"
}

variable "autoscaling_group_min_size" {
  type        = "string"
  description = "Minimum desired number of ECS container instances"
  default     = 1
}

variable "autoscaling_group_max_size" {
  type        = "string"
  description = "Maximum desired number of ECS container instances"
  default     = 1
}

variable "autoscaling_group_desired_capacity" {
  type        = "string"
  description = "Desired number of ECS container instances"
  default     = 1
}

variable "ecs_image_id" {
  type        = "string"
  description = "AMI ID to use for the ECS container instances"
  default     = "ami-2d386654"                                  # Latest Amazon ECS optimised AMI
}

variable "ecs_instance_type" {
  type        = "string"
  description = "ECS container instance type"
  default     = "m4.xlarge"
}

variable "ecs_instance_root_size" {
  type        = "string"
  description = "ECS container instance root volume size - in GB"
  default     = "50"
}

variable "ecs_instance_ssh_keyname" {
  type        = "string"
  description = "SSH keyname for ECS container instances"
  default     = "djeche-insecure"
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

# locals
# --------------------------------------------------------------

locals {
  default_tags = {
    Terraform = "true"
    Project   = "app-ecs-instances"
  }

  cluster_name = "${var.stack_name}-ecs-monitoring"
}

# Resources
# --------------------------------------------------------------

## Providers

terraform {
  required_version = "= 0.11.7"

  backend "s3" {
    key = "app-ecs-instances.tfstate"
  }
}

provider "aws" {
  version = "~> 1.14.1"
  region  = "${var.aws_region}"
}

provider "template" {
  version = "~> 1.0.0"
}

## Data sources

data "terraform_remote_state" "infra_networking" {
  backend = "s3"

  config {
    bucket = "${var.remote_state_bucket}"
    key    = "infra-networking.tfstate"
    region = "${var.aws_region}"
  }
}

data "terraform_remote_state" "infra_security_groups" {
  backend = "s3"

  config {
    bucket = "${var.remote_state_bucket}"
    key    = "infra-security-groups.tfstate"
    region = "${var.aws_region}"
  }
}

## Resources

resource "aws_ecs_cluster" "prometheus_cluster" {
  name = "${local.cluster_name}"
}

data "template_file" "instance_user_data" {
  template = "${file("instance-user-data.tpl")}"

  vars {
    cluster_name = "${local.cluster_name}"
  }
}

module "ecs_instance" {
  source = "terraform-aws-modules/autoscaling/aws"

  name = "${var.stack_name}-ecs-instance"

  key_name = "${var.ecs_instance_ssh_keyname}"

  # Launch configuration
  lc_name = "${var.stack_name}-ecs-instance"

  image_id             = "${var.ecs_image_id}"
  instance_type        = "${var.ecs_instance_type}"
  security_groups      = ["${data.terraform_remote_state.infra_security_groups.monitoring_internal_sg_id}"]
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
  vpc_zone_identifier       = ["${element(data.terraform_remote_state.infra_networking.private_subnets, 0)}"]
  health_check_type         = "EC2"
  min_size                  = "${var.autoscaling_group_min_size}"
  max_size                  = "${var.autoscaling_group_max_size}"
  desired_capacity          = "${var.autoscaling_group_desired_capacity}"
  wait_for_capacity_timeout = 0

  tags_as_map = "${merge(
    local.default_tags,
    var.additional_tags,
    map("Stackname", "${var.stack_name}"),
    map("Name", "${var.stack_name}-ecs-instance")
  )}"
}

## Outputs

output "ecs_instance_asg_id" {
  value       = "${module.ecs_instance.this_autoscaling_group_id}"
  description = "ecs-instance ASG ID"
}
