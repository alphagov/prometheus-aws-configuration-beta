variable "availability_zones" {
  type    = "map"
  default = {}
}

# the traget VPC which the 
variable "target_vpc" {
  description = "The target VPC which Prometheus will be deployed to"
  type        = "string"
}

variable "internet_gateway_id" {
  description = "The internet gateway of the target VPC"

  type = "string"
}

#Needed by Verify to peer with the high VPC can be left empty if there are no
#VPCs to peer with
variable "vpc_peers" {
  description = "Map of VPCs to peer with the key is the subnet the value is the VPC peer ID"

  type    = "map"
  default = {}
}

variable "cidr_admin_whitelist" {
  description = "CIDR ranges permitted to communicate with administrative endpoints"
  type        = "list"

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

variable environment {}
variable product {}

variable team {
  default = "observe"
}
