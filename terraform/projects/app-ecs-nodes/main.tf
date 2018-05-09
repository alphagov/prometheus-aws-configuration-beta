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

variable "autoscaling_group_min_size" {
  type = "string"
  description = "Minimum desired number of ECS nodes"
  default = 1
}

variable "autoscaling_group_max_size" {
  type = "string"
  description = "Maximum desired number of ECS nodes"
  default = 1
}

variable "autoscaling_group_desired_capacity" {
  type = "string"
  description = "Desired number of ECS nodes"
  default = 1
}

variable "ecs_image_id" {
  type        = "string"
  description = "AMI ID to use for the ECS nodes"
  default     = "ami-2d386654" # Latest Amazon ECS optimised AMI
}

variable "ecs_instance_type" {
  type        = "string"
  description = "ECS Node instance type"
  default     = "m4.xlarge"
}

variable "ecs_instance_root_size" {
  type        = "string"
  description = "ECS instance root volume size - in GB"
  default     = "50"
}

variable "ecs_instance_ssh_keyname" {
  type        = "string"
  description = "SSH keyname for ECS instances"
  default     = "ecs-monitoring-ssh-test"
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
    Project = "app-ecs-nodes"
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

resource "aws_ecs_cluster" "prometheus_cluster" {
  name = "${local.cluster_name}"
}

data "template_file" "node_user_data" {
  template = "${file("node-user-data.tpl")}"

  vars {
    cluster_name = "${local.cluster_name}"
  }
}

module "ecs_node" {
  source = "terraform-aws-modules/autoscaling/aws"

  name = "${var.stack_name}-ecs-node"

  key_name = "${var.ecs_instance_ssh_keyname}"

  # Launch configuration
  lc_name = "${var.stack_name}-ecs-node"

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

  user_data = "${data.template_file.node_user_data.rendered}"

  # Auto scaling group
  asg_name                  = "${var.stack_name}-ecs-node"
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
    map("Name", "${var.stack_name}-ecs_node")
  )}"
}

## Outputs

output "ecs_node_asg_id" {
  value       = "${module.ecs_node.this_autoscaling_group_id}"
  description = "ecs-node ASG ID"
}
