variable "az_zone" {
  type        = "list"
  description = "The availability zone in which the disk and instance reside. "
  default     = ["eu-west-2a", "eu-west-2b"]
}

variable "ec2_endpoint_ips" {
  type        = "list"
  description = "This is placeholder for a missing value"
  default     = ["1.1.1.1", "2.2.2.2"]
}
