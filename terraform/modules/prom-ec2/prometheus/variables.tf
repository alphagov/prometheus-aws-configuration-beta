variable "ami_id" {}

variable "device_mount_path" {
  description = "The path to mount the prometheus disk"
  default     = "/dev/sdh"
}

variable "data_volume_size" {
  description = "The size of the volume that will contain the prometheus data"
  default     = 50
}

variable "availability_zones" {
  description = "A map of availability zones to subnets"

  type    = map(string)
  default = {}
}

variable "subnet_ids" {
  type = list(string)
}

variable "instance_size" {
  type        = string
  description = "This is the default instance size"
  default     = "m5.large"
}

variable "target_vpc" {
  description = "The VPC in which the system will be deployed"
}

variable "environment" {}

variable "vpc_security_groups" {
  type        = list(string)
  default     = []
  description = "Security groups to attach to the prometheus instances"
}

variable "enable_ssh" {
  default = false
}

variable "region" {
  default = "eu-west-1"
}

variable "allowed_cidrs" {
  type        = list(string)
  description = "List of CIDRs which are able to access the prometheus instance, default are GDS ips"

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

variable "prometheus_public_fqdns" {
  type = list(string)
}

variable "logstash_host" {
  default = ""
}

variable "prometheus_htpasswd" {
  default     = ""
  description = "Contents of basic auth .htpasswd file for NGINX to allow access from Grafana"
}

variable "prometheus_target_group_arns" {
  type    = list(string)
  default = []
}
