terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "2.70"
    }
    pass = {
      source  = "camptocamp/pass"
      version = "1.4.0"
    }
    template = {
      source  = "hashicorp/template"
      version = "2.2.0"
    }
  }
  required_version = ">= 0.13"
}
