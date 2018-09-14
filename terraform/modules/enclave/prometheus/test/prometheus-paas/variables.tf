variable "ec2_endpoint_ips" {
  type        = "list"
  description = "This is placeholder for a missing value"
  default     = ["1.1.1.1", "2.2.2.2"]
}

variable "az_zones_avalible" {
  type    = "list"
  default = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
}

variable "test_user" {}

variable "target_test_env" {}
