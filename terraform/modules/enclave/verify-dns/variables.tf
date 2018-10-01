variable "hosted_zone_name" {
  description = "The name of the hosted zone the records will be added to"
}

variable "target_vpc" {
  description = "The VPC which contains the hosted zone which will be updated"
}

variable "prometheus_private_ips" {
  description = "The list of instance ips which will have records created for them"
  type        = "list"
}

variable "hostname_prefix" {
  description = "The prefix of the hostname added to the record i.e. {hostname_prefix}-1.internal"
  default     = "prometheus"
}
