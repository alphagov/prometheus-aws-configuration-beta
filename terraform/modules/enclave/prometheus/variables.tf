variable "ami_id" {}

variable "device_mount_path" {
  description = "The path to mount the prometheus disk"
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
  default = [""]
}

variable "region" {
  default = "eu-west-2"
}

variable "egress_proxy" {
  default = ""
}

variable "allowed_cidrs" {
  type        = "list"
  description = "List of CIDRs which are able to access the enclave prometheus instance, default are GDS ips"

  default = [
    "213.86.153.212/32",
    "213.86.153.213/32",
    "213.86.153.214/32",
    "213.86.153.235/32",
    "213.86.153.236/32",
    "213.86.153.237/32",
    "85.133.67.244/32",
  ]
}

variable "config_bucket" {}

variable "targets_bucket" {
  default = ""
}

variable "prometheus_public_fqdns" {
  type = "list"
}
