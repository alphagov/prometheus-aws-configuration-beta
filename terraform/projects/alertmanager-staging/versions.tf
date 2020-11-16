terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    pass = {
      source = "camptocamp/pass"
    }
    template = {
      source = "hashicorp/template"
    }
  }
  required_version = ">= 0.13"
}
