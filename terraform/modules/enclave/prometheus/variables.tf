variable "ami_id" {}

variable "device_mount_path" {
  description = "The path to mount the promethus disk"
  default     = "/dev/sdh"
}

variable "availability_zones" {
  description = "A map of availability zones to subnets"

  type    = "map"
  default = {}
}

variable "subnet_ids" {
  type = "list"
}

variable "instance_size" {
  type        = "string"
  description = "This is the default instance size"
  default     = "t2.medium"
}

variable "target_vpc" {
  description = "The VPC in which the system will be deployed"
}

variable "product" {}

variable "environment" {}

variable "vpc_security_groups" {
  type    = "list"
  default = []
}

variable "enable_ssh" {
  default = false
}

variable "ec2_endpoint_ips" {
  type    = "list"
  default = []
}

variable "region" {
  default = "eu-west-2"
}

variable "verify_enclave" {
  type = "string"
  default = "true"
}

variable "egress_proxy" {
  default = ""
}
