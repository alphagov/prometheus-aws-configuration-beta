terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "3.15"
    }
    pass = {
      source  = "camptocamp/pass"
      version = "1.4.0"
    }
  }
  required_version = ">= 0.13"
}
