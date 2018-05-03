/**
* ## Project: app-ecs-nodes
*
* Create ECS worker nodes
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

variable "ecs_image_id" {
  type        = "string"
  description = "AMI ID to use for the ECS nodes"
  default     = "ami-2d386654"
}

variable "ecs_instance_type" {
  type        = "string"
  description = "ECS Node instance type"
  default     = "t2.medium"
}

variable "ecs_instance_root_size" {
  type        = "string"
  description = "ECS instance root volume size - in GB"
  default     = "50"
}

variable "ecs_instance_ssh_keyname" {
  type        = "string"
  description = "SSH keyname for ECS instances"
  default     = "ecs-monitoring"
}

variable "remote_state_bucket" {
  type        = "string"
  description = "S3 bucket we store our terraform state in"
  default     = "ecs-monitoring"
}

variable "remote_state_infra_networking_key_stack" {
  type        = "string"
  description = "Override infra-networking remote state path"
  default     = "infra-security-groups.tfstate"
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
    "Project" = "app-ecs-nodes"
  }

  cluster_name = "${var.stack_name}-ecs-monitoring"
}

# Resources
# --------------------------------------------------------------

## Providers

terraform {
  required_version = "= 0.11.7"

  backend "s3" {
    key = "app-ecs-nodes.tfstate"
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

resource "null_resource" "node_autoscaling_group_tags" {
  count = "${length(keys(var.additional_tags))}"

  triggers {
    key                 = "${element(keys(var.additional_tags), count.index)}"
    value               = "${element(values(var.additional_tags), count.index)}"
    propagate_at_launch = true
  }
}

resource "aws_ecs_cluster" "prometheus_cluster" {
  name = "${local.cluster_name}"
}

data "template_file" "prometheus_user_data" {
  template = "${file("prometheus-user-data.tpl")}"

  vars {
    cluster_name = "${local.cluster_name}"
  }
}

module "ecs-node-1" {
  source = "terraform-aws-modules/autoscaling/aws"

  name = "${var.stack_name}-ecs-node-1"

  key_name = "${var.ecs_instance_ssh_keyname}"

  # Launch configuration
  lc_name = "${var.stack_name}-ecs-node-1"

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

  user_data = "${data.template_file.prometheus_user_data.rendered}"

  # Auto scaling group
  asg_name                  = "${var.stack_name}-ecs-node-1"
  vpc_zone_identifier       = ["${element(data.terraform_remote_state.infra_networking.private_subnets, 1)}"]
  health_check_type         = "EC2"
  min_size                  = 1
  max_size                  = 1
  desired_capacity          = 1
  wait_for_capacity_timeout = 0

  tags = ["${concat(
    null_resource.node_autoscaling_group_tags.*.triggers)
  }"]
}

## Outputs

output "ecs-node-1_asg_id" {
  value       = "${module.ecs-node-1.this_autoscaling_group_id}"
  description = "ecs-node-1 ASG ID"
}
