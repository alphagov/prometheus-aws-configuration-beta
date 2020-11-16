terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    pass = {
      source = "camptocamp/pass"
    }
  }
  required_version = ">= 0.13"
}
